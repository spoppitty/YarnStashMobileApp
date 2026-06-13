import 'package:flutter_test/flutter_test.dart';
import 'package:yarn_stash/main.dart';

void main() {
  testWidgets('renders the Yarn Stash login screen', (tester) async {
    await tester.pumpWidget(const YarnStashApp());

    expect(find.text('Yarn Stash'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
