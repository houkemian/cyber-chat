import axios from 'axios'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { CHAT_WS_BASE_URL, HTTP_BASE_URL } from '../config/api'

// ── 消息生命周期配置（分钟）──────────────────────────────────
const MESSAGE_LIFETIME_MINUTES = 1

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

type SystemKind = 'join' | 'leave' | 'generic'

type ChatMessage = {
  id: string
  type: 'chat' | 'system'
  systemKind?: SystemKind  // system 消息的细分类型，用于视觉区分
  sender?: string
  content: string
  timestamp: string
  isHistory?: boolean
  expiresAt?: number   // unix ms，undefined 表示系统消息或历史消息不过期
  dissolving?: boolean // 触发像素散开动画
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
}

const PRESET_SECTORS = [
  { id: 'sector-001', name: '午夜心碎俱乐部' },
  { id: 'sector-404', name: '赛博酒保' },
  { id: 'sector-777', name: '黑客帝国' },
  { id: 'sector-999', name: '星空物语' },
]

// ── 公告数据（静态，后续可改为 API 下发）───────────────────────
const ANNOUNCEMENTS = [
  { id: 'ann-1', content: '欢迎接入赛博树洞 2000.exe · 禁止实名，允许发疯。所有消息将在 1 分钟后自毁。' },
  { id: 'ann-2', content: '当前节点状态稳定 · 多扇区同步运行中 · 请文明发言，共同维护数字秩序。' },
  { id: 'ann-3', content: '系统公告：Phase-3 升级中 · AI 气氛组即将接入 · 敬请期待更多赛博体验。' },
]

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
  if (roomId.includes('001')) return 'border-cyan-400/60 shadow-[0_0_20px_rgba(34,211,238,0.2)]'
  if (roomId.includes('404')) return 'border-amber-400/60 shadow-[0_0_20px_rgba(251,191,36,0.2)]'
  return 'border-fuchsia-400/60 shadow-[0_0_20px_rgba(217,70,239,0.22)]'
}

interface RoomMessageLineProps {
  msg: ChatMessage
  isHistory: boolean
  index?: number
}

function RoomMessageLine({ msg, isHistory, index = 0 }: RoomMessageLineProps) {
  if (msg.type === 'system') {
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
      } ${isOdd ? 'msg-row-odd' : 'msg-row-even'} ${msg.dissolving ? 'msg-dissolve' : ''}`}
    >
      <p className="msg-inline-line">
        <span className={`msg-sender ${isOdd ? 'text-fuchsia-300' : 'text-cyan-400'}`}>
          {msg.sender ?? 'ANON'}
        </span>
        <span className="msg-time-inline">[{toClock(msg.timestamp)}]</span>
        <span className="msg-content-inline">{msg.content}</span>
      </p>
    </div>
  )
}

// ── 公告轮播组件 ──────────────────────────────────────────────
function AnnouncementPanel() {
  const [idx, setIdx] = useState(0)
  const [fade, setFade] = useState(true)

  useEffect(() => {
    const timer = window.setInterval(() => {
      setFade(false)
      window.setTimeout(() => {
        setIdx((i) => (i + 1) % ANNOUNCEMENTS.length)
        setFade(true)
      }, 400)
    }, 6000)
    return () => window.clearInterval(timer)
  }, [])

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
          <span className="ann-text">{ANNOUNCEMENTS[idx].content}</span>
        </div>
        <div className="ann-dots">
          {ANNOUNCEMENTS.map((_, i) => (
            <button
              key={i}
              type="button"
              className={`ann-dot ${i === idx ? 'active' : ''}`}
              onClick={() => { setFade(false); window.setTimeout(() => { setIdx(i); setFade(true) }, 200) }}
              aria-label={`公告 ${i + 1}`}
            />
          ))}
        </div>
      </div>
    </div>
  )
}

// ── 在线成员蒙层 ──────────────────────────────────────────────
interface MembersOverlayProps {
  roomName: string
  onClose: () => void
  memberList: string[]
}

function MembersOverlay({ roomName, onClose, memberList }: MembersOverlayProps) {
  return (
    <div className="members-overlay-mask" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="members-overlay-box">
        {/* 做旧纹理层 */}
        <div className="members-aged-layer" aria-hidden />
        <div className="members-scanlines" aria-hidden />
        <div className="members-vignette" aria-hidden />

        <div className="members-overlay-header">
          <span className="members-overlay-title">
            <span className="members-title-blink">▶</span>
            {' '}SCAN://扇区探测 · {roomName}
          </span>
          <button type="button" className="members-overlay-close" onClick={onClose}>✕</button>
        </div>
        <div className="members-overlay-list">
          {memberList.length === 0 ? (
            <p className="members-empty">[ 探测范围内无新增终端 ]<br /><span className="members-empty-sub">仅显示您接入后上线的用户</span></p>
          ) : (
            memberList.map((name, i) => (
              <div key={i} className="members-item">
                <img
                  className="members-avatar"
                  src={getAvatarUrl(name)}
                  alt={name}
                />
                <span className="members-name">{name}</span>
                <span className="members-status-dot" />
              </div>
            ))
          )}
        </div>
        <div className="members-overlay-footer">
          ◈ LIVE NODES · {memberList.length} 个终端已被探测
        </div>
      </div>
    </div>
  )
}

export function RoomChat({ embedded = false, loginSeq = 0 }: RoomChatProps) {
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
  const roomName = currentSector?.name ?? roomId

  const wsRef = useRef<WebSocket | null>(null)
  const wsSeqRef = useRef(0)
  const systemListRef = useRef<HTMLDivElement>(null)
  const userListRef = useRef<HTMLDivElement>(null)
  const switchNavTimerRef = useRef<number | null>(null)
  const historySyncTimerRef = useRef<number | null>(null)
  const lifetimeTimerRef = useRef<number | null>(null)

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

  const syncExpectedCount = 200
  const systemMessages = useMemo(() => messages.filter((msg) => msg.type === 'system'), [messages])
  const userMessages = useMemo(() => messages.filter((msg) => msg.type === 'chat'), [messages])

  // ── 消息生命周期：每 5s 扫描，到期先 dissolving，800ms 后移除 ──
  useEffect(() => {
    lifetimeTimerRef.current = window.setInterval(() => {
      const now = Date.now()
      setMessages((prev) => {
        let changed = false
        const updated = prev.map((m) => {
          if (m.expiresAt && !m.dissolving && m.expiresAt <= now) {
            changed = true
            return { ...m, dissolving: true }
          }
          return m
        })
        if (!changed) return prev

        // 800ms 后彻底删除正在散开的消息
        window.setTimeout(() => {
          setMessages((p) => p.filter((m) => !m.dissolving))
        }, 800)
        return updated
      })
    }, 5000)
    return () => {
      if (lifetimeTimerRef.current) window.clearInterval(lifetimeTimerRef.current)
    }
  }, [])

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

    const openRealtimeLink = () => {
      if (seq !== wsSeqRef.current) return

      const ws = new WebSocket(
        `${CHAT_WS_BASE_URL}/${encodeURIComponent(roomId)}?token=${encodeURIComponent(token)}`,
      )
      wsRef.current = ws

      ws.onopen = () => {
        if (seq !== wsSeqRef.current) return
        setChannelState('online')
      }

      ws.onmessage = (event) => {
        if (seq !== wsSeqRef.current) return
        try {
          const raw = JSON.parse(event.data) as IncomingMessage
          const timestamp = raw.timestamp ?? new Date().toISOString()
          const lifetimeMs = MESSAGE_LIFETIME_MINUTES * 60 * 1000

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
                  expiresAt: Date.now() + lifetimeMs,
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
            setOnlineCount(raw.online_count)
            // 成员列表：追踪当前房间所有在线用户（接入加入，断开移除）
            setMemberList((prev) => {
              const joinMatch = raw.content.match(/终端\s+(\S+)\s+已接入/)
              const leaveMatch = raw.content.match(/终端\s+(\S+)\s+已断开/)
              if (joinMatch) {
                const name = joinMatch[1]
                return prev.includes(name) ? prev : [...prev, name]
              }
              if (leaveMatch) {
                const name = leaveMatch[1]
                return prev.filter((n) => n !== name)
              }
              return prev
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

      ws.onclose = () => {
        if (seq !== wsSeqRef.current) return
        setChannelState('offline')
      }
    }

    const syncHistoryThenConnect = async () => {
      let normalizedHistory: ChatMessage[] = []
      try {
        const response = await axios.get<HistoryApiMessage[]>(
          `${HTTP_BASE_URL}/api/chat/history/${encodeURIComponent(roomId)}`,
          {
            params: { limit: syncExpectedCount },
            signal: abortController.signal,
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
      }

      if (seq !== wsSeqRef.current) return
      setRawHistory(normalizedHistory)

      // 从历史 system 消息中重建初始成员列表（顺序扫描 join/leave）
      const seedMembers: string[] = []
      for (const msg of normalizedHistory) {
        if (msg.type !== 'system') continue
        const joinMatch = msg.content.match(/终端\s+(\S+)\s+已接入/)
        const leaveMatch = msg.content.match(/终端\s+(\S+)\s+已断开/)
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
      abortController.abort()
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

  const handleSend = () => {
    const content = draft.trim()
    if (!content) return
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return
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
    <div style={{ height: '100%', width: '100%', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
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
            className={`border-l-2 border-r-2 font-mono text-[13px] leading-relaxed ${roomTheme(roomId)}`}
          >
            {/* 公告区 15% */}
            <div style={{ flex: '0 0 15%', minHeight: '60px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
              <AnnouncementPanel />
            </div>

            {/* 系统消息区 15% */}
            <div style={{ flex: '0 0 15%', minHeight: '60px', overflow: 'hidden', display: 'flex', flexDirection: 'column' }} className="border border-amber-300/35 bg-[#15100b]/65">
              <div className="panel-header-sys">
                <span className="dot" />
                <span className="title">SYS<span className="sep">://</span>FEED</span>
                <span className="arrows">▸▸</span>
                <span className="badge">◈&thinsp;MONITOR</span>
              </div>
              <div ref={systemListRef} style={{ flex: 1, minHeight: 0, overflowY: 'auto' }} className="space-y-1 px-2 py-2">
                {systemMessages.length === 0 ? (
                  <p className="text-[12px] text-amber-200/70">[系统提示] 暂无系统信号</p>
                ) : (
                  systemMessages.map((msg) => (
                    <RoomMessageLine key={msg.id} msg={msg} isHistory={Boolean(msg.isHistory)} />
                  ))
                )}
              </div>
            </div>

            {/* 用户消息区 65%，吃剩余空间 */}
            <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }} className="border border-cyan-400/35 bg-[#0b1223]/62">
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
            <div className="shrink-0 border-t border-[#2d2d2d] bg-[#09070f] px-3 py-2 font-mono text-[12px] text-cyan-200">
              <div className="mb-2 flex items-center justify-between animate-pulse">
                <span>[ 同步中: {Math.min(syncRenderedCount, syncExpectedCount)}/{syncExpectedCount} ]</span>
                <span>{rawHistory.length} buffered</span>
              </div>
              <div className="h-2 overflow-hidden border border-cyan-400/45 bg-black/80">
                <div
                  className="h-full bg-[linear-gradient(90deg,#00f0ff,#bc00ff,#39ff14)] transition-[width] duration-75"
                  style={{ width: `${Math.max(2, (Math.min(syncRenderedCount, syncExpectedCount) / syncExpectedCount) * 100)}%` }}
                />
              </div>
            </div>
          )}

          {/* ── 命令面板（输入区 5% 占位由 flex-shrink:0 控制）── */}
          <div className="cmd-panel">
            {/* 探测成员按钮 */}
            <button
              type="button"
              className="cmd-members-btn"
              onClick={() => setShowMembers(true)}
              title="探测当前扇区在线终端"
            >
              <span>[ 探测<br />SCAN ]</span>
            </button>

            <label className="cmd-input-wrap">
              <span className="cmd-prompt">&gt; //</span>
              <input
                className={`cmd-input ${channelState !== 'online' ? 'cmd-input-offline' : ''}`}
                placeholder={channelState !== 'online' ? '[ 链路断开 · 无法发送 ]' : '终端信号源 · 输入全频段广播消息..._'}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSend()
                }}
                autoComplete="off"
                autoCorrect="off"
                autoCapitalize="off"
                spellCheck={false}
                disabled={channelState !== 'online'}
              />
            </label>
            <button
              type="button"
              className={`cmd-exec-btn ${channelState !== 'online' ? 'cmd-exec-btn-offline' : ''}`}
              onClick={handleSend}
              disabled={channelState !== 'online'}
            >
              <span>[ 执行传输<br />X-MISSION ]</span>
            </button>
          </div>

          {/* ── 切换频道遮罩 ── */}
          {channelState === 'switching' && (
            <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center bg-black/68">
              <div className="w-[82%] max-w-[560px] border border-cyan-400/60 bg-[#080a17]/95 p-4 font-mono text-cyan-200 shadow-[0_0_18px_rgba(34,211,238,0.2)]">
                <p className="mb-3 text-center text-sm">
                  [ 正在切换频段至 SECTOR-{roomId} ({roomName})... ]
                </p>
                <div className="h-2 overflow-hidden border border-cyan-400/45 bg-black/80">
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
        </div>
      </div>

      {/* ── 在线成员蒙层 ── */}
      {showMembers && (
        <MembersOverlay
          roomName={roomName}
          onClose={() => setShowMembers(false)}
          memberList={memberList}
        />
      )}
    </div>
  )
}
