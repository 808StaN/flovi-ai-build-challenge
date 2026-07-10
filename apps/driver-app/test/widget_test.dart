import 'package:flutter_test/flutter_test.dart';
import 'package:flovi_driver_app/main.dart';

void main() {
  testWidgets('renders driver auth shell', (tester) async {
    await tester.pumpWidget(const DriverApp());

    expect(find.text('Flovi'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
