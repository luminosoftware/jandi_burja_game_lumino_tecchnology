import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/symbol.dart';
import '../../state/game_controller.dart';
import 'symbol_icon.dart';

/// The six-symbol betting grid.
///
/// Tapping a cell stages one chip; the small minus button on a funded cell
/// removes one, so a bet can be built up and wound back without leaving the
/// board. Long-pressing adds half, which is the quickest route to a big stack.
class BettingBoard extends StatelessWidget {
  const BettingBoard({
    super.key,
    required this.controller,
    required this.bets,
    required this.enabled,
  });

  final GameController controller;

  /// Currently staged wagers, so the board can be a pure function of state.
  final Map<Symbol, int> bets;

  /// False while the dice are moving or a result is awaiting acknowledgement.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Three columns on a phone in portrait, six across when there is room
        // for it, so the same widget serves both orientations.
        final int columns = constraints.maxWidth >= 560 ? 6 : 3;
        const double gap = 6;
        final double cellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        // Placing a chip repaints the one cell that changed, and the ink splash
        // that follows it. Confining both to this layer is what keeps the rest
        // of the table, and the felt behind it, out of the repaint.
        return RepaintBoundary(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final Symbol symbol in Symbol.values)
                SizedBox(
                  width: cellWidth,
                  child: _BetCell(
                    symbol: symbol,
                    amount: bets[symbol] ?? 0,
                    enabled: enabled,
                    onAdd: () => controller.addBet(symbol),
                    onRemove: () => controller.removeBet(symbol),
                    onAddHalf: () => controller.addHalf(symbol),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BetCell extends StatelessWidget {
  const _BetCell({
    required this.symbol,
    required this.amount,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onAddHalf,
  });

  final Symbol symbol;
  final int amount;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onAddHalf;

  bool get _funded => amount > 0;

  @override
  Widget build(BuildContext context) {
    final Color border = _funded ? GameColors.brass : const Color(0x33FFFFFF);

    return Semantics(
      button: true,
      label: '${symbol.label} bet',
      value: _funded ? '$amount coins' : 'no bet',
      child: Material(
        color: _funded
            ? GameColors.feltLight.withValues(alpha: 0.55)
            : GameColors.feltMid,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onAdd : null,
          onLongPress: _funded && enabled ? onAddHalf : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 2),
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Reserve minimal consistent top space so name position doesn't jump when funded.
                SizedBox(
                  height: 12,
                  child: (_funded && enabled)
                      ? Align(
                          alignment: Alignment.topRight,
                          child: InkResponse(
                            onTap: onRemove,
                            radius: 12,
                            child: const Icon(
                              Icons.remove_circle_outline,
                              size: 16,
                              color: GameColors.cream,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 1),
                Text(
                  symbol.localName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9FB6AA),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    symbol.whiteBgImageAsset,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 20,
                  child: _funded
                      ? Center(child: _StakeChip(amount: amount))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The wager sitting on a cell: a chip icon with the amount, or a dimmed
/// preview of what a tap would cost.
///
/// The hint reads as an action rather than a rule. "min 10" is a constraint
/// nobody asked about; "+10" is the thing that happens when you touch the card.
class _StakeChip extends StatelessWidget {
  const _StakeChip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: GameColors.brass,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SymbolIcon.chip(size: 13, color: GameColors.ink),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$amount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GameColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
