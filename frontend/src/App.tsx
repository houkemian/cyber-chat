import { useCallback, useEffect, useRef, useState } from 'react'
import { Navigate, Route, Routes, useNavigate } from 'react-router-dom'
import { LoginTerminal } from './pages/LoginTerminal'
import { RoomChat } from './pages/RoomChat'

const DEFAULT_ROOM_ID = 'sector-001'

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [cyberName, setCyberName] = useState<string | null>(null)
  const [showLogin, setShowLogin] = useState(false)
  const [noisePhase, setNoisePhase] = useState(0)
  const [chatHeight, setChatHeight] = useState('60vh')
  const [loginSeq, setLoginSeq] = useState(0)
  const headerRef = useRef<HTMLElement>(null)
  const navigate = useNavigate()

  const avatarSeed = cyberName ?? 'midnight'
  const avatarUrl = `https://api.dicebear.com/9.x/pixel-art/svg?seed=${encodeURIComponent(avatarSeed)}`

  // 动态计算聊天区精确高度：视口高度 - header高度 - container上下padding - gap
  useEffect(() => {
    const recalc = () => {
      if (!headerRef.current) return
      const headerH = headerRef.current.getBoundingClientRect().height
      // container padding: 16px top + 16px bottom = 32px；gap between header and section: 14px
      const reserved = headerH + 32 + 14
      setChatHeight(`calc(100vh - ${reserved}px)`)
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
    navigate(`/chat/${DEFAULT_ROOM_ID}`, { replace: true })
  }

  return (
    <>
      {/* ── 主页面 ── */}
      <div className="page h-screen overflow-hidden" data-noise-phase={noisePhase}>
        <div className="fx-layer">
          <span className="spark spark-cyan"></span>
          <span className="spark spark-pink"></span>
          <span className="spark spark-cyan spark-slow"></span>
          <span className="scanline"></span>
        </div>

        <div className="container">
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
              <Route path="/chat/:room_id" element={<RoomChat embedded loginSeq={loginSeq} />} />
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
    </>
  )
}

export default App
