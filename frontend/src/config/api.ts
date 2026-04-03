const hostname = window.location.hostname
const isLocalHost = hostname === 'localhost' || hostname === '127.0.0.1'

let HTTP_BASE_URL: string
let WS_BASE_URL: string

if (isLocalHost) {
  // 本地开发：直连后端开发服务器端口
  HTTP_BASE_URL = 'http://localhost:8000'
  WS_BASE_URL = 'ws://localhost:8000'
} else {
  // 生产环境：同域经由 Nginx 反向代理到后端
  const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  HTTP_BASE_URL = '/cyber-api'
  WS_BASE_URL = `${wsProtocol}//${window.location.host}/cyber-api`
}

export { HTTP_BASE_URL, WS_BASE_URL }

export const API_AUTH_URL = `${HTTP_BASE_URL}/api/auth`
export const CHAT_WS_BASE_URL = `${WS_BASE_URL}/api/ws`
