import 'package:flutter_test/flutter_test.dart';
import 'package:smart_jeep/test_map.dart';

void main() {
  testWidgets('Test OSM map loads', (WidgetTester tester) async {
    await tester.pumpWidget(TestMap());
    expect(find.byType(TestMap), findsOneWidget);
  });
}
