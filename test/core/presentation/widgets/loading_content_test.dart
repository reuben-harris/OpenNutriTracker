import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/loading_content.dart';

Widget content({required bool loading, bool error = false}) => MaterialApp(
  home: Scaffold(
    body: LoadingContent(
      isLoading: loading,
      hasError: error,
      semanticIdentifier: 'test-information-loading',
      child: const Text('Ready'),
    ),
  ),
);

void main() {
  testWidgets('content stays mounted and hidden for the minimum loading time', (
    tester,
  ) async {
    await tester.pumpWidget(content(loading: true));
    expect(find.text('Ready'), findsNothing);
    expect(find.text('Ready', skipOffstage: false), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final body = tester.getRect(find.byType(LoadingContent));
    expect(
      tester.getCenter(find.byType(CircularProgressIndicator)),
      body.center,
    );

    await tester.pumpWidget(content(loading: false));
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text('Ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('errors bypass the hold and disposal clears the next timer', (
    tester,
  ) async {
    await tester.pumpWidget(content(loading: true));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(content(loading: false, error: true));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(content(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
