# STYLE_GUIDE（样式专卷）

> **何时阅读**：改 UI、动效、`index.css`、Tailwind 类名或布局变量时打开。  
> 实现落点：`frontend/src/index.css`（约 2900 行）+ 各组件 `className`。

---

## 1. 体系概览

- **像素赛博 Y2K**：深色底、霓虹青/绿/品红、粗边框、等宽字体、扫描线与噪点。
- **Tailwind**：工具类 + 少量自定义 `theme`；大量视觉在 **`index.css`** 手写（`@layer` / 裸选择器 / `@keyframes`）。
- **根壳 CRT**：`App.tsx` 最外层 `.crt-container`，滤镜与装饰层见 §5。

---

## 2. 命令面板（`cmd-panel`）

### 2.1 布局

```
[cmd-scan-icon-btn 44×44px]  [cmd-input-wrap flex:1 min-w:0]  [cmd-exec-btn min-w:44px]
```

- `cmd-input-wrap`：`flex: 1; min-width: 0` 防止 flex 子项撑破，保证输入框占主宽（常 >70%）。

### 2.2 探测按钮（`cmd-scan-icon-btn`）

- SVG：双同心圆（r=9 / r=5）+ 指针线 + 中心点。
- 指针：`radar-sweep-hand`，`transform-origin: 12px 12px`，`sweep-rotate` 3s linear infinite。
- 按钮：`scan-btn-idle`，约 2.8s 步进呼吸闪烁。

### 2.3 通电闪烁（`cmd-panel-powered`）

- 触发：`inputFocused === true`（输入框 focus/blur）。
- 动画 `panel-power-on`：约 600ms forwards 单次  
  - 0% → 8% 绿边爆闪 + 上方散射  
  - 18% 绿退 → 30% 青光接力 + 散射  
  - 50% 收敛 → 100% 暗底收尾  

### 2.4 传输按钮

- `xmission-idle`：约 2.2s steps(2) infinite，紫色辉光呼吸。

---

## 3. CRT 终端滤镜（`.crt-container`）

- **挂载**：`App.tsx` 包裹主界面与登录层，全屏一致质感。
- **`::before`**：`repeating-linear-gradient` 横线；`crt-terminal-flicker` 高频低幅 `opacity`；`will-change: opacity`；`z-index` 高于 `.radar-mask` 内容区（约 351），**不挡点击**。
- **`::after`**：`radial-gradient` 暗角（中心略亮），`pointer-events: none`。
- **色散**：`:where(.crt-container *)` 低特异性 `text-shadow`（红 +1px / 青 −1px）；`.neon-flicker` 等可与标题霓虹合并。
- **性能**：装饰层 `position: fixed` + `contain: strict`，避免参与聊天区滚动布局抖动。

---

## 4. 雷达蒙层（`RadarScan`）

### 4.1 扫描线（`.radar-beam`）

- `bottom: 0` → `animation: radar-beam-sweep` 2.2s `cubic-bezier(0.22, 0.6, 0.78, 0.94)` forwards，`100% { bottom: 100% }`。
- `.radar-beam-line`：约 2px 绿色发光线；`.radar-beam-glow`：约 48px 向下余晖（绿→青渐变）。

### 4.2 成员行

- 默认 `opacity: 0`、`translateY(10px)`；`.radar-member-show` 时 `opacity: 1`、位移归零，过渡约 400ms ease-out。

### 4.3 层次（z-index 300 区）

```
.radar-mask
  ├── .radar-aged（SVG 噪点）
  ├── .radar-bg-scanlines
  ├── .radar-vignette
  ├── .radar-beam（scanning 阶段）
  ├── .radar-header
  ├── .radar-members（column, justify-end）
  └── .radar-footer
```

---

## 5. 关键动画与 class 速查

| 名称 | 作用 |
|------|------|
| `panel-power-on` | 命令面板通电 |
| `radar-beam-sweep` | 雷达扫描线 2.2s |
| `sweep-rotate` | 探测图标指针旋转 |
| `scan-btn-idle` | 探测按钮呼吸 |
| `xmission-idle` | 传输按钮呼吸 |
| `history-pulse-once` | 历史消息入场约 320ms |
| `header-dot-blink` | 在线点闪烁 |
| `ann-fade-in/out` | 公告轮播淡入淡出 |
| `room-chaos-flicker` | 切房信号中断 |
| `crt-terminal-flicker` | CRT 扫描线层闪烁 |
| `cfs-wipe-*` | `/clear` 全屏擦除 |

---

## 6. 聊天区布局（`RoomChat` 内）

- **三区比例**：`BROADCAST://SIGNAL` **12%**、`SYS://FEED` **18%**、`USR://STREAM` `flex: 1`。
- **顶栏对齐**：`.container` 上 `--chat-panel-r-inset`；`.header` 的 `padding-right` 与之对齐，使头像/按钮右缘与下方三区右边界一致；`.header` 可用 `--header-h-scale` 压缩高度。
- **系统消息**：`join` 绿、`leave` 红橙、`generic` 琥珀；`cfs` 多行块单独样式。
- **用户消息**：行内 `sender` + 时间 + 内容；奇偶行 cyan / fuchsia 交替。

---

## 7. 移动端与视口

- `index.html`：`viewport-fit=cover`。
- `html, body, #root, .page`：`height: 100dvh` / `overflow: hidden`。
- `.container`：`safe-area-inset-*` + `max()` 与 padding 组合；`≤480px` 时收紧 padding。
- **Header 断点**：`≤480px` 压缩标题与头像；`≤360px` 再缩。
- **输入框**：`font-size: 16px`（防 iOS 自动缩放）、`-webkit-appearance: none`、`touch-action: manipulation`。

---

## 8. 颜色与语义（约定）

- **青 / cyan**：主链路、在线、强调边框（`border-cyan-*`、`text-cyan-*`）。
- **品红 / fuchsia**：用户消息奇偶行、霓虹标题。
- **琥珀**：系统区、警告感公告（`amber-*`）。
- **深灰底**：`#090910`、`#0b1223`、`#15112a` 等分层背景；白/灰 **1px** 立体边框模拟 CRT 面板。

改 UI 时优先在 **`index.css`** 搜索对应 **class** 或 **`@keyframes`**，再局部改动，避免与全局 CRT 层冲突。
