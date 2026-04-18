# flutter_client

Android native client for Cyber Dream Space (`2000.exe`), migrated from React H5.

## Android

- `flutter create` 已生成标准 `android/` 工程壳（Kotlin、`compileSdk` 由 Flutter 插件管理）。
- 已声明 `INTERNET` 权限，应用显示名为 **2000.exe**。
- 本地调试默认将 HTTP/WS 指向 **`10.0.2.2:8000`**（模拟器访问宿主机后端）。
- 如需切换真机/生产地址，请直接修改 `lib/core/constants/api_endpoints.dart` 中的配置常量。

## API & 会话

- 认证：`POST /api/auth/send-key`、`POST /api/auth/verify`（见 `lib/features/auth/data/auth_repository.dart`）。
- 会话：`SharedPreferences` 持久化 `cyber_token` / `cyber_name`（`lib/core/storage/session_store.dart`），与 Web 端 `localStorage` 键一致。
- 聊天：`GET /api/chat/history/{room_id}`、`GET /api/ws/rooms/{room_id}/members`、`GET /api/announcements`；实时链路 `WS /api/ws/{room_id}?token=...`。

## Layered structure

```text
flutter_client/
  android/                    # Flutter 生成的 Android 原生工程
  pubspec.yaml
  lib/
    main.dart
    app/
      cyber_chat_app.dart
      cyber_shell.dart        # 登录门闸 + 会话恢复
    core/
      constants/
        api_endpoints.dart    # API/WS 基础地址集中配置
        chat_rate_limit.dart
      storage/
        session_store.dart
      theme/
        theme.dart
    features/
      auth/
        data/
          auth_repository.dart
        presentation/
          controllers/
            login_terminal_controller.dart
          pages/
            login_terminal_page.dart
      chat/
        data/
          chat_remote_data_source.dart
          services/
            chat_websocket_service.dart
        domain/
          cfs_commands.dart
          models/
            chat_message.dart
          room_presets.dart
        presentation/
          controllers/
            room_chat_controller.dart
          pages/
            room_chat_page.dart
          utils/
            chat_clock.dart
```

## Mapping notes (Tailwind -> Flutter)

- `bg-black` -> `Scaffold` / `DecoratedBox` + `Color(0xFF000000)`
- `text-[#39ff14]` -> `TextStyle(color: CyberPalette.terminalGreen)`
- `border` + `shadow` CRT frame -> `BoxDecoration(border, boxShadow)`
- `p-*, m-*` -> `EdgeInsets`
- 房间状态机 -> `RoomChatController`（`ChangeNotifier`）

---

## 中文版说明

`flutter_client` 是 `2000.exe`（赛博树洞）项目的 Android 原生客户端，用于将现有 React H5 版本逐步迁移为 Flutter。

### 分层结构（中文）

与上文英文目录树一致；补充说明：

- **`CyberShell`**：启动时读取 token，已登录则进入 **`RoomChatPage`**，否则进入 **`LoginTerminalPage`**。
- **`RoomChatController`**：扇区历史分批回放、WebSocket 实时消息、在线人数与成员列表、`/whoami` `/ls` `/clear` 本地 CFS 指令、发送频控等与 `RoomChat.tsx` 对齐。

### 映射说明（Tailwind -> Flutter）

- 赛博扇区主题色 -> `RoomThemeTokens`（`lib/features/chat/domain/room_presets.dart`）
- 系统/用户双流 -> 两个 `ListView` + 独立 `ScrollController`
- 扇区切换故障风 -> `_chaosFx` 短时叠层 + 控制器按新 `roomId` 重建

### 后续可迭代项

- 更细的状态管理（Riverpod / Bloc）与依赖注入。
- 生产环境 API 基址与证书 pinning。
- 雷达扫描动画与 Web 像素级 1:1 动效对齐。
