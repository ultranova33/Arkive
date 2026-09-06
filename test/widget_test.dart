import 'package:flutter_test/flutter_test.dart';

import 'package:arkive/main.dart';

void main() {
  group('Arkive app', () {
    testWidgets('starts on the locked vault screen', (tester) async {
      await tester.pumpWidget(const ArkiveApp());

      expect(find.text('ARKIVE'), findsOneWidget);
      expect(find.text('Unlock with Passcode'), findsOneWidget);
    });
  });
}
