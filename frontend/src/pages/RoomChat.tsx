import axios from 'axios'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { CHAT_WS_BASE_URL, HTTP_BASE_URL } from '../config/api'
import { CHAT_RATE_LIMIT } from '../config/chat'

/** 与后端房间历史 deque 上限一致：本地列表最多保留最近 N 条 */
const MAX_ROOM_MESSAGES = 200
const WS_RETRY_MAX = 2
const WS_RETRY_DELAY_MS = 450
const WS_HANDSHAKE_TIMEOUT_MS = 2500
const HISTORY_SYNC_TIMEOUT_MS = 4000

type IncomingMessage =
  | {
      type: 'chat'
      sender: string
      content: string
      timestamp?: string
    }
  | {
      type: 'system'
      content: string
      timestamp?: string
      online_count?: number
    }

type SystemKind = 'join' | 'leave' | 'generic' | 'cfs'

type ChatMessage = {
  id: string
  type: 'chat' | 'system'
  systemKind?: SystemKind  // system 消息的细分类型，用于视觉区分
  sender?: string
  content: string
  timestamp: string
  isHistory?: boolean
}

type HistoryApiMessage = {
  type: 'chat' | 'system'
  sender?: string | null
  content: string
  timestamp: string
}

interface RoomChatProps {
  embedded?: boolean
  loginSeq?: number
  /** 来自 App 的当前身份，与 localStorage cyber_name 同步 */
  cyberName?: string | null
}

const PRESET_SECTORS = [
  { id: 'sector-001', name: '午夜心碎俱乐部' },
  { id: 'sector-404', name: '赛博酒保' },
  { id: 'sector-777', name: '废弃数据中心' },
  { id: 'sector-999', name: '星空物语' },
]

const ROOM_THEME_MAP: Record<string, 'heartbreak' | 'bartender' | 'datacenter' | 'starry'> = {
  'sector-001': 'heartbreak',
  'sector-404': 'bartender',
  'sector-777': 'datacenter',
  'sector-999': 'starry',
}

// ── 公告：默认由 GET /api/announcements 下发；请求失败时使用此兜底 ──
type AnnouncementItem = { id: string; content: string }

type AnnouncementsApiResponse = { items: AnnouncementItem[] }

const FALLBACK_ANNOUNCEMENTS: AnnouncementItem[] = [
  { id: 'ann-1', content: '欢迎接入赛博树洞 2000.exe · 禁止实名，允许发疯。本地消息列表最多保留最近 200 条，与频道历史同步上限一致。' },
  { id: 'ann-2', content: '当前节点状态稳定 · 多扇区同步运行中 · 请文明发言，共同维护数字秩序。' },
  { id: 'ann-3', content: '系统公告：Phase-3 升级中 · AI 气氛组即将接入 · 敬请期待更多赛博体验。' },
]

/** 与后端 `[系统]: 终端 <cyber_name> 已接入/已断开扇区` 一致 */
const WS_JOIN_RE = /终端\s+<([^>]+)>\s*已接入/
const WS_LEAVE_RE = /终端\s+<([^>]+)>\s*已断开/

type RoomMembersApi = {
  members: string[]
  online_count: number
}

// ── Cyber File System（本地伪指令，不经 WS）────────────────────
const CFS_UPLINK_KEY = 'cfs_uplink_iso'

function isCfsSlashCommand(text: string): boolean {
  const c = text.trim().toLowerCase()
  return c === '/whoami' || c === '/ls' || c === '/clear'
}

function ensureCfsUplinkStamp(): void {
  if (!sessionStorage.getItem(CFS_UPLINK_KEY)) {
    sessionStorage.setItem(CFS_UPLINK_KEY, new Date().toISOString())
  }
}

function buildCfsWhoami(params: { cyberName: string; roomId: string; roomName: string }): string {
  ensureCfsUplinkStamp()
  const uplink = sessionStorage.getItem(CFS_UPLINK_KEY) ?? new Date().toISOString()
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
  const ua = navigator.userAgent
  const uaShort = ua.length > 56 ? `${ua.slice(0, 56)}…` : ua
  const scr = `${window.screen.width}×${window.screen.height}`
  const dpr = window.devicePixelRatio ?? 1
  const lang = navigator.language
  const tokenOk = Boolean(window.localStorage.getItem('cyber_token'))
  const cores = typeof navigator.hardwareConcurrency === 'number' ? navigator.hardwareConcurrency : null

  const art = [
    ' ██████╗██╗   ██╗██████╗ ███████╗██████╗ ',
    '██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗',
    '██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝',
    '██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗',
    '╚██████╗   ██║   ██████╔╝███████╗██║  ██║',
    ' ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝',
  ].join('\n')

  const t0 = new Date(uplink)
  const t0s = Number.isNaN(t0.getTime()) ? uplink : `${t0.toISOString().replace('T', ' ').slice(0, 19)}Z`

  const lines = [
    art,
    '',
    `  ── NODE_DESCRIPTOR :: ${params.cyberName} ──`,
    `  UPLINK_KEY .... ${params.cyberName}`,
    `  SESSION_T0 .... ${t0s}`,
    `  SECTOR_ID ..... ${params.roomId} (${params.roomName})`,
    `  GEO_BIND ...... TZ=${tz} · LANG=${lang}`,
    `  CLIENT_SIG .... ${uaShort}`,
    `  VIEWPORT ...... ${scr} @${dpr}x · ${screen.colorDepth}bpp`,
    cores != null ? `  CPU_CORES ..... ${cores}` : null,
    `  TOKEN_STATE ... ${tokenOk ? 'ARMED' : 'NULL'}`,
  ].filter((l): l is string => l != null)

  return lines.join('\n')
}

function buildCfsLs(params: { roomName: string; members: string[]; announcements: AnnouncementItem[] }): string {
  const ann = params.announcements.map((a, i) => {
    const short = a.content.length > 48 ? `${a.content.slice(0, 48)}…` : a.content
    return `  │   ann_${String(i + 1).padStart(2, '0')}.dat  ${short}`
  })
  const mem =
    params.members.length > 0
      ? params.members.map((m) => `      └── NODE_ACTIVE :: ${m}`)
      : ['      └── (empty cluster — no peer handshakes)']

  return ['  ./sector_assets/', '  ├── BROADCAST_HEAP/', ...ann, '  └── ONLINE_CLUSTER/', ...mem].join('\n')
}

function getAvatarUrl(seed: string): string {
  return `https://api.dicebear.com/9.x/pixel-art/svg?seed=${encodeURIComponent(seed)}`
}

function toClock(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return '--:--'
  const now = new Date()
  const isToday =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  const hhmm = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  if (isToday) return hhmm
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  const dd = String(date.getDate()).padStart(2, '0')
  return `${mm}-${dd} ${hhmm}`
}

function roomTheme(roomId: string): string {
  return ROOM_THEME_MAP[roomId] ?? 'starry'
}

interface RoomMessageLineProps {
  msg: ChatMessage
  isHistory: boolean
  index?: number
}

function RoomMessageLine({ msg, isHistory, index = 0 }: RoomMessageLineProps) {
  if (msg.type === 'system') {
    if (msg.systemKind === 'cfs') {
      return (
        <div className={`global-chat-system-cfs ${isHistory ? 'animate-pulse-once' : ''}`}>
          <div className="sys-cfs-meta">
            <span className="sys-icon">◈</span>
            <span className="global-chat-system-time">[{toClock(msg.timestamp)}]</span>
            <span className="sys-cfs-tag">CFS</span>
          </div>
          <pre className="sys-cfs-pre">{msg.content}</pre>
        </div>
      )
    }
    const kindClass =
      msg.systemKind === 'join' ? 'sys-join' :
      msg.systemKind === 'leave' ? 'sys-leave' :
      'sys-generic'
    const icon =
      msg.systemKind === 'join' ? '▶' :
      msg.systemKind === 'leave' ? '◀' :
      '◈'
    return (
      <p className={`global-chat-system-line ${kindClass} ${isHistory ? 'animate-pulse-once' : ''}`}>
        <span className="sys-icon">{icon}</span>
        <span className="global-chat-system-time">[{toClock(msg.timestamp)}]</span>
        {' '}{msg.content}
      </p>
    )
  }

  const isOdd = index % 2 === 1

  return (
    <div
      className={`msg-row group rounded-sm transition-colors ${
        isHistory ? 'animate-pulse-once' : ''
      } ${isOdd ? 'msg-row-odd' : 'msg-row-even'}`}
    >
      <p className="msg-inline-line">
        <span className={`msg-sender ${isOdd ? 'msg-sender-odd' : 'msg-sender-even'}`}>
          {msg.sender ?? 'ANON'}
        </span>
        <span className="msg-time-inline">[{toClock(msg.timestamp)}]</span>
        <span className="msg-content-inline">{msg.content}</span>
      </p>
    </div>
  )
}

// ── 公告轮播组件（数据来自父级拉取的 API）────────────────────────
function AnnouncementPanel({ items }: { items: AnnouncementItem[] }) {
  const list = items.length > 0 ? items : FALLBACK_ANNOUNCEMENTS
  const [idx, setIdx] = useState(0)
  const [fade, setFade] = useState(true)

  useEffect(() => {
    setIdx((i) => (i >= list.length ? 0 : i))
  }, [list.length])

  useEffect(() => {
    const timer = window.setInterval(() => {
      setFade(false)
      window.setTimeout(() => {
        setIdx((i) => (i + 1) % list.length)
        setFade(true)
      }, 400)
    }, 6000)
    return () => window.clearInterval(timer)
  }, [list.length])

  const safeIdx = list.length > 0 ? Math.min(idx, list.length - 1) : 0

  return (
    <div className="announcement-panel">
      <div className="announcement-header">
        <span className="dot" />
        <span className="title">BROADCAST<span className="sep">://</span>SIGNAL</span>
        <span className="arrows">▸▸</span>
        <span className="badge">◈&thinsp;ALERT</span>
      </div>
      <div className="announcement-body">
        <div className={`announcement-content ${fade ? 'ann-fade-in' : 'ann-fade-out'}`}>
          <span className="ann-icon">📡</span>
          <span className="ann-text">{list[safeIdx]?.content ?? ''}</span>
        </div>
        <div className="ann-dots">
          {list.map((_, i) => (
            <button
              key={i}
              type="button"
              className={`ann-dot ${i === safeIdx ? 'active' : ''}`}
              onClick={() => { setFade(false); window.setTimeout(() => { setIdx(i); setFade(true) }, 200) }}
              aria-label={`公告 ${i + 1}`}
            />
          ))}
        </div>
      </div>
    </div>
  )
}

// ── 雷达扫描成员组件 ──────────────────────────────────────────
interface RadarScanProps {
  roomName: string
  onClose: () => void
  memberList: string[]
}

// 每个成员在扫描线经过时渐显，延迟由其在列表中的位置决定
const SCAN_DURATION_MS = 2200   // 扫描线从底到顶总时长

function DataWipeOverlay() {
  return (
    <div className="cfs-wipe-overlay" role="presentation" aria-hidden>
      <div className="cfs-wipe-aged" />
      <div className="cfs-wipe-noise" />
      <div className="cfs-wipe-scan" />
      <p className="cfs-wipe-text">SECURE_ERASE · LOCAL_BUFFER_PURGE</p>
    </div>
  )
}

function RadarScan({ roomName, onClose, memberList }: RadarScanProps) {
  const [phase, setPhase] = useState<'scanning' | 'revealed'>('scanning')
  const [visibleCount, setVisibleCount] = useState(0)
  const total = memberList.length

  useEffect(() => {
    if (total === 0) {
      // 无成员时扫完直接跳到 revealed
      const t = window.setTimeout(() => setPhase('revealed'), SCAN_DURATION_MS)
      return () => window.clearTimeout(t)
    }

    // 扫描线从底向上，按比例触发每个成员浮现
    const timers: number[] = []
    for (let i = 0; i < total; i++) {
      // 越靠下（索引大）越先出现（扫描线从下往上）
      const revIdx = total - 1 - i
      const delay = Math.round((revIdx / Math.max(total - 1, 1)) * (SCAN_DURATION_MS * 0.85))
      timers.push(window.setTimeout(() => {
        setVisibleCount((c) => c + 1)
      }, delay))
    }
    const doneTimer = window.setTimeout(() => setPhase('revealed'), SCAN_DURATION_MS)
    timers.push(doneTimer)
    return () => timers.forEach(window.clearTimeout)
  }, [total])

  return (
    <div className="radar-mask" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      {/* 做旧背景层 */}
      <div className="radar-aged" aria-hidden />
      <div className="radar-bg-scanlines" aria-hidden />
      <div className="radar-vignette" aria-hidden />

      {/* 雷达扫描线（仅 scanning 阶段）*/}
      {phase === 'scanning' && (
        <div className="radar-beam" aria-hidden>
          <div className="radar-beam-line" />
          <div className="radar-beam-glow" />
        </div>
      )}

      {/* 顶部标题 */}
      <div className="radar-header">
        <span className="radar-title-blink">▶▶</span>
        <span className="radar-title">SCAN://扇区探测 · {roomName}</span>
        <button type="button" className="radar-close-btn" onClick={onClose}>✕</button>
      </div>

      {/* 成员列表区，从下方往上按位置浮现 */}
      <div className="radar-members">
        {total === 0 ? (
          <div className={`radar-empty ${phase === 'revealed' ? 'radar-member-show' : ''}`}>
            <span>[ 扫描完毕 · 未探测到其他终端 ]</span>
          </div>
        ) : (
          memberList.map((name, i) => {
            // 反序：索引越大越先出现（扫描线从下往上，先扫到底部成员）
            const revIdx = total - 1 - i
            const isVisible = revIdx < visibleCount
            return (
              <div
                key={name}
                className={`radar-member-row ${isVisible ? 'radar-member-show' : ''}`}
                style={{ transitionDelay: `0ms` }}
              >
                <img className="radar-avatar" src={getAvatarUrl(name)} alt={name} />
                <span className="radar-name">{name}</span>
                <span className="radar-node-dot" />
                <span className="radar-node-label">NODE_ACTIVE</span>
              </div>
            )
          })
        )}
      </div>

      {/* 底部状态栏 */}
      <div className="radar-footer">
        <span className={`radar-footer-status ${phase === 'scanning' ? 'radar-scanning-blink' : ''}`}>
          {phase === 'scanning' ? '◈ 扫描中...' : `◈ 探测完毕 · ${total} 个终端`}
        </span>
        {phase === 'revealed' && (
          <button type="button" className="radar-dismiss-btn" onClick={onClose}>
            [ 关闭 ]
          </button>
        )}
      </div>
    </div>
  )
}

export function RoomChat({ embedded = false, loginSeq = 0, cyberName = null }: RoomChatProps) {
  const { room_id } = useParams<{ room_id: string }>()
  const navigate = useNavigate()
  const roomId = useMemo(() => {
    if (!room_id?.trim()) return PRESET_SECTORS[0].id
    return room_id.trim()
  }, [room_id])
  const currentSector = useMemo(
    () => PRESET_SECTORS.find((sector) => sector.id === roomId),
    [roomId],
  )
  const themeName = useMemo(() => roomTheme(roomId), [roomId])
  const roomName = currentSector?.name ?? roomId

  const resolvedCyberName = useMemo(
    () => cyberName ?? window.localStorage.getItem('cyber_name') ?? 'ANON',
    [cyberName],
  )

  const wsRef = useRef<WebSocket | null>(null)
  const wsSeqRef = useRef(0)
  const systemListRef = useRef<HTMLDivElement>(null)
  const userListRef = useRef<HTMLDivElement>(null)
  const switchNavTimerRef = useRef<number | null>(null)
  const historySyncTimerRef = useRef<number | null>(null)
  const sendTimestampsRef = useRef<number[]>([])

  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [rawHistory, setRawHistory] = useState<ChatMessage[]>([])
  const [draft, setDraft] = useState('')
  const [onlineCount, setOnlineCount] = useState(1)
  const [channelState, setChannelState] = useState<'switching' | 'online' | 'offline'>('switching')
  const [chaosFx, setChaosFx] = useState(false)
  const [syncRenderedCount, setSyncRenderedCount] = useState(0)
  const [isHistorySyncing, setIsHistorySyncing] = useState(false)
  const [showMembers, setShowMembers] = useState(false)
  const [memberList, setMemberList] = useState<string[]>([])
  const [inputFocused, setInputFocused] = useState(false)
  const [dataWipe, setDataWipe] = useState(false)
  const [announcements, setAnnouncements] = useState<AnnouncementItem[]>(FALLBACK_ANNOUNCEMENTS)

  useEffect(() => {
    let cancelled = false
    void axios
      .get<AnnouncementsApiResponse>(`${HTTP_BASE_URL}/api/announcements`)
      .then(({ data }) => {
        if (cancelled || !data?.items?.length) return
        setAnnouncements(data.items)
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [])

  const fetchMembersFromApi = useCallback(async () => {
    try {
      const { data } = await axios.get<RoomMembersApi>(
        `${HTTP_BASE_URL}/api/ws/rooms/${encodeURIComponent(roomId)}/members`,
      )
      setMemberList(data.members)
      setOnlineCount(data.online_count)
    } catch {
      // 网络或扇区异常时保留本地 presence 状态
    }
  }, [roomId])

  const fetchMembersRef = useRef(fetchMembersFromApi)
  fetchMembersRef.current = fetchMembersFromApi

  /** 打开雷达时拉取权威成员名单（与 WS 解析解耦） */
  useEffect(() => {
    if (!showMembers) return
    void fetchMembersFromApi()
  }, [showMembers, fetchMembersFromApi])

  const systemMessages = useMemo(() => messages.filter((msg) => msg.type === 'system'), [messages])
  const userMessages = useMemo(() => messages.filter((msg) => msg.type === 'chat'), [messages])

  // ── 本地消息条数上限（与拉取历史 limit、后端 deque 对齐）──
  useEffect(() => {
    setMessages((prev) => {
      if (prev.length <= MAX_ROOM_MESSAGES) return prev
      return prev.slice(-MAX_ROOM_MESSAGES)
    })
  }, [messages.length])

  useEffect(() => {
    const html = document.documentElement
    html.setAttribute('data-theme', themeName)
    return () => {
      html.removeAttribute('data-theme')
    }
  }, [themeName])

  useEffect(() => {
    const token = window.localStorage.getItem('cyber_token')
    if (!token) {
      setChannelState('offline')
      setIsHistorySyncing(false)
      setRawHistory([])
      setMessages([
        {
          id: `sys-${Date.now()}`,
          type: 'system',
          content: '[系统提示] 未检测到身份令牌，请重新登录后接入频道。',
          timestamp: new Date().toISOString(),
        },
      ])
      return
    }

    if (historySyncTimerRef.current) {
      window.clearInterval(historySyncTimerRef.current)
      historySyncTimerRef.current = null
    }

    setChannelState('switching')
    setMessages([])
    setRawHistory([])
    setSyncRenderedCount(0)
    setIsHistorySyncing(true)
    setOnlineCount(1)
    setMemberList([])

    wsRef.current?.close()
    const seq = ++wsSeqRef.current
    const abortController = new AbortController()

    let reconnectTimer: number | null = null
    let handshakeTimer: number | null = null
    let disposed = false

    const openRealtimeLink = (attempt = 0) => {
      if (seq !== wsSeqRef.current) return

      const ws = new WebSocket(
        `${CHAT_WS_BASE_URL}/${encodeURIComponent(roomId)}?token=${encodeURIComponent(token)}`,
      )
      wsRef.current = ws
      handshakeTimer = window.setTimeout(() => {
        if (seq !== wsSeqRef.current || disposed) return
        if (ws.readyState === WebSocket.CONNECTING) {
          ws.close(4000, 'handshake-timeout')
        }
      }, WS_HANDSHAKE_TIMEOUT_MS)

      ws.onopen = () => {
        if (seq !== wsSeqRef.current) return
        if (handshakeTimer != null) {
          window.clearTimeout(handshakeTimer)
          handshakeTimer = null
        }
        setChannelState('online')
      }

      ws.onmessage = (event) => {
        if (seq !== wsSeqRef.current) return
        try {
          const raw = JSON.parse(event.data) as IncomingMessage
          const timestamp = raw.timestamp ?? new Date().toISOString()

          // 识别系统消息类型
          let systemKind: SystemKind = 'generic'
          if (raw.type === 'system') {
            if (/已接入/.test(raw.content)) systemKind = 'join'
            else if (/已断开/.test(raw.content)) systemKind = 'leave'
          }

          const normalized: ChatMessage =
            raw.type === 'chat'
              ? {
                  id: `chat-${timestamp}-${Math.random().toString(16).slice(2)}`,
                  type: 'chat',
                  sender: raw.sender,
                  content: raw.content,
                  timestamp,
                  isHistory: false,
                }
              : {
                  id: `sys-${timestamp}-${Math.random().toString(16).slice(2)}`,
                  type: 'system',
                  systemKind,
                  content: raw.content,
                  timestamp,
                  isHistory: false,
                }

          if (normalized.type === 'system' && raw.type === 'system' && raw.online_count !== undefined) {
            const oc = raw.online_count
            setOnlineCount(oc)
            // 成员列表：先按系统消息增量更新；与 online_count 不一致时以 GET /members 为准
            setMemberList((prev) => {
              let next = prev
              const joinMatch = raw.content.match(WS_JOIN_RE)
              const leaveMatch = raw.content.match(WS_LEAVE_RE)
              if (joinMatch) {
                const name = joinMatch[1]
                next = prev.includes(name) ? prev : [...prev, name]
              } else if (leaveMatch) {
                const name = leaveMatch[1]
                next = prev.filter((n) => n !== name)
              }
              if (next.length !== oc) {
                queueMicrotask(() => {
                  fetchMembersRef.current?.()
                })
              }
              return next
            })
          }

          setMessages((prev) => [...prev, normalized])
        } catch {
          // 忽略异常数据包
        }
      }

      ws.onerror = () => {
        if (seq !== wsSeqRef.current) return
        setChannelState('offline')
      }

      ws.onclose = (evt) => {
        if (seq !== wsSeqRef.current) return
        if (disposed) return
        if (handshakeTimer != null) {
          window.clearTimeout(handshakeTimer)
          handshakeTimer = null
        }
        setChannelState('offline')
        if (attempt >= WS_RETRY_MAX) {
          setMessages((prev) => [
            ...prev,
            {
              id: `sys-ws-close-${Date.now()}-${Math.random().toString(16).slice(2)}`,
              type: 'system',
              systemKind: 'generic',
              content: `[系统提示] 链路断开(code=${evt.code})，请稍后重试或重新接入。`,
              timestamp: new Date().toISOString(),
            },
          ])
          return
        }
        reconnectTimer = window.setTimeout(() => {
          openRealtimeLink(attempt + 1)
        }, WS_RETRY_DELAY_MS)
      }
    }

    const syncHistoryThenConnect = async () => {
      let normalizedHistory: ChatMessage[] = []
      try {
        const response = await axios.get<HistoryApiMessage[]>(
          `${HTTP_BASE_URL}/api/chat/history/${encodeURIComponent(roomId)}`,
          {
            params: { limit: MAX_ROOM_MESSAGES },
            signal: abortController.signal,
            timeout: HISTORY_SYNC_TIMEOUT_MS,
          },
        )

        if (seq !== wsSeqRef.current) return

        normalizedHistory = response.data.map((item, index) => ({
          id: `hist-${roomId}-${index}-${item.timestamp}`,
          type: item.type,
          sender: item.sender ?? undefined,
          content: item.content,
          timestamp: item.timestamp,
          isHistory: true,
          // 历史消息不设过期
        }))
      } catch {
        if (seq !== wsSeqRef.current) return
        setMessages((prev) => [
          ...prev,
          {
            id: `sys-history-failed-${Date.now()}-${Math.random().toString(16).slice(2)}`,
            type: 'system',
            systemKind: 'generic',
            content: '[系统提示] 历史同步失败，已切换至实时链路重试。',
            timestamp: new Date().toISOString(),
          },
        ])
      }

      if (seq !== wsSeqRef.current) return
      setRawHistory(normalizedHistory)

      // 从历史 system 消息中重建初始成员列表（顺序扫描 join/leave）
      const seedMembers: string[] = []
      for (const msg of normalizedHistory) {
        if (msg.type !== 'system') continue
        const joinMatch = msg.content.match(WS_JOIN_RE)
        const leaveMatch = msg.content.match(WS_LEAVE_RE)
        if (joinMatch) {
          const name = joinMatch[1]
          if (!seedMembers.includes(name)) seedMembers.push(name)
        } else if (leaveMatch) {
          const name = leaveMatch[1]
          const idx = seedMembers.indexOf(name)
          if (idx !== -1) seedMembers.splice(idx, 1)
        }
      }
      if (seedMembers.length > 0) {
        setMemberList(seedMembers)
      }

      if (normalizedHistory.length === 0) {
        setIsHistorySyncing(false)
        openRealtimeLink()
        return
      }

      let cursor = 0
      historySyncTimerRef.current = window.setInterval(() => {
        if (seq !== wsSeqRef.current) {
          if (historySyncTimerRef.current) {
            window.clearInterval(historySyncTimerRef.current)
            historySyncTimerRef.current = null
          }
          return
        }

        const batch = normalizedHistory.slice(cursor, cursor + 3)
        if (batch.length === 0) {
          if (historySyncTimerRef.current) {
            window.clearInterval(historySyncTimerRef.current)
            historySyncTimerRef.current = null
          }
          setIsHistorySyncing(false)
          openRealtimeLink()
          return
        }

        cursor += batch.length
        setMessages((prev) => [...prev, ...batch])
        setSyncRenderedCount(cursor)
      }, 50)
    }

    void syncHistoryThenConnect()

    return () => {
      disposed = true
      abortController.abort()
      if (handshakeTimer != null) {
        window.clearTimeout(handshakeTimer)
        handshakeTimer = null
      }
      if (reconnectTimer != null) {
        window.clearTimeout(reconnectTimer)
        reconnectTimer = null
      }
      if (historySyncTimerRef.current) {
        window.clearInterval(historySyncTimerRef.current)
        historySyncTimerRef.current = null
      }
      wsRef.current?.close()
    }
  }, [roomId, loginSeq])

  useEffect(() => {
    if (systemListRef.current) {
      systemListRef.current.scrollTo({
        top: systemListRef.current.scrollHeight,
        behavior: 'smooth',
      })
    }
    if (!userListRef.current) return
    userListRef.current.scrollTo({
      top: userListRef.current.scrollHeight,
      behavior: isHistorySyncing ? 'auto' : 'smooth',
    })
  }, [systemMessages, userMessages, isHistorySyncing])

  useEffect(() => {
    if (!dataWipe) return
    const done = window.setTimeout(() => {
      setMessages([
        {
          id: `cfs-erase-${Date.now()}`,
          type: 'system',
          systemKind: 'generic',
          content: '[CFS] SECURE_ERASE 完成 · 本地缓冲区已归零',
          timestamp: new Date().toISOString(),
        },
      ])
      setDataWipe(false)
    }, 2000)
    return () => window.clearTimeout(done)
  }, [dataWipe])

  const handleSend = () => {
    const content = draft.trim()
    if (!content) return

    if (isCfsSlashCommand(content)) {
      const cmd = content.trim().toLowerCase()
      if (cmd === '/whoami') {
        setMessages((prev) => [
          ...prev,
          {
            id: `cfs-${Date.now()}-${Math.random().toString(16).slice(2)}`,
            type: 'system',
            systemKind: 'cfs',
            content: buildCfsWhoami({
              cyberName: resolvedCyberName,
              roomId,
              roomName,
            }),
            timestamp: new Date().toISOString(),
          },
        ])
        setDraft('')
        return
      }
      if (cmd === '/ls') {
        const self = window.localStorage.getItem('cyber_name')
        const merged = [...new Set([...(self ? [self] : []), ...memberList])]
        setMessages((prev) => [
          ...prev,
          {
            id: `cfs-${Date.now()}-${Math.random().toString(16).slice(2)}`,
            type: 'system',
            systemKind: 'cfs',
            content: buildCfsLs({ roomName, members: merged, announcements }),
            timestamp: new Date().toISOString(),
          },
        ])
        setDraft('')
        return
      }
      if (cmd === '/clear') {
        setMessages([])
        setDataWipe(true)
        setDraft('')
        return
      }
    }

    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return
    const now = Date.now()
    const recent = sendTimestampsRef.current.filter((ts) => now - ts < CHAT_RATE_LIMIT.windowMs)
    if (recent.length >= CHAT_RATE_LIMIT.maxSendsPerSecond) {
      setMessages((prev) => [
        ...prev,
        {
          id: `sys-rate-limit-${now}-${Math.random().toString(16).slice(2)}`,
          type: 'system',
          systemKind: 'generic',
          content: '[系统提示] 发送过快：每位用户每秒最多发送 2 条消息。',
          timestamp: new Date().toISOString(),
        },
      ])
      return
    }
    recent.push(now)
    sendTimestampsRef.current = recent
    wsRef.current.send(content)
    setDraft('')
  }

  const handleSwitchSector = (targetRoomId: string) => {
    if (!targetRoomId || targetRoomId === roomId) return

    setChannelState('switching')
    wsRef.current?.close()
    setChaosFx(true)

    const targetPath = `/chat/${targetRoomId}`
    if (switchNavTimerRef.current) window.clearTimeout(switchNavTimerRef.current)
    switchNavTimerRef.current = window.setTimeout(() => {
      navigate(targetPath)
      setChaosFx(false)
    }, 600)
  }

  useEffect(() => {
    return () => {
      if (switchNavTimerRef.current) window.clearTimeout(switchNavTimerRef.current)
    }
  }, [])

  return (
    <div
      className="page room-chat-page"
      data-theme={themeName}
      style={{ height: '100%', width: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}
    >
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }} className={`border-2 border-t-white border-l-white border-r-gray-700 border-b-gray-700 bg-[#bdbdbd] p-[3px] ${embedded ? '' : 'shadow-[8px_8px_0_#1c1c1c]'}`}>
        <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', position: 'relative' }} className={`global-chat-grain border-2 border-t-gray-700 border-l-gray-700 border-r-white border-b-white bg-[#090910]`}>

          {/* ── Tab 栏 ── */}
          <div className="shrink-0 border-b border-[#463264] bg-[#15112a]" style={{ overflowX: 'auto', overflowY: 'hidden', WebkitOverflowScrolling: 'touch' }}>
            <div className="flex gap-2 px-2 py-2" style={{ width: 'max-content', minWidth: '100%' }}>
              {PRESET_SECTORS.map((sector) => (
                <button
                  key={sector.id}
                  type="button"
                  className={`room-tab room-sector-tab ${roomId === sector.id ? 'active' : ''}`}
                  onClick={() => handleSwitchSector(sector.id)}
                >
                  #{sector.name}
                </button>
              ))}
            </div>
          </div>

          {/* ── 三区主体（flex 竖排）── */}
          <div
            style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', padding: '12px', gap: '6px' }}
            className="room-theme-frame border-l-2 border-r-2 font-mono text-[13px] leading-relaxed"
          >
            {/* 公告区 BROADCAST://SIGNAL 12% */}
            <div style={{ flex: '0 0 12%', minHeight: '60px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
              <AnnouncementPanel items={announcements} />
            </div>

            {/* 系统消息区 SYS://FEED 18% */}
            <div style={{ flex: '0 0 18%', minHeight: '60px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }} className="room-sys-panel border">
              <div className="panel-header-sys">
                <span className="dot" />
                <span className="title">SYS<span className="sep">://</span>FEED</span>
                <span className="arrows">▸▸</span>
                <span className="badge">◈&thinsp;MONITOR</span>
              </div>
              <div ref={systemListRef} style={{ flex: 1, minHeight: 0, overflowY: 'auto' }} className="space-y-1 px-2 py-2">
                {systemMessages.length === 0 ? (
                  <p className="room-theme-muted text-[12px]">[系统提示] 暂无系统信号</p>
                ) : (
                  systemMessages.map((msg) => (
                    <RoomMessageLine key={msg.id} msg={msg} isHistory={Boolean(msg.isHistory)} />
                  ))
                )}
              </div>
            </div>

            {/* 用户消息区 USR://STREAM，flex:1 吃剩余空间 */}
            <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }} className="room-usr-panel border">
              <div className="panel-header-usr">
                <span className={`dot ${channelState === 'online' ? 'online' : 'offline'}`} />
                <span className="title">USR<span className="sep">://</span>STREAM</span>
                <span className="arrows">▸▸</span>
                <span className="online-count">ONLINE&thinsp;<strong>{onlineCount}</strong></span>
                <span className={`badge ${channelState === 'online' ? 'online' : 'offline'}`}>◈&thinsp;LIVE</span>
              </div>
              <div ref={userListRef} style={{ flex: 1, minHeight: 0, overflowY: 'auto', overscrollBehavior: 'contain' }} className="px-2 py-2">
                {userMessages.length === 0 && (
                  <p className="text-gray-500 font-mono text-[12px]">[系统提示] 正在接入扇区主干网络...</p>
                )}
                {(() => {
                  const lastHistoryIdx = userMessages.map((m) => m.isHistory).lastIndexOf(true)
                  const showDivider = !isHistorySyncing && lastHistoryIdx >= 0
                  return userMessages.map((msg, idx) => (
                    <>
                      <RoomMessageLine key={msg.id} msg={msg} isHistory={Boolean(msg.isHistory)} index={idx} />
                      {showDivider && idx === lastHistoryIdx && (
                        <div key="echo-divider" className="data-echo-divider">DATA ECHO · 数据残响 ▾</div>
                      )}
                    </>
                  ))
                })()}
              </div>
            </div>
          </div>

          {/* ── 历史同步进度条 ── */}
          {isHistorySyncing && (
            <div className="room-sync-panel shrink-0 border-t px-3 py-2 font-mono text-[12px]">
              <div className="mb-2 flex items-center justify-between animate-pulse">
                <span>[ 同步中: {Math.min(syncRenderedCount, MAX_ROOM_MESSAGES)}/{MAX_ROOM_MESSAGES} ]</span>
                <span>{rawHistory.length} buffered</span>
              </div>
              <div className="room-sync-progress-track h-2 overflow-hidden border bg-black/80">
                <div
                  className="room-sync-progress-fill h-full transition-[width] duration-75"
                  style={{ width: `${Math.max(2, (Math.min(syncRenderedCount, MAX_ROOM_MESSAGES) / MAX_ROOM_MESSAGES) * 100)}%` }}
                />
              </div>
            </div>
          )}

          {/* ── 命令面板（输入区 5% 占位由 flex-shrink:0 控制）── */}
          <div className={`cmd-panel ${inputFocused ? 'cmd-panel-powered' : ''}`}>
            {/* 探测成员图标按钮 */}
            <button
              type="button"
              className="cmd-scan-icon-btn"
              onClick={() => setShowMembers(true)}
              title="探测当前扇区在线终端"
              aria-label="探测成员"
            >
              <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.5" />
                <circle cx="12" cy="12" r="5" stroke="currentColor" strokeWidth="1" strokeDasharray="2 2" />
                <line x1="12" y1="12" x2="12" y2="3" stroke="currentColor" strokeWidth="1.5" className="radar-sweep-hand" />
                <circle cx="12" cy="12" r="1.5" fill="currentColor" />
              </svg>
            </button>

            <label className="cmd-input-wrap">
              <span className="cmd-prompt">&gt; //</span>
              <input
                className={`cmd-input ${channelState !== 'online' ? 'cmd-input-offline' : ''}`}
                placeholder={
                  channelState === 'online'
                    ? '终端信号源 · /whoami /ls /clear · 全频段广播..._'
                    : '[ 链路断开 · CFS 伪指令仍可用: /whoami /ls /clear ]'
                }
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSend()
                }}
                onFocus={() => setInputFocused(true)}
                onBlur={() => setInputFocused(false)}
                autoComplete="off"
                autoCorrect="off"
                autoCapitalize="off"
                spellCheck={false}
              />
            </label>
            <button
              type="button"
              className={`cmd-exec-btn ${channelState !== 'online' && !isCfsSlashCommand(draft) ? 'cmd-exec-btn-offline' : ''}`}
              onClick={handleSend}
              disabled={channelState !== 'online' && !isCfsSlashCommand(draft)}
            >
              <span>[ 传输<br />TX ]</span>
            </button>
          </div>

          {/* ── 切换频道遮罩 ── */}
          {channelState === 'switching' && (
            <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center bg-black/68">
              <div className="room-switch-card w-[82%] max-w-[560px] border p-4 font-mono">
                <p className="mb-3 text-center text-sm">
                  [ 正在切换频段至 SECTOR-{roomId} ({roomName})... ]
                </p>
                <div className="room-switch-progress-track h-2 overflow-hidden border bg-black/80">
                  <div className="room-switch-progress h-full w-1/2" />
                </div>
              </div>
            </div>
          )}

          {chaosFx && (
            <div className="room-chaos-overlay" aria-hidden>
              <div className="room-chaos-noise"></div>
              <p className="room-chaos-text">[ SIGNALYLOST ]</p>
            </div>
          )}

          {dataWipe && <DataWipeOverlay />}
        </div>
      </div>

      {/* ── 雷达扫描蒙层 ── */}
      {showMembers && (
        <RadarScan
          roomName={roomName}
          onClose={() => setShowMembers(false)}
          memberList={memberList}
        />
      )}
    </div>
  )
}
