import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../controllers/login_terminal_controller.dart';
import '../widgets/login_terminal_body.dart';

class LoginTerminalPage extends StatefulWidget {
  const LoginTerminalPage({super.key, this.onLoggedIn});

  final void Function(String cyberName)? onLoggedIn;

  @override
  State<LoginTerminalPage> createState() => _LoginTerminalPageState();
}

class _LoginTerminalPageState extends State<LoginTerminalPage> {
  late final LoginTerminalController _controller;
  final ScrollController _decodeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = LoginTerminalController(
      onCompleted: (String name) => widget.onLoggedIn?.call(name),
    );
    _controller.startBoot();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _decodeScroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.phase == LoginPhase.decoding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_decodeScroll.hasClients) {
          _decodeScroll.jumpTo(_decodeScroll.position.maxScrollExtent);
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: CyberPalette.pureBlack,
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: <Color>[Color(0x1200F0FF), CyberPalette.pureBlack],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
                decoration: BoxDecoration(
                  color: const Color(0xF5000800),
                  border: Border.all(color: CyberPalette.terminalGreen.withValues(alpha: 0.55), width: 2),
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, _) {
                    return LoginTerminalBody(
                      controller: _controller,
                      decodeScroll: _decodeScroll,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
