import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';

void main() {
  var taps = 0;
  var leftActions = 0;
  var rightActions = 0;
  setUp(() {
    taps = 0;
    leftActions = 0;
    rightActions = 0;
  });

  Widget row({
    String id = 'row',
    bool left = true,
    bool right = true,
    bool enabled = true,
    Object identity = 'first',
    double? threshold,
  }) => SwipeReveal(
    key: ValueKey(id),
    enabled: enabled,
    resetKey: identity,
    leftAction: !left
        ? null
        : SwipeRevealAction(
            icon: Icons.info_outline,
            label: 'Info',
            semanticsIdentifier: '$id-info',
            onTap: () => leftActions++,
            revealThreshold: threshold ?? 52,
          ),
    rightAction: !right
        ? null
        : SwipeRevealAction(
            icon: Icons.refresh,
            label: 'Refresh',
            semanticsIdentifier: '$id-refresh',
            onTap: () => rightActions++,
          ),
    child: SizedBox(
      height: 100,
      width: double.infinity,
      child: Material(
        color: Colors.grey,
        child: InkWell(onTap: () => taps++, child: Text(id)),
      ),
    ),
  );
  Widget app({
    bool left = true,
    bool right = true,
    bool enabled = true,
    Object identity = 'first',
    double? threshold,
    bool reducedMotion = false,
    bool second = false,
    bool active = true,
    GlobalKey<NavigatorState>? navigator,
  }) => MaterialApp(
    navigatorKey: navigator,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: SwipeRevealScope(
          active: active,
          child: ListView(
            children: [
              row(
                left: left,
                right: right,
                enabled: enabled,
                identity: identity,
                threshold: threshold,
              ),
              if (second) row(id: 'second'),
              TextButton(onPressed: () => taps++, child: const Text('Outside')),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    ),
  );
  Finder child([String id = 'row']) => find.text(id);
  double offset(WidgetTester tester, [String id = 'row']) =>
      tester.getTopLeft(child(id)).dx;
  Future<void> open(
    WidgetTester tester, {
    bool left = true,
    String id = 'row',
  }) async {
    await tester.dragFrom(
      tester.getCenter(child(id)),
      Offset(left ? 140 : -140, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> slowDrag(WidgetTester tester, double distance) async {
    final gesture = await tester.startGesture(tester.getCenter(child()));
    await gesture.moveBy(Offset(distance.sign * 20, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(Offset(distance, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  SemanticsFinder actionSemantics(String identifier) => find.semantics
      .byPredicate((node) => node.getSemanticsData().identifier == identifier);

  testWidgets(
    'two-sided actions settle at 104px and close before invoking callbacks',
    (tester) async {
      await tester.pumpWidget(app());
      await open(tester);
      expect(offset(tester), 104);
      await tester.tap(find.text('Info'));
      await tester.pump();
      expect(offset(tester), 0);
      expect(leftActions, 1);
      expect(taps, 0);
      await open(tester, left: false);
      expect(offset(tester), -104);
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(offset(tester), 0);
      expect(rightActions, 1);
    },
  );

  testWidgets('one-sided rows keep unsupported directions closed', (
    tester,
  ) async {
    for (final left in [true, false]) {
      await tester.pumpWidget(app(left: left, right: !left));
      await open(tester, left: !left);
      expect(offset(tester), 0);
      await open(tester, left: left);
      expect(offset(tester), left ? 104 : -104);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'default half-width and per-action thresholds control slow swipes',
    (tester) async {
      await tester.pumpWidget(app());
      await slowDrag(tester, 40);
      expect(offset(tester), 0);
      await slowDrag(tester, 60);
      expect(offset(tester), 104);
      await tester.pumpWidget(app(identity: 'custom', threshold: 32));
      await slowDrag(tester, 40);
      expect(offset(tester), 104);
    },
  );

  testWidgets(
    'a short fast fling opens an action below its distance threshold',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.fling(child(), const Offset(-70, 0), 1000);
      await tester.pumpAndSettle();
      expect(offset(tester), -104);
    },
  );

  testWidgets('settling takes 200ms and hides actions until fully open', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(threshold: 32));
    final gesture = await tester.startGesture(tester.getCenter(child()));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(offset(tester), greaterThan(40));
    expect(offset(tester), lessThan(104));
    expect(actionSemantics('row-info'), findsNothing);
    await tester.pump(const Duration(milliseconds: 101));
    expect(offset(tester), 104);
    expect(actionSemantics('row-info'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'tapping open child intercepts normal tap, next tap activates child',
    (tester) async {
      await tester.pumpWidget(app());
      await open(tester);
      await tester.tapAt(tester.getCenter(child()));
      await tester.pumpAndSettle();
      expect(offset(tester), 0);
      expect(taps, 0);
      await tester.tapAt(tester.getCenter(child()));
      expect(taps, 1);
    },
  );

  testWidgets(
    'hidden and partially revealed actions have no semantics or hit testing',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app());
      expect(actionSemantics('row-info'), findsNothing);
      expect(actionSemantics('row-refresh'), findsNothing);
      final gesture = await tester.startGesture(tester.getCenter(child()));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(35, 0));
      await tester.pump();
      expect(actionSemantics('row-info'), findsNothing);
      await tester.tapAt(const Offset(10, 50));
      expect(leftActions, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await open(tester);
      expect(actionSemantics('row-info'), findsOneWidget);
      expect(actionSemantics('row-refresh'), findsNothing);
      await tester.pumpWidget(app(enabled: false));
      await tester.pump();
      expect(actionSemantics('row-info'), findsNothing);
      expect(offset(tester), 0);
      semantics.dispose();
    },
  );

  testWidgets('busy rows disable swipe, revealed actions, and child taps', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.pumpWidget(app(enabled: false));
    await open(tester, left: false);
    expect(offset(tester), 0);
    await tester.tapAt(tester.getCenter(child()));
    expect(taps, 0);
    expect(leftActions, 0);
    expect(rightActions, 0);
  });

  testWidgets('scope coordinates rows, outside taps and vertical scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(app(second: true));
    await open(tester);
    await open(tester, id: 'second');
    expect(offset(tester), 0);
    expect(offset(tester, 'second'), 104);
    await tester.tap(find.text('Outside'));
    await tester.pumpAndSettle();
    expect(offset(tester, 'second'), 0);
    expect(taps, 1);
    await open(tester);
    await tester.dragFrom(tester.getCenter(child()), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
  });

  testWidgets('identity, scope activation, and navigation reset open rows', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigator: navigator));
    await open(tester);
    await tester.pumpWidget(app(navigator: navigator, identity: 'replacement'));
    await tester.pump();
    expect(offset(tester), 0);
    await open(tester);
    await tester.pumpWidget(
      app(navigator: navigator, identity: 'replacement', active: false),
    );
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
    await tester.pumpWidget(app(navigator: navigator));
    await open(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Details')),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
  });

  testWidgets('reduced motion is immediate; disposal during settling is safe', (
    tester,
  ) async {
    await tester.pumpWidget(app(reducedMotion: true));
    await open(tester);
    await tester.tapAt(tester.getCenter(child()));
    await tester.pump();
    expect(offset(tester), 0);
    await tester.pumpWidget(app());
    await tester.drag(child(), const Offset(-140, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
