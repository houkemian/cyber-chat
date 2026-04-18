import 'package:flutter/material.dart';

import '../core/storage/session_store.dart';
import '../core/theme/theme.dart';
import '../features/auth/presentation/widgets/login_modal_overlay.dart';
import '../features/chat/presentation/pages/room_chat_page.dart';
import 'widgets/crt_atmosphere.dart';
import 'widgets/cyber_header_bar.dart';
import 'widgets/neon_y2k_shell.dart';

/// 与 Web `App.tsx` 一致：CRT 背景 + 顶栏 + 聊天区；未登录仍可浏览离线扇区（`RoomChat`）。
class CyberShell extends StatefulWidget {
  const CyberShell({super.key});

  @override
  State<CyberShell> createState() => _CyberShellState();
}

class _CyberShellState extends State<CyberShell> {
  bool _ready = false;
  bool _loggedIn = false;
  String? _cyberName;
  int _avatarIdx = 0;
  bool _showLogin = false;
  int _roomSessionSeq = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final String? token = await SessionStore.readToken();
    final String? name = await SessionStore.readCyberName();
    final int avatar = await SessionStore.readCyberAvatarIdx();
    if (!mounted) return;
    setState(() {
      _loggedIn = token != null && token.isNotEmpty;
      _cyberName = name;
      _avatarIdx = avatar;
      _ready = true;
    });
  }

  void _onLoginSuccess(String name) {
    setState(() {
      _loggedIn = true;
      _cyberName = name;
      _showLogin = false;
      _roomSessionSeq += 1;
    });
  }

  Future<void> _onLogout() async {
    await SessionStore.clearSession();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _cyberName = null;
      _roomSessionSeq += 1;
    });
  }

  void _onPinToHome(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('本端为原生客户端；Web 请在浏览器中使用「安装应用 / 添加到主屏幕」。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: CyberPalette.pureBlack,
        body: Center(
          child: CircularProgressIndicator(color: CyberPalette.terminalGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CrtAtmosphere(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: NeonY2kShell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        CyberHeaderBar(
                          embeddedInCard: true,
                          loggedIn: _loggedIn,
                          cyberName: _cyberName,
                          avatarIdx: _avatarIdx,
                          onTeleport: () => setState(() => _showLogin = true),
                          onLogout: _onLogout,
                          onShowQr: () => showCyberQrDialog(context),
                          onPinToHome: () => _onPinToHome(context),
                        ),
                        Expanded(
                          child: RoomChatPage(key: ValueKey<int>(_roomSessionSeq)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showLogin)
            Positioned.fill(
              child: LoginModalOverlay(
                onDismiss: () => setState(() => _showLogin = false),
                onSuccess: _onLoginSuccess,
              ),
            ),
        ],
      ),
    );
  }
}
