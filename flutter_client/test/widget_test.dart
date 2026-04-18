import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/app/cyber_chat_app.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const CyberChatApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
