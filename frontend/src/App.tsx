import { type FormEvent, useCallback, useEffect, useRef, useState } from 'react'
import { Navigate, Route, Routes, useNavigate } from 'react-router-dom'
import { LoginTerminal } from './pages/LoginTerminal'
import { RoomChat } from './pages/RoomChat'

const DEFAULT_ROOM_ID = 'sector-001'
const AVATAR_STORAGE_KEY = 'cyber_avatar_idx'

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>
}

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
  const [deferredInstallPrompt, setDeferredInstallPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [isInstalledMode, setIsInstalledMode] = useState(false)
  const [loginMode, setLoginMode] = useState<'phone' | 'terminal'>('phone')
  const [phoneNumber, setPhoneNumber] = useState('')
  const [agreePolicy, setAgreePolicy] = useState(true)
  const [phoneLoginHint, setPhoneLoginHint] = useState('')
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

  useEffect(() => {
    const media = window.matchMedia('(display-mode: standalone)')
    const updateInstalledMode = () => {
      const standaloneByNavigator = (window.navigator as Navigator & { standalone?: boolean }).standalone === true
      setIsInstalledMode(media.matches || standaloneByNavigator)
    }
    updateInstalledMode()
    media.addEventListener('change', updateInstalledMode)
    window.addEventListener('appinstalled', updateInstalledMode)
    return () => {
      media.removeEventListener('change', updateInstalledMode)
      window.removeEventListener('appinstalled', updateInstalledMode)
    }
  }, [])

  useEffect(() => {
    const handleBeforeInstallPrompt = (event: Event) => {
      event.preventDefault()
      setDeferredInstallPrompt(event as BeforeInstallPromptEvent)
    }
    const handleAppInstalled = () => {
      setDeferredInstallPrompt(null)
      setIsInstalledMode(true)
    }
    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', handleAppInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
      window.removeEventListener('appinstalled', handleAppInstalled)
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

  const handleInstallApp = useCallback(async () => {
    if (!deferredInstallPrompt) return
    await deferredInstallPrompt.prompt()
    const choice = await deferredInstallPrompt.userChoice
    if (choice.outcome === 'accepted') {
      setIsInstalledMode(true)
    }
    setDeferredInstallPrompt(null)
  }, [deferredInstallPrompt])

  const normalizedPhone = phoneNumber.replace(/\D/g, '').slice(0, 11)
  const canQuickLogin = normalizedPhone.length === 11 && agreePolicy

  const handlePhoneQuickLogin = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (!canQuickLogin) {
      setPhoneLoginHint('ERR//MISSING_PAYLOAD: 写入 11 位号码并授权条款后重试。')
      return
    }
    setPhoneLoginHint('PASS//SILENT_UPLINK: 认证通道已待命，接入运营商网关后自动放行。')
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
                <div className="title-row">
                  <h1 className="title neon-flicker">2000.exe</h1>
                  <span className="tag-mobile">禁止实名，允许发疯。</span>
                </div>
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
                    {!isInstalledMode && deferredInstallPrompt && (
                      <button
                        type="button"
                        className="auth-btn-install"
                        onClick={() => { void handleInstallApp() }}
                      >
                        <span>[ 添加到桌面 ]</span>
                      </button>
                    )}
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
            <div className="login-modal-content">
              <div className="login-mode-tabs" role="tablist" aria-label="登录方式切换">
                <button
                  type="button"
                  role="tab"
                  aria-selected={loginMode === 'phone'}
                  className={`login-mode-tab ${loginMode === 'phone' ? 'is-active' : ''}`}
                  onClick={() => {
                    setLoginMode('phone')
                    setPhoneLoginHint('')
                  }}
                >
                  BYPASS.SMS // 静默越权
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={loginMode === 'terminal'}
                  className={`login-mode-tab ${loginMode === 'terminal' ? 'is-active' : ''}`}
                  onClick={() => {
                    setLoginMode('terminal')
                    setPhoneLoginHint('')
                  }}
                >
                  TERMINAL_REQ // 密钥接驳
                </button>
              </div>

              {loginMode === 'phone' ? (
                <form className={`phone-login-panel ${phoneNumber ? 'is-typing' : ''}`} onSubmit={handlePhoneQuickLogin}>
                  <span className="phone-hud-corner phone-hud-corner-tl" aria-hidden>+</span>
                  <span className="phone-hud-corner phone-hud-corner-tr" aria-hidden>+</span>
                  <span className="phone-hud-corner phone-hud-corner-bl" aria-hidden>+</span>
                  <span className="phone-hud-corner phone-hud-corner-br" aria-hidden>+</span>

                  <div className="phone-hud-lamps" aria-hidden>
                    <span className="hud-lamp lamp-green-square"></span>
                    <span className="hud-lamp lamp-green-square"></span>
                    <span className="hud-lamp lamp-green-square"></span>
                    <span className="hud-lamp-label">AUTH BUS</span>
                  </div>

                  <div className="phone-login-console-head">
                    <p className="phone-login-title">[ PROTOCOL STATUS ] : ACTIVE</p>
                    <p className="phone-login-subtitle">NODE: 2000.EXE.AUTH-GATEWAY / MODE: ZERO-CODE</p>
                  </div>

                  <div className="phone-login-marquee" aria-hidden>
                    {'>> 拒绝物理定位 // 允许意识游离 // '}
                  </div>

                  <p className="phone-login-desc">
                    [ SYSTEM MSG: 链路验证通过后，将自动分配临时 IP 并唤醒赛博义体。]
                  </p>

                  <label className="phone-login-label" htmlFor="phone-number-input"></label>
                  <div className="phone-input-shell">
                    <span className="phone-input-prefix" aria-hidden>{'>_'}</span>
                    <input
                      id="phone-number-input"
                      className="phone-login-input"
                      type="tel"
                      inputMode="numeric"
                      maxLength={11}
                      value={phoneNumber}
                      onChange={(e) => {
                        setPhoneNumber(e.target.value.replace(/\D/g, '').slice(0, 11))
                        setPhoneLoginHint('')
                      }}
                      placeholder="等待输入 11 位通讯序列..."
                    />
                    <span className="phone-input-cursor" aria-hidden></span>
                  </div>

                  <p className="phone-login-wire mt-3">
                    {'[ PIPELINE ] Device Fingerprint -> Carrier Verify -> Session Key Mint'}
                  </p>

                  <label className="phone-login-check">
                    <input
                      type="checkbox"
                      checked={agreePolicy}
                      onChange={(e) => setAgreePolicy(e.target.checked)}
                    />
                    <span>我确认将设备指纹与号码摘要提交至网关，接受《幽灵链路公约》与《黑箱隐私协议》。</span>
                  </label>

                  <button type="submit" className="phone-login-submit-btn" disabled={!canQuickLogin}>
                    {'>_ EXECUTE // 强制越权接入'}
                  </button>
                  {phoneLoginHint && <p className="phone-login-hint">{phoneLoginHint}</p>}
                </form>
              ) : (
                <LoginTerminal onSuccess={handleLoginSuccess} />
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default App
