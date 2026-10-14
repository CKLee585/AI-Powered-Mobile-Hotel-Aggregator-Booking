import 'package:cp2/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('text search opens ranked candidates and confirms a hotel',
      (tester) async {
    await tester.pumpWidget(const HereWeGoApp());

    expect(find.text('herewego'), findsOneWidget);
    expect(find.text('Search hotels'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('hotelSearchField')),
      'Sunway Resort',
    );
    await tester.tap(find.byKey(const Key('searchHotelsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Top 3 ranked candidates'), findsOneWidget);
    expect(find.textContaining('Sunway Resort Hotel'), findsOneWidget);

    await tester.tap(find.text('Confirm hotel').first);
    await tester.pumpAndSettle();

    expect(find.text('Hotel overview'), findsOneWidget);
    expect(find.text('Week 1-3 foundation complete'), findsOneWidget);
  });

  testWidgets('empty search explains what the user must enter', (tester) async {
    await tester.pumpWidget(const HereWeGoApp());

    await tester.tap(find.byKey(const Key('searchHotelsButton')));
    await tester.pump();

    expect(
      find.text('Enter a hotel name, destination, or keyword.'),
      findsOneWidget,
    );
  });
}
