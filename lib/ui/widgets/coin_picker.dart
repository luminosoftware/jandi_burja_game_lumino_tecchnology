import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

/// The coin denominations, as a single segmented rail.
///
/// One control split into equal value segments rather than a row of separate
/// chips: a brass thumb slides to the selected denomination, so the choice reads
/// the same way as the 2D/3D switch in the top bar. Every denomination is on
/// screen at once, so there is nothing to scroll to and nothing to discover.
class CoinPicker extends StatelessWidget {
  const CoinPicker({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final int selected;
  final bool enabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<int> values = AppConfig.chipDenominations;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: GameColors.feltDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double segment = constraints.maxWidth / values.length;
            final int activeIndex = values.indexOf(selected);
            // One stop per segment: -1 at the far left, +1 at the far right.
            final double alignX = values.length == 1
                ? 0
                : (activeIndex / (values.length - 1)) * 2 - 1;

            return Stack(
              children: <Widget>[
                // Faint rules between segments, drawn under the thumb so the
                // selected one never shows a line through it.
                for (int i = 1; i < values.length; i++)
                  Positioned(
                    left: segment * i,
                    top: 8,
                    bottom: 8,
                    width: 1,
                    child: const ColoredBox(color: Color(0x22FFFFFF)),
                  ),
                if (activeIndex >= 0)
                  AnimatedAlign(
                    alignment: Alignment(alignX, 0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: FractionallySizedBox(
                      widthFactor: 1 / values.length,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: GameColors.brass,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: GameColors.brassDark,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: <Widget>[
                    for (final int value in values)
                      Expanded(
                        child: _Segment(
                          value: value,
                          active: value == selected,
                          enabled: enabled,
                          onTap: () => onSelect(value),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One value in the rail. The whole cell is the tap target, so the number does
/// not have to be hit precisely on a phone.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.value,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final int value;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '$value coin',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FittedBox(
              // A four-digit value in a fifth of a 320 pixel rail would
              // otherwise overflow; scaling down is invisible at this size.
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                maxLines: 1,
                style: TextStyle(
                  color: active ? GameColors.ink : GameColors.cream,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
