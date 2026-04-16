# flutter_client

Android native client for Cyber Dream Space (`2000.exe`), migrated from React H5.

---

## 中文版说明

`flutter_client` 是 `2000.exe`（赛博树洞）项目的 Android 原生客户端，
用于将现有 React H5 版本逐步迁移为 Flutter 实现。

## Layered structure

```text
flutter_client/
  pubspec.yaml
  analysis_options.yaml
  lib/
    main.dart
    app/
      cyber_chat_app.dart
    core/
      constants/
        api_endpoints.dart
      network/
      theme/
        theme.dart
    features/
      auth/
        presentation/
          controllers/
            login_terminal_controller.dart
          pages/
            login_terminal_page.dart
      chat/
        data/
          services/
            chat_websocket_service.dart
```

## Mapping notes (Tailwind -> Flutter)

- `bg-black` -> `Scaffold` / `DecoratedBox` + `Color(0xFF000000)`
- `text-[#39ff14]` -> `TextStyle(color: CyberPalette.terminalGreen)`
- `border` + `shadow` CRT frame -> `BoxDecoration(border, boxShadow)`
- `p-*, m-*` -> `EdgeInsets`
- Stateful screen flow -> `ChangeNotifier` controller + `StatefulWidget`

## Next phase

- Add HTTP auth repository (`send-key`, `verify`) and token persistence.
- Introduce state management abstraction (Riverpod/Bloc) after core flows stabilize.
- Port `RoomChat.tsx` into Flutter `feature/chat/presentation`.

---

## 分层结构（中文）

```text
flutter_client/
  pubspec.yaml
  analysis_options.yaml
  lib/
    main.dart
    app/
      cyber_chat_app.dart
    core/
      constants/
        api_endpoints.dart
      network/
      theme/
        theme.dart
    features/
      auth/
        presentation/
          controllers/
            login_terminal_controller.dart
          pages/
            login_terminal_page.dart
      chat/
        data/
          services/
            chat_websocket_service.dart
```

## 映射说明（Tailwind -> Flutter）

- `bg-black` -> `Scaffold` / `DecoratedBox` + `Color(0xFF000000)`
- `text-[#39ff14]` -> `TextStyle(color: CyberPalette.terminalGreen)`
- `border` + `shadow` CRT 边框效果 -> `BoxDecoration(border, boxShadow)`
- `p-*`, `m-*` 间距体系 -> `EdgeInsets`
- 页面状态流转 -> `ChangeNotifier` 控制器 + `StatefulWidget`

## 下一阶段计划（中文）

- 接入 HTTP 认证仓库（`send-key`、`verify`）并实现 token 持久化。
- 在核心流程稳定后引入状态管理抽象（Riverpod/Bloc）。
- 将 `RoomChat.tsx` 迁移到 Flutter 的 `feature/chat/presentation`。
