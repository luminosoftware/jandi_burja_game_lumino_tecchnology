import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/symbol.dart';
import '../../state/game_controller.dart';
import 'symbol_icon.dart';

/// The six-symbol betting mat.
///
/// One framed panel with a shared divider grid rather than six loose cards, so
/// the six symbols read as a single betting layout. Tapping a cell stages one
/// chip; the small square badge on a funded cell removes one, and long-pressing
/// adds half.
class BettingBoard extends StatelessWidget {
  const BettingBoard({
    super.key,
    required this.controller,
    required this.bets,
    required this.enabled,
  });

  final GameController controller;

  /// Currently staged wagers, so the mat can be a pure function of state.
  final Map<Symbol, int> bets;

  /// False while the dice are moving or a result is awaiting acknowledgement.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Three columns on a phone in portrait, six across when there is room
        // for it, so the same mat serves both orientations.
        final int columns = constraints.maxWidth >= 560 ? 6 : 3;
        final int rows = (Symbol.values.length / columns).ceil();

        // Placing a chip repaints the one cell that changed. Confining that to
        // this layer keeps the rest of the table out of the repaint.
        return RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[GameColors.feltLight, GameColors.feltMid],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x66D4A94E), width: 2),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _MatCaption(),
                Table(
                  defaultColumnWidth: const FlexColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder.symmetric(
                    inside: const BorderSide(color: Color(0x1FFFFFFF)),
                  ),
                  children: <TableRow>[
                    for (int row = 0; row < rows; row++)
                      TableRow(
                        children: <Widget>[
                          for (int col = 0; col < columns; col++)
                            _matCell(Symbol.values[row * columns + col]),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _matCell(Symbol symbol) {
    return _MatCell(
      symbol: symbol,
      amount: bets[symbol] ?? 0,
      enabled: enabled,
      onAdd: () => controller.addBet(symbol),
      onRemove: () => controller.removeBet(symbol),
      onAddHalf: () => controller.addHalf(symbol),
    );
  }
}

/// The heading printed on the mat, centred over the symbol grid.
class _MatCaption extends StatelessWidget {
  const _MatCaption();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text(
        'PLACE YOUR BETS',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: GameColors.brass,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _MatCell extends StatelessWidget {
  const _MatCell({
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
    return Semantics(
      button: true,
      label: '${symbol.label} bet',
      value: _funded ? '$amount coins' : 'no bet',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onAdd : null,
        onLongPress: _funded && enabled ? onAddHalf : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          decoration: BoxDecoration(
            color: _funded
                ? GameColors.brass.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _funded
                ? Border.all(color: GameColors.brass, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The artwork carries the cell: the remove badge and the staged
              // chip sit on top of it rather than pushing it around.
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset(
                        symbol.whiteBgImageAsset,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (_funded && enabled)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: _RemoveBadge(onTap: onRemove),
                      ),
                    if (_funded)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Center(child: _StakeChip(amount: amount)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                symbol.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GameColors.cream,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The remove control on a funded cell: a small rounded square, deliberately
/// not a circle so it reads as a control rather than another chip.
class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameColors.ink.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(Icons.remove, size: 15, color: GameColors.cream),
        ),
      ),
    );
  }
}

/// The wager sitting on a cell: a chip icon with the amount.
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
        border: Border.all(color: GameColors.brassDark, width: 1),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
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
