import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhandi_munda_game_app/state/game_controller.dart';
import 'package:jhandi_munda_game_app/ui/screens/dice_lab_screen.dart';
import 'package:jhandi_munda_game_app/ui/screens/dice_lab_web.dart';
import 'package:jhandi_munda_game_app/ui/screens/more_screen.dart';
import 'package:jhandi_munda_game_app/ui/widgets/symbol_icon.dart';

import 'game_screen_test.dart' show buildController;

/// The practice screen, so far as the test VM can see it.
///
/// The dice, the throw button, the label and the roll history all live in HTML
/// inside a web view served over a loopback socket, and neither that server nor
/// the web view plugin exists under `flutter test` -
/// `DiceLabScreen.viewerOverride` swaps the body out for a placeholder, and
/// these tests hold the rest of the screen to the promises the Flutter side
/// actually makes: it hosts the page, it never touches the money, and it lets
/// the player leave.
void main() {
  setUp(() {
    DiceLabScreen.viewerOverride = () =>
        const SizedBox(key: Key('diceLabViewer'));
  });

  tearDown(() {
    DiceLabScreen.viewerOverride = null;
  });

  Future<void> openLab(WidgetTester tester, GameController controller) async {
    await tester.pumpWidget(
      MaterialApp(home: DiceLabScreen(controller: controller)),
    );
    await tester.pump();
  }

  testWidgets('opens on a quiet table with nothing thrown', (
    WidgetTester tester,
  ) async {
    final GameController controller = await buildController();
    addTearDown(controller.dispose);
    await openLab(tester, controller);

    // The page is hosted full bleed, behind everything else, so the felt shows
    // the moment the route is pushed rather than a white rectangle waiting on
    // the loopback server to come up.
    expect(find.byKey(const Key('diceLabViewer')), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF14501A),
    );
    // No result has been dealt: the page has not thrown yet, and no symbol is
    // on screen pretending otherwise.
    expect(find.byType(SymbolIcon), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves the balance and the board exactly as it found them', (
    WidgetTester tester,
  ) async {
    final GameController controller = await buildController(
      startingBalance: 1000,
    );
    addTearDown(controller.dispose);

    final int balance = controller.wallet.balance;
    final int round = controller.roundSerial;

    await openLab(tester, controller);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(DiceLabScreen), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: const SizedBox()), // pop the route
    );
    await tester.pump();

    expect(controller.wallet.balance, balance);
    expect(controller.wallet.totalBet, 0);
    expect(controller.roundSerial, round);
    expect(controller.lastRound, isNull);
    expect(controller.phase, RollPhase.idle);
  });

  testWidgets('goes back to the table with the system back button', (
    WidgetTester tester,
  ) async {
    final GameController controller = await buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DiceLabScreen(controller: controller),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DiceLabScreen), findsOneWidget);

    // The Android back gesture, not a button on screen: the page draws its own
    // arrow and posts it down a channel, which the test VM cannot reach.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DiceLabScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('is reachable from the More screen', (
    WidgetTester tester,
  ) async {
    final GameController controller = await buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MoreScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ListTile, '3D Dice Table'));
    await tester.pumpAndSettle();

    expect(find.byType(DiceLabScreen), findsOneWidget);
  });

  group('symbol art script', () {
    // Regression: `jsonEncode` throws `JsonUnsupportedObjectError` when a map
    // key is not a `String`, and the die-number keys are `int`s. The encode runs
    // inside `build`, so the throw blanked the whole practice screen instead of
    // just leaving the symbols as emoji. The keys are stringified before they
    // reach the encoder; these pin that down.
    test('stringifies the die-number keys so the map can be encoded', () {
      final String script = symbolImagesScript(<int, String>{
        1: 'data:image/png;base64,AAA',
        2: 'data:image/png;base64,BBB',
      });

      expect(script, contains('var SYMBOL_IMAGES = {'));
      expect(script, contains('"1":"data:image/png;base64,AAA"'));
      expect(script, contains('"2":"data:image/png;base64,BBB"'));
    });

    test('sends no script when there is no art', () {
      expect(symbolImagesScript(const <int, String>{}), isEmpty);
    });
  });
}
