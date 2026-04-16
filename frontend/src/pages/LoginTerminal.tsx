import { useEffect, useRef, useState } from 'react'
import axios from 'axios'
import { API_AUTH_URL } from '../config/api'

// ── 状态机阶段定义 ───────────────────────────────────────────
type Phase =
  | 'boot'       // 开机打字动画
  | 'idle'       // 输入手机号
  | 'countdown'  // 倒计时 + 输入验证码
  | 'decoding'   // 解码乱码流
  | 'success'    // 身份覆写成功

function makeDecodingLines(): string[] {
  const phrases = [
    '>> INIT QUANTUM HANDSHAKE ...',
    '>> SYNC TIME-LAYER OFFSETS ...',
    '>> DECRYPT LEGACY CREDENTIALS ...',
    '>> CRC CHECK: PASS',
    '>> OPEN CHANNEL /CYBER/DREAM/SPACE',
    '>> OVERRIDE IDENTITY BOUNDARY ...',
    '>> LOAD MILLENNIUM PROFILE ...',
    '>> HANDSHAKE COMPLETE. ACCESS GRANTED.',
  ]
  return Array.from({ length: 40 }, (_, i) => {
    const noise = Math.random().toString(16).slice(2, 14).toUpperCase()
    return `${i < phrases.length ? phrases[i] : '>> STREAM //'}  0x${noise}`
  })
}

interface Props {
  /** 弹层模式：登录成功后调用，不做页面跳转 */
  onSuccess?: (cyberName: string) => void
}

export function LoginTerminal({ onSuccess }: Props) {
  const [phase, setPhase] = useState<Phase>('boot')
  const [phone, setPhone] = useState('')
  const [code, setCode] = useState('')
  const [countdown, setCountdown] = useState(0)
  const [decodingLines, setDecodingLines] = useState<string[]>([])
  const [cyberName, setCyberName] = useState('')
  const [error, setError] = useState('')
  const [bootText, setBootText] = useState('')
  const [cursor, setCursor] = useState(true)
  const decodingRef = useRef<HTMLDivElement>(null)
  const codeInputRef = useRef<HTMLInputElement>(null)

  // 光标闪烁
  useEffect(() => {
    const id = setInterval(() => setCursor((c) => !c), 530)
    return () => clearInterval(id)
  }, [])

  // 开机打字动画
  useEffect(() => {
    const target = '[ SYSTEM BOOT... 2000.exe ]'
    let idx = 0
    const id = setInterval(() => {
      idx++
      setBootText(target.slice(0, idx))
      if (idx >= target.length) {
        clearInterval(id)
        setTimeout(() => setPhase('idle'), 500)
      }
    }, 48)
    return () => clearInterval(id)
  }, [])

  // 60s 倒计时
  useEffect(() => {
    if (countdown <= 0) return
    const id = setInterval(() => {
      setCountdown((n) => {
        if (n <= 1) { clearInterval(id); return 0 }
        return n - 1
      })
    }, 1000)
    return () => clearInterval(id)
  }, [countdown])

  // 解码滚到底
  useEffect(() => {
    if (phase === 'decoding' && decodingRef.current) {
      decodingRef.current.scrollTop = decodingRef.current.scrollHeight
    }
  }, [phase, decodingLines])

  // 进入验证码阶段：聚焦输入框，便于第一时间发现输入位置
  useEffect(() => {
    if (phase !== 'countdown') return
    const id = window.setTimeout(() => codeInputRef.current?.focus(), 80)
    return () => window.clearTimeout(id)
  }, [phase])

  // 成功后：弹层模式回调，否则跳转 /chat
  useEffect(() => {
    if (phase !== 'success') return
    const id = setTimeout(() => {
      if (onSuccess) {
        onSuccess(cyberName)
      } else {
        window.location.href = '/chat'
      }
    }, 2000)
    return () => clearTimeout(id)
  }, [phase, cyberName, onSuccess])

  const handleSendKey = async () => {
    setError('')
    const tel = phone.trim()
    if (tel.length < 6) { setError('>> ERROR: 终端号长度不足，信道拒绝建立'); return }
    try {
      await axios.post(`${API_AUTH_URL}/send-key`, { phone_number: tel })
      setPhase('countdown')
      setCountdown(60)
    } catch {
      setError('>> ERROR: 信道被干扰，请稍后重试')
    }
  }

  const handleVerify = async () => {
    setError('')
    if (!code.trim()) { setError('>> ERROR: 跃迁密匙为空，终端拒绝接入'); return }
    setPhase('decoding')
    setDecodingLines(makeDecodingLines())
    try {
      const res = await axios.post<{ token: string; cyber_name: string }>(
        `${API_AUTH_URL}/verify`,
        { phone_number: phone.trim(), sms_code: code.trim() },
      )
      window.localStorage.setItem('cyber_token', res.data.token)
      window.localStorage.setItem('cyber_name', res.data.cyber_name)
      setCyberName(res.data.cyber_name)
      setTimeout(() => setPhase('success'), 2000)
    } catch (e: unknown) {
      const msg =
        axios.isAxiosError(e) && e.response?.data?.detail === 'invalid_or_expired_code'
          ? '>> ERROR: 验证矩阵拒绝握手 // 密匙失配或跃迁窗口已冻结'
          : '>> ERROR: 时空通道异常，请重试'
      setError(msg)
      setPhase('countdown')
    }
  }

  return (
    <div className="terminal-root">
      <div className="crt-overlay" />

      <div className="terminal-frame">
        {/* 标题 */}
        <div className="terminal-title">
          {phase === 'boot'
            ? <>{bootText}<span className={cursor ? 'opacity-100' : 'opacity-0'}>_</span></>
            : <span className="terminal-title-blink">[ SYSTEM BOOT... 2000.exe ]</span>
          }
        </div>

        {/* 开机 */}
        {phase === 'boot' && (
          <p className="terminal-hint mt-4">正在初始化赛博树洞时空接入协议...</p>
        )}

        {/* 成功 */}
        {phase === 'success' && (
          <div className="terminal-success">
            <p className="terminal-success-line">{'>> IDENTITY OVERRIDE COMPLETE'}</p>
            <p className="terminal-success-name">
              身份覆写成功。欢迎登陆，代号：<br />
              <span className="terminal-cyber-name">【{cyberName}】</span>
            </p>
            <p className="terminal-hint mt-4 animate-pulse">{'>> 正在接入赛博树洞频道...'}</p>
          </div>
        )}

        {/* 解码动画 */}
        {phase === 'decoding' && (
          <div className="terminal-decode-box" ref={decodingRef}>
            {decodingLines.map((line, i) => (
              <div key={i} className="terminal-decode-line">{line}</div>
            ))}
            <div className="terminal-decode-line animate-pulse">{'>> PROCESSING...'}</div>
          </div>
        )}

        {/* 主交互 */}
        {(phase === 'idle' || phase === 'countdown') && (
          <div className="terminal-body">
            <p className="terminal-hint">{'> [ 密钥接驳 ] 验证码登录通道'}</p>
            <label className="terminal-label">
              {'> 请输入地球维度的通讯终端号 (Phone Number):'}
              <span className={cursor ? 'opacity-100' : 'opacity-0'}>_</span>
            </label>
            <input
              className="terminal-input"
              type="tel"
              inputMode="numeric"
              value={phone}
              placeholder="13800138000"
              onChange={(e) => setPhone(e.target.value)}
              disabled={phase === 'countdown'}
            />

            <button
              type="button"
              className={`terminal-btn mt-3 ${countdown > 0 ? 'terminal-btn-disabled' : ''}`}
              onClick={handleSendKey}
              disabled={countdown > 0}
            >
              {countdown > 0
                ? `> 密匙已发送至终端，正在维持信道 (${countdown}s)...`
                : '[ 请求时空跃迁密匙 ]'}
            </button>

            {phase === 'countdown' && (
              <>
                <label className="terminal-label mt-5 terminal-label-verify" htmlFor="terminal-auth-code">
                  {'> 请输入 4 位跃迁密匙 (Auth Code):'}
                  <span className={cursor ? 'opacity-100' : 'opacity-0'}>_</span>
                </label>
                <div
                  className="terminal-code-hitbox terminal-code-hitbox--prominent"
                  onClick={() => codeInputRef.current?.focus()}
                  role="presentation"
                >
                  <input
                    id="terminal-auth-code"
                    ref={codeInputRef}
                    className="terminal-input terminal-input--auth-code"
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={8}
                    value={code}
                    placeholder="· · · ·"
                    onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                  />
                </div>
                <button
                  type="button"
                  className="terminal-btn mt-3 terminal-btn-verify"
                  onClick={handleVerify}
                >
                  {'[ 执行身份覆写 (Override) ]'}
                </button>
              </>
            )}

            {error && <p className="terminal-error mt-3">{error}</p>}
          </div>
        )}
      </div>
    </div>
  )
}
