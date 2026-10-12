import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../logic/game_engine.dart';
import '../../services/rewarded_ad_service.dart';
import '../../state/game_controller.dart';
import '../widgets/betting_board.dart';
import '../widgets/coin_picker.dart';
import '../widgets/felt_backdrop.dart';
import '../widgets/hero_card.dart';
import 'roll_screen.dart';
import 'more_screen.dart';

/// The betting table: quick actions, balance, the six symbols, and the throw.
/// Deliberately contains no dice. The throw happens on its own screen, so this
/// one is only ever about deciding where the coins go.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  /// Hands the throw to [RollScreen] and, on the way back, guarantees a clean
  /// board.
  ///
  /// The reset happens here rather than on the roll screen's own button so that
  /// the system back button lands on the same clean state as PLAY AGAIN. It
  /// runs only when a round actually settled: a player who leaves before the
  /// dice have been dealt keeps the wagers they staged, because clearing them
  /// there would take coins off the table for a throw that never happened.
  Future<void> _throw(BuildContext context, {required bool throw3d}) async {
    if (!controller.canRoll) return;
    final int serial = controller.roundSerial;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RollScreen(controller: controller, throw3d: throw3d),
      ),
    );
    if (!context.mounted) return;
    if (controller.roundSerial == serial) return;
    await controller.clearBoard();
  }

  /// The throw, in whichever style the top-bar toggle has selected.
  ///
  /// The mode is read at the moment of the tap rather than captured anywhere, so
  /// switching the toggle is all it takes to change what this button does.
  Future<void> _roll(BuildContext context) =>
      _throw(context, throw3d: controller.throw3d);

  @override
  Widget build(BuildContext context) {
    // The controller is the source of truth and a ChangeNotifier, so the whole
    // table rebuilds from it rather than from local state.
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) => _buildTable(context),
    );
  }

  Widget _buildTable(BuildContext context) {
    final GameController c = controller;
    // Locked only while the dice are moving or a result is unacknowledged.
    // Treating "not idle" as locked would disable the board, the chips and the
    // quick actions the instant a single bet was staged.
    final bool locked =
        c.phase == RollPhase.rolling || c.phase == RollPhase.settled;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const FeltBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                _TopBar(controller: c),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            HeroCard(controller: c),
                            const SizedBox(height: 6),
                            BetAmount(controller: c),
                            if (c.lastRejection != null) ...<Widget>[
                              const SizedBox(height: 6),
                              _RejectionNotice(rejection: c.lastRejection!),
                            ],
                            const SizedBox(height: 6),
                            BettingBoard(
                              controller: c,
                              bets: c.wallet.bets,
                              enabled: !locked,
                            ),
                            const SizedBox(height: 6),
                            CoinPicker(
                              selected: c.wallet.selectedChip,
                              enabled: !locked,
                              onSelect: c.selectChip,
                            ),
                            const SizedBox(height: 6),
                            // Under the coins rather than above the board, so
                            // the order on screen runs the way the round does:
                            // pick a coin, place it, fix a mistake.
                            _QuickActions(controller: c),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Pinned outside the scroll view: the one control that matters
                // most must stay reachable on a small phone without scrolling.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: RollButton(
                        controller: c,
                        onRoll: () => _roll(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (c.adMessage != null)
            Align(
              alignment: const Alignment(0, 0.75),
              child: _Toast(
                message: c.adMessage!,
                onRetry: c.adState == RewardedAdState.ready
                    ? null
                    : () => c.retryAd(),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 2D/3D switch for the throw, in the top bar.
///
/// It only picks which dice the single ROLL THE DICE button uses: it stages
/// nothing, spends nothing and is therefore never gated on a round being ready.
/// Two short labels rather than an icon keep the choice legible at a glance and
/// still fit beside the title on the narrowest phone.
class _ThrowModeToggle extends StatelessWidget {
  const _ThrowModeToggle({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Dice style: 2D or 3D',
      child: SegmentedButton<bool>(
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(value: false, label: Text('2D')),
          ButtonSegment<bool>(value: true, label: Text('3D')),
        ],
        selected: <bool>{controller.throw3d},
        onSelectionChanged: (Set<bool> selection) =>
            controller.setThrow3d(selection.first),
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Menu',
            icon: Image.asset(
              'assets/images/appbar.png',
              width: 34,
              height: 34,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MoreScreen(controller: controller),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: GameColors.brass,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ),
          _ThrowModeToggle(controller: controller),
        ],
      ),
    );
  }
}

class _RejectionNotice extends StatelessWidget {
  const _RejectionNotice({required this.rejection});

  final BetRejection rejection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GameColors.lose.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.lose.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: GameColors.lose, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rejection.message,
              style: const TextStyle(color: GameColors.cream, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Undo, repeat and clear, sitting above the board.
///
/// The ad refill used to be a fourth button here, squeezed in only when the
/// player was already broke. It now lives in the hero card, where there is room
/// to explain it.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final bool busy =
        controller.phase == RollPhase.rolling ||
        controller.phase == RollPhase.settled;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy || !controller.wallet.hasBets
                ? null
                : controller.undoLastBet,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Undo'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy || !controller.canRepeatLast
                ? null
                : controller.repeatLastBet,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Repeat'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : controller.clearBoard,
            icon: const Icon(Icons.backspace_outlined, size: 18),
            label: const Text('Clear'),
          ),
        ),
      ],
    );
  }
}

/// Transient message bar, with a retry that only appears when there is
/// something to retry.
class _Toast extends StatelessWidget {
  const _Toast({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xEE05170F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GameColors.brassDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.info_outline, color: GameColors.brass, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(color: GameColors.cream, fontSize: 13),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: GameColors.brass,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}
