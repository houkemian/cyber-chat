import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/login_terminal_controller.dart';
import 'login_terminal_body.dart';

/// 对应 Web `login-modal-mask` / `login-modal-box`。
class LoginModalOverlay extends StatefulWidget {
  const LoginModalOverlay({
    super.key,
    required this.onDismiss,
    required this.onSuccess,
  });

  final VoidCallback onDismiss;
  final ValueChanged<String> onSuccess;

  @override
  State<LoginModalOverlay> createState() => _LoginModalOverlayState();
}

class _LoginModalOverlayState extends State<LoginModalOverlay> {
  late final LoginTerminalController _controller;
  late final ScrollController _decodeScroll;

  @override
  void initState() {
    super.initState();
    _decodeScroll = ScrollController();
    _controller = LoginTerminalController(
      onCompleted: widget.onSuccess,
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
    final maxH = MediaQuery.sizeOf(context).height * 0.9;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(color: const Color(0xD1000000)),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600, maxHeight: maxH),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF4EF3FF), width: 2),
                        ),
                        child: CustomPaint(
                          painter: _ModalScanlinesPainter(),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(22, 36, 22, 28),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0xF3071424),
                                  Color(0xF5050818),
                                ],
                              ),
                            ),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (BuildContext context, _) {
                                return SingleChildScrollView(
                                  child: LoginTerminalBody(
                                    controller: _controller,
                                    decodeScroll: _decodeScroll,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onDismiss,
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0x804ADE80)),
                              ),
                              child: const Text(
                                '✕',
                                style: TextStyle(color: Color(0xFF4ADE80), fontSize: 14, height: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1400F0FF)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
