import { useEffect, useRef, useState } from 'react'

interface SignalGlitchProps {
  roomId: string
  isConnected: boolean
}

export function SignalGlitch({ roomId, isConnected }: SignalGlitchProps) {
  const [visible, setVisible] = useState(false)
  const [glitching, setGlitching] = useState(false)
  const roomRef = useRef<string | null>(null)

  useEffect(() => {
    const isRoomChanged = roomRef.current !== null && roomRef.current !== roomId
    const isFirstMount = roomRef.current === null
    roomRef.current = roomId

    if (!isRoomChanged && !isFirstMount) return
    setVisible(true)
    setGlitching(true)

    const stopGlitchTimer = window.setTimeout(() => {
      setGlitching(false)
    }, 300)
    // 容错兜底：即使链路未成功，也避免遮罩长驻影响交互。
    const autoHideTimer = window.setTimeout(() => {
      setVisible(false)
    }, 1200)

    return () => {
      window.clearTimeout(stopGlitchTimer)
      window.clearTimeout(autoHideTimer)
    }
  }, [roomId])

  useEffect(() => {
    if (!isConnected) return
    setVisible(false)
  }, [isConnected])

  if (!visible) {
    return null
  }

  return (
    <div
      className={`signal-glitch-layer ${glitching ? 'signal-glitch-animate' : ''}`}
      aria-hidden
    >
      <div className="signal-glitch-noise" />
      <p className="signal-glitch-text">
        <span>[ FREQUENCY_RETUNING... ]</span>
      </p>
    </div>
  )
}

