import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shift_mate/main.dart';

void main() {
  testWidgets('ShiftMate app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShiftMateApp()));
    await tester.pump();
    expect(find.text('ShiftMate'), findsWidgets);
  });
}
