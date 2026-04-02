import { useCallback, useEffect, useRef, useState } from 'react'
import { Navigate, Route, Routes, useNavigate } from 'react-router-dom'
import { LoginTerminal } from './pages/LoginTerminal'
import { RoomChat } from './pages/RoomChat'

const DEFAULT_ROOM_ID = 'sector-001'
const AVATAR_STORAGE_KEY = 'cyber_avatar_idx'

// ── 扩展头像池：保留像素人像 + 新增物件种子 ──────────────────
// 前 4 个为像素人像（使用 pixel-art style），后续为物件风格
const AVATAR_POOL = [
  // 像素人像（以 cyberName 为动态种子，此处用占位符 __NAME__）
  { seed: '__NAME__', label: '身份像', icon: '👤' },
  // 物件头像
  { seed: 'mini-red-umbrella-2000', label: '小雨伞', icon: '☂️' },
  { seed: 'cactus-pixel-verde', label: '仙人掌', icon: '🌵' },
  { seed: 'retro-computer-9x-boot', label: '小电脑', icon: '💻' },
  { seed: 'floppy-disk-cyber-wave', label: '磁碟片', icon: '💾' },
  { seed: 'gameboy-neon-blink-99', label: '游戏机', icon: '🎮' },
  { seed: 'satellite-orbit-signal', label: '卫星锅', icon: '📡' },
  { seed: 'coffee-mug-terminal-hot', label: '咖啡杯', icon: '☕' },
  { seed: 'alien-capsule-static', label: '外星舱', icon: '🛸' },
  { seed: 'cassette-tape-rewind88', label: '磁带机', icon: '📼' },
  { seed: 'pixel-robot-unit-zero', label: '机器人', icon: '🤖' },
]

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [cyberName, setCyberName] = useState<string | null>(null)
  const [showLogin, setShowLogin] = useState(false)
  const [noisePhase, setNoisePhase] = useState(0)
  const [chatHeight, setChatHeight] = useState('60vh')
  const [loginSeq, setLoginSeq] = useState(0)
  const [avatarIdx] = useState(() => {
    const saved = window.localStorage.getItem(AVATAR_STORAGE_KEY)
    return saved ? Number(saved) : 0
  })
  const headerRef = useRef<HTMLElement>(null)
  const navigate = useNavigate()

  const currentAvatarEntry = AVATAR_POOL[avatarIdx] ?? AVATAR_POOL[0]
  const avatarSeed = currentAvatarEntry.seed === '__NAME__'
    ? (cyberName ?? 'midnight')
    : currentAvatarEntry.seed
  const avatarUrl = `https://api.dicebear.com/9.x/pixel-art/svg?seed=${encodeURIComponent(avatarSeed)}`

  // 动态计算聊天区精确高度：视口高度 - header高度 - container上下padding - gap
  useEffect(() => {
    const recalc = () => {
      if (!headerRef.current) return
      const headerH = headerRef.current.getBoundingClientRect().height
      // container padding: 16px top + 16px bottom = 32px；gap between header and section: 14px
      // 移动端用 dvh 单位（随地址栏动态收缩），桌面降级到 vh
      const vhUnit = CSS.supports('height', '1dvh') ? 'dvh' : 'vh'
      // container padding: 16px top + 16px bottom = 32px；gap: 14px
      // 移动端 padding 已压缩至 8px，故 reserved 更小
      const isMobile = window.innerWidth <= 480
      const containerPad = isMobile ? 16 : 32   // 8px top+bottom on mobile
      const gapVal = isMobile ? 8 : 14
      const reserved = headerH + containerPad + gapVal
      setChatHeight(`calc(100${vhUnit} - ${reserved}px)`)
    }
    recalc()
    window.addEventListener('resize', recalc)
    return () => window.removeEventListener('resize', recalc)
  }, [])

  // UI 轻量噪声节拍：用于头像和按钮的微抖动/颗粒偏移
  useEffect(() => {
    const id = window.setInterval(() => {
      setNoisePhase(Math.floor(Math.random() * 4))
    }, 170)
    return () => window.clearInterval(id)
  }, [])

  // 启动时读取登录态
  useEffect(() => {
    const token = window.localStorage.getItem('cyber_token')
    const name = window.localStorage.getItem('cyber_name')
    if (token) {
      setIsLoggedIn(true)
      setCyberName(name)
    }
  }, [])

  // 登录成功回调：关闭弹层，刷新状态
  const handleLoginSuccess = useCallback((name: string) => {
    setIsLoggedIn(true)
    setCyberName(name)
    setShowLogin(false)
    setLoginSeq((n) => n + 1)
    navigate(`/chat/${DEFAULT_ROOM_ID}`, { replace: true })
  }, [navigate])

  const logout = () => {
    window.localStorage.removeItem('cyber_token')
    window.localStorage.removeItem('cyber_name')
    setIsLoggedIn(false)
    setCyberName(null)
    // loginSeq +1 触发 RoomChat effect 重跑，读取 token 为空进入 offline 分支，关闭 WS
    setLoginSeq((n) => n + 1)
    navigate(`/chat/${DEFAULT_ROOM_ID}`, { replace: true })
  }

  return (
    <div className="crt-container">
      {/* ── 主页面 ── */}
      <div className="page overflow-hidden" data-noise-phase={noisePhase}>
        <div className="fx-layer">
          <span className="spark spark-cyan"></span>
          <span className="spark spark-pink"></span>
          <span className="spark spark-cyan spark-slow"></span>
          <span className="scanline"></span>
        </div>

        <div className="container">
          {/* 顶栏：index.css `.header`（`--header-h-scale`、右侧与 `--chat-panel-r-inset` 对齐下方三区右边界；`.header-top` 垂直居中） */}
          <header ref={headerRef} className="card header shrink-0">
            <div className="header-top">
              <div>
                <p className="tag">禁止实名，允许发疯。</p>
                <h1 className="title neon-flicker">2000.exe</h1>
              </div>
              <div className="auth-area">
                {isLoggedIn ? (
                  <div className="user-avatar-wrap">
                    <div className="user-avatar-shell" aria-hidden>
                      <img className="user-avatar" src={avatarUrl} alt="用户头像" />
                      <span className="avatar-crt-mask"></span>
                      <span className="avatar-static-noise"></span>
                    </div>
                    <div className="user-menu">
                      <div className="user-menu-item user-menu-name">
                        {'>> 当前身份密匙 (Uplink Key):'}
                        <br />
                        {cyberName ?? 'ANON'}
                      </div>
                      <button type="button" className="user-menu-item" onClick={logout}>
                        {'终止当前进程 (Terminate PID)'}
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="auth-actions">
                    <button
                      type="button"
                      className="auth-btn-teleport"
                      onClick={() => setShowLogin(true)}
                    >
                      <span>[ 传送：GO! ]</span>
                    </button>
                  </div>
                )}
              </div>
            </div>
          </header>

          <section
            className="card chat overflow-hidden"
            style={{ height: chatHeight, minHeight: 0, flexShrink: 0 }}
          >
            <Routes>
              <Route path="/chat/:room_id" element={<RoomChat embedded loginSeq={loginSeq} cyberName={cyberName} />} />
              <Route path="/chat" element={<Navigate to={`/chat/${DEFAULT_ROOM_ID}`} replace />} />
              <Route path="*" element={<Navigate to={`/chat/${DEFAULT_ROOM_ID}`} replace />} />
            </Routes>
          </section>
        </div>
      </div>

      {/* ── 登录弹层 ── */}
      {showLogin && (
        <div className="login-modal-mask" onClick={(e) => {
          if (e.target === e.currentTarget) setShowLogin(false)
        }}>
          <div className="login-modal-box">
            {/* 右上角关闭 */}
            <button
              type="button"
              className="login-modal-close"
              onClick={() => setShowLogin(false)}
            >
              ✕
            </button>
            <LoginTerminal onSuccess={handleLoginSuccess} />
          </div>
        </div>
      )}
    </div>
  )
}

export default App
