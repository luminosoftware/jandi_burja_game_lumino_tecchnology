import 'dart:async';


import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/bet.dart';
import '../../models/symbol.dart';
import '../../state/game_controller.dart';
import '../widgets/die_face_view.dart';
import '../widgets/felt_backdrop.dart';
import '../widgets/symbol_icon.dart';
import 'dice_lab_web.dart';

/// The throw itself: dice at the top, the outcome anchored to the bottom.
///
/// Split out from the betting screen so the dice own the whole viewport while
/// they move, and so the result is the only thing at eye level once they stop.
/// Reached by pushing a route, which means the Android back button also returns
/// to the table; either way the betting screen clears the board on return.
///
/// Two ways to throw. The default tumbles the 2D dice with [DieFaceView]. With
/// [throw3d] the dice are the physical web-view page, driven the other way
/// round: Dart deals the faces, sends them into the page, and settles the
/// wagers when the page reports they have landed. Same result panel, same
/// balance, same round - only the dice are real.
class RollScreen extends StatefulWidget {
  const RollScreen({super.key, required this.controller, this.throw3d = false});

  final GameController controller;

  /// True to throw through the 3D web-view dice rather than [DieFaceView].
  final bool throw3d;

  /// Test seam for [throw3d].
  ///
  /// The real bridge opens a local HTTP server and a platform web view in its
  /// `initState`, and neither exists under `flutter test`, where no plugin is
  /// registered. Tests install a fake and get a plain placeholder body plus a
  /// throw they can time by hand; leaving it null is what a device sees.
  @visibleForTesting
  static DiceThrowBridge Function()? bridgeOverride;

  @override
  State<RollScreen> createState() => _RollScreenState();
}

class _RollScreenState extends State<RollScreen> {
  late final ConfettiController _confetti;

  /// The [GameController.roundSerial] whose celebration has been played.
  int _celebratedSerial = 0;

  /// Only created for a 3D throw: the 2D path has nothing to talk to.
  DiceThrowBridge? _bridge;

  /// Built once in [initState] so a rebuild cannot restart the page's server.
  Widget? _throw3dViewer;

  /// Whether the dice on screen are the page's. Flipped to false if the page
  /// never loads, which is the whole of the 2D fallback.
  bool _show3d = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(
      duration: const Duration(milliseconds: 1400),
    );
    widget.controller.addListener(_onControllerChanged);

    if (widget.throw3d) {
      _bridge = RollScreen.bridgeOverride?.call() ?? WebDiceThrowBridge();
      _throw3dViewer = _bridge!.buildViewer();
      _show3d = true;
    }

    // Deferred to after the first frame. `roll()` notifies the controller
    // synchronously, and the betting screen listening to it is not an ancestor
    // of this route, so notifying here would mark it dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.controller.roll(thrower: _show3d ? _throw3d : null));
    });
  }

  /// Runs one 3D throw on the faces [GameController.roll] has already dealt.
  ///
  /// Handed to the controller as its `thrower`, so it owns the wait between
  /// "dice are moving" and "dice have landed" and nothing else: the phase
  /// machine, the sounds and the settlement stay there.
  Future<void> _throw3d(List<Symbol> faces) async {
    final DiceThrowBridge? bridge = _bridge;
    if (bridge == null) return;

    final bool ready = await bridge.waitForReady();
    if (!ready) {
      // The page never arrived. Show the 2D dice and give them the tumble they
      // would have had, so the round completes here instead of the player
      // staring at a view that will not load.
      if (mounted) {
        setState(() => _show3d = false);
      }
      await Future<void>.delayed(const Duration(milliseconds: 950));
      return;
    }

    await bridge.land(faces);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _confetti.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Celebrate on entering a settled round only. Re-checking `lastRound` would
    // replay the confetti on every later notification.
    if (widget.controller.roundSerial != _celebratedSerial) {
      _celebratedSerial = widget.controller.roundSerial;
      final RoundResult? result = widget.controller.lastRound ;
      if (result != null && result.won && result.netChange > 0) {
        _confetti.play();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final GameController c = widget.controller;
    final bool rolling = c.phase == RollPhase.rolling;
    final RoundResult? result = c.lastRound;

    return PopScope(
      // Dismissing mid-throw would leave the controller settled with no result
      // on screen to acknowledge, which locks out the next throw.
      canPop: !rolling,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            const FeltBackdrop(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: Column(
                  children: <Widget>[
                    // The dice take the whole space that is left over, centred
                    // in it, rather than sitting under the app bar.
                    //
                    // The 3D page gets that space outright rather than being
                    // centred inside it: a platform web view sizes to the box
                    // it is given, and the page positions its own dice against
                    // the top of that box, so a loose fit would put them
                    // somewhere other than where the result talks about.
                    //
                    // The outcome and the rolling notice float over the bottom
                    // of this space rather than sitting under it in the column,
                    // so the dice keep the exact same box and do not jump up the
                    // moment the result appears.
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _show3d && _throw3dViewer != null
                              ? SizedBox.expand(child: _throw3dViewer)
                              : Center(child: _DiceTable(controller: c)),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: result != null
                                ? _ResultPanel(result: result)
                                : const _RollingNotice(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: rolling
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: GameColors.brass,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          rolling ? 'ROLLING…' : 'PLAY AGAIN',
                          style: const TextStyle(
                            color: GameColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 8,
                emissionFrequency: 0.05,
                gravity: 0.3,
                colors: const <Color>[
                  GameColors.brass,
                  GameColors.cream,
                  GameColors.win,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The six dice, given as much room as the screen allows.
///
/// Six across when there is width for it, otherwise two rows of three, which is
/// far more readable on a phone than six shrunken faces.
class _DiceTable extends StatelessWidget {
  const _DiceTable({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final List<Symbol> faces = controller.visibleFaces;
    final bool rolling = controller.phase == RollPhase.rolling;
    final Set<Symbol> backed = controller.backedSymbols;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 10;
        final bool sixAcross = constraints.maxWidth >= 520;
        final int columns = sixAcross ? AppConfig.diceCount : 3;
        final int rows = sixAcross ? 1 : 2;
        final double size =
            ((constraints.maxWidth - gap * (columns - 1)) / columns).clamp(
              56.0,
              sixAcross ? 76.0 : 92.0,
            );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int row = 0; row < rows; row++) ...<Widget>[
              if (row > 0) const SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int col = 0; col < columns; col++) ...<Widget>[
                    if (col > 0) const SizedBox(width: gap),
                    Builder(
                      builder: (BuildContext context) {
                        final int index = sixAcross ? col : row * columns + col;
                        if (index >= AppConfig.diceCount) {
                          return const SizedBox.shrink();
                        }
                        if (faces.isEmpty) {
                          return _FaceDownDie(size: size);
                        }
                        return DieFaceView(
                          key: ValueKey<int>(index),
                          symbol: faces[index],
                          size: size,
                          // The controller already dealt the faces, so the
                          // tumble lands on the result that gets scored.
                          spinning: rolling,
                          highlighted:
                              !rolling && backed.contains(faces[index]),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FaceDownDie extends StatelessWidget {
  const _FaceDownDie({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GameColors.feltMid,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: GameColors.brassDark),
      ),
      child: Center(
        child: SymbolIcon.chip(
          size: size * 0.4,
          color: const Color(0x55809089),
        ),
      ),
    );
  }
}

class _RollingNotice extends StatelessWidget {
  const _RollingNotice();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 72,
      child: Center(
        child: Text(
          'Rolling the dice…',
          style: TextStyle(color: GameColors.cream, fontSize: 15),
        ),
      ),
    );
  }
}

/// The round's outcome: a headline win/loss and net change, then the six faces
/// as a compact row with the number of dice that came up on each.
///
/// The panel floats over the dice as a small frosted chip rather than pushing
/// them aside, and the balance is deliberately absent - the throw screen is
/// about the result, and the number belongs to the table underneath.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final RoundResult result;

  @override
  Widget build(BuildContext context) {
    final bool won = result.won;
    final Color accent = won ? GameColors.win : GameColors.lose;
    // Which symbols the player backed, and how each settled.
    final Map<Symbol, BetResult> bySymbol = <Symbol, BetResult>{
      for (final BetResult r in result.results) r.bet.symbol: r,
    };
    final int totalBet = result.totalStake;
    final int net = result.netChange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x5905170F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33D4A94E)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                won ? 'WIN' : 'LOSS',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${net >= 0 ? '+' : ''}$net',
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (totalBet > 0) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  'Bet $totalBet',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _FaceGrid(faces: result.faces, results: bySymbol),
        ],
      ),
    );
  }
}

/// The six symbols in a compact horizontal row, bottom-aligned so a backed
/// symbol can carry its stake above the artwork without shifting its label.
class _FaceGrid extends StatelessWidget {
  const _FaceGrid({required this.faces, required this.results});

  final List<Symbol> faces;

  /// The settled wagers, keyed by symbol; absent means the symbol was not bet.
  final Map<Symbol, BetResult> results;

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      key: const Key('result-grid'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < Symbol.values.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: _gap),
            _FaceCell(
              symbol: Symbol.values[i],
              count: faces.where((Symbol f) => f == Symbol.values[i]).length,
              bet: results[Symbol.values[i]],
            ),
          ],
        ],
      ),
    );
  }
}

/// One cell of the result grid: the symbol artwork and the number of dice
/// showing it, dimmed when the face never came up.
///
/// A symbol the player backed is boxed in the colour of that bet's outcome -
/// green when it paid, red when it did not - with the stake shown above it, so
/// the round's bets are readable at a glance.
class _FaceCell extends StatelessWidget {
  const _FaceCell({required this.symbol, required this.count, this.bet});

  final Symbol symbol;
  final int count;

  /// The wager on this symbol, or null if the player did not back it.
  final BetResult? bet;

  @override
  Widget build(BuildContext context) {
    final BetResult? b = bet;
    final Color border = b == null
        ? Colors.transparent
        : (b.won ? GameColors.win : GameColors.lose);
    return Container(
      key: Key('result-cell-${symbol.name}'),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: b == null ? Colors.transparent : border.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (b != null) ...<Widget>[
            _BetAmountTag(amount: b.bet.amount),
            const SizedBox(height: 3),
          ],
          Opacity(
            opacity: count > 0 ? 1 : 0.35,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    symbol.whiteBgImageAsset,
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '×$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stake on a backed result cell, matching the board's chip so the amount
/// reads as the same money the player placed.
class _BetAmountTag extends StatelessWidget {
  const _BetAmountTag({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: GameColors.brass,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SymbolIcon.chip(size: 10, color: GameColors.ink),
          const SizedBox(width: 3),
          Text(
            '$amount',
            style: const TextStyle(
              color: GameColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
