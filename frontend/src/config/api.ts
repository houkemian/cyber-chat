const hostname = window.location.hostname
const isLocalHost = hostname === 'localhost' || hostname === '127.0.0.1'

// 统一跟随当前访问主机，避免手机/局域网/主机名访问时回落到 localhost。
const backendHost = isLocalHost ? 'localhost' : hostname

const httpProtocol = window.location.protocol === 'https:' ? 'https' : 'http'
const wsProtocol = window.location.protocol === 'https:' ? 'wss' : 'ws'

export const HTTP_BASE_URL = `${httpProtocol}://${backendHost}:8000`
export const WS_BASE_URL = `${wsProtocol}://${backendHost}:8000`

export const API_AUTH_URL = `${HTTP_BASE_URL}/api/auth`
export const CHAT_WS_BASE_URL = `${WS_BASE_URL}/api/ws`
