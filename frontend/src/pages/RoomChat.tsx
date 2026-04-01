import axios from 'axios'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { CHAT_WS_BASE_URL, HTTP_BASE_URL } from '../config/api'

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
    }

type ChatMessage = {
  id: string
  type: 'chat' | 'system'
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
}

const PRESET_SECTORS = [
  { id: 'sector-001', name: '午夜心碎俱乐部' },
  { id: 'sector-404', name: '赛博酒保' },
  { id: 'sector-777', name: '黑客帝国' },
  { id: 'sector-999', name: '星空物语' },
]

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
}

function RoomMessageLine({ msg, isHistory }: RoomMessageLineProps) {
  if (msg.type === 'system') {
    return (
      <p className={`global-chat-system-line ${isHistory ? 'animate-pulse-once' : ''}`}>
        <span className="global-chat-system-time">[{toClock(msg.timestamp)}]</span> {msg.content}
      </p>
    )
  }

  return (
    <div
      className={`group mb-3 rounded-sm py-1 transition-colors hover:bg-cyan-900/20 ${
        isHistory ? 'animate-pulse-once' : ''
      } border-b border-dashed border-cyan-900/50`}
    >
      <div className="flex items-center">
        <span className="font-semibold text-cyan-400 drop-shadow-[0_0_6px_rgba(34,211,238,0.6)]">
          {msg.sender ?? 'ANON'}
        </span>
        <span className="ml-2 text-xs text-slate-500">[{toClock(msg.timestamp)}]</span>
      </div>
      <p className="ml-3 mt-1 whitespace-pre-wrap text-gray-200 leading-relaxed [text-shadow:0_0_2px_rgba(255,255,255,0.2)]">
        {msg.content}
      </p>
    </div>
  )
}

export function RoomChat({ embedded = false }: RoomChatProps) {
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
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [rawHistory, setRawHistory] = useState<ChatMessage[]>([])
  const [draft, setDraft] = useState('')
  const [onlineCount, setOnlineCount] = useState(1)
  const [channelState, setChannelState] = useState<'switching' | 'online' | 'offline'>('switching')
  const [chaosFx, setChaosFx] = useState(false)
  const [syncRenderedCount, setSyncRenderedCount] = useState(0)
  const [isHistorySyncing, setIsHistorySyncing] = useState(false)

  const syncExpectedCount = 200
  const systemMessages = useMemo(() => messages.filter((msg) => msg.type === 'system'), [messages])
  const userMessages = useMemo(() => messages.filter((msg) => msg.type === 'chat'), [messages])

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
                  content: raw.content,
                  timestamp,
                  isHistory: false,
                }

          if (normalized.type === 'system') {
            const isJoinSignal = normalized.content.includes('已接入扇区')
            const isLeaveSignal = normalized.content.includes('已断开扇区')
            if (isJoinSignal) setOnlineCount((n) => n + 1)
            if (isLeaveSignal) setOnlineCount((n) => Math.max(0, n - 1))
          }

          setMessages((prev) => [...prev, normalized])
        } catch {
          // 忽略异常数据包，保持终端稳定。
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
        }))
      } catch {
        if (seq !== wsSeqRef.current) return
      }

      if (seq !== wsSeqRef.current) return
      setRawHistory(normalizedHistory)

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
  }, [roomId])

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

    // 先主动切到 switching，并关闭当前链路，避免旧房间残留消息。
    setChannelState('switching')
    wsRef.current?.close()
    setChaosFx(true)

    const targetPath = `/chat/${targetRoomId}`
    if (switchNavTimerRef.current) window.clearTimeout(switchNavTimerRef.current)
    switchNavTimerRef.current = window.setTimeout(() => {
      // 使用 React Router navigate，basename 会自动补全 /cyber-chat 前缀
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

          <div
            style={{ flex: 1, minHeight: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', padding: '12px' }}
            className={`border-l-2 border-r-2 font-mono text-[13px] leading-relaxed ${roomTheme(roomId)}`}
          >
            {/* 系统消息区：固定 20%，最小 96px */}
            <div style={{ flexShrink: 0, height: '20%', minHeight: '96px', overflow: 'hidden', display: 'flex', flexDirection: 'column', marginBottom: '8px' }} className="border border-amber-300/35 bg-[#15100b]/65">
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

            {/* 用户消息区：吃剩余全部高度，内部滚动 */}
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
                  // 历史同步完成后，分割线固定插在最后一条历史消息之后
                  const showDivider = !isHistorySyncing && lastHistoryIdx >= 0
                  return userMessages.map((msg, idx) => (
                    <>
                      <RoomMessageLine key={msg.id} msg={msg} isHistory={Boolean(msg.isHistory)} />
                      {showDivider && idx === lastHistoryIdx && (
                        <div key="echo-divider" className="data-echo-divider">DATA ECHO · 数据残响 ▾</div>
                      )}
                    </>
                  ))
                })()}
              </div>
            </div>
          </div>

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

          <div className="cmd-panel">
            <label className="cmd-input-wrap">
              <span className="cmd-prompt">&gt; //</span>
              <input
                className="cmd-input"
                placeholder="终端信号源 · 输入全频段广播消息..._"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSend()
                }}
                autoComplete="off"
                autoCorrect="off"
                autoCapitalize="off"
                spellCheck={false}
              />
            </label>
            <button type="button" className="cmd-exec-btn" onClick={handleSend}>
              <span>[ 执行传输<br />X-MISSION ]</span>
            </button>
          </div>

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
    </div>
  )
}

