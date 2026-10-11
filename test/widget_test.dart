import 'package:flutter_test/flutter_test.dart';
import 'package:e_byahe_shuttle/screens/home_shell.dart';

void main() {
  testWidgets('E-Byahe home shell renders the existing live map frame', (tester) async {
    await tester.pumpWidget(const HomeShell());
    expect(find.text('E-Byahe Shuttle'), findsOneWidget);
    expect(find.text('Shuttles'), findsWidgets);
    expect(find.text('Live Map'), findsOneWidget);
  });
}
