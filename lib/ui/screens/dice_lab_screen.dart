import 'dart:async';
import 'dart:convert' show base64Encode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

import '../../core/theme.dart';
import '../../models/symbol.dart';
import '../../services/audio_service.dart';
import '../../state/game_controller.dart';
import 'dice_lab_web.dart';

/// A practice table for the 3D dice. Free throws, no bets, nothing at stake.
///
/// The dice, the physics and this screen's chrome are all inside the web view:
/// [buildDiceLabViewer] hands a loopback-served HTML page to `model_viewer_plus`
/// and the throw runs as JavaScript at 240 hertz, off the Flutter UI thread
/// entirely. Flutter's job here is to host that page, to play the game's own
/// sounds when it throws, and to provide a way out - everything else is the
/// page's.
///
/// The one thing Flutter gives the page is the symbol art: the page is served
/// over loopback with no route to the bundled images, so this screen reads them
/// from the asset bundle and hands them to the page as base64, which is what
/// the label and roll history draw instead of the page's own emoji fallback.
///
/// Deliberately not wired to [GameController]. Nothing here reads the wallet,
/// moves a chip or advances a round, and that is the whole point: a practice
/// mode that touched the balance would be the real mode with a different label
/// on it. The controller is taken for its sound service alone.
class DiceLabScreen extends StatefulWidget {
  const DiceLabScreen({super.key, required this.controller});

  /// Used only for audio. See the note above.
  final GameController controller;

  /// Test seam for the body of the screen.
  ///
  /// The real viewer opens a local HTTP server and a platform web view in its
  /// `initState`, and neither exists under `flutter test`, where no plugin is
  /// registered. It also parks a spinner on screen until both are ready, which
  /// would never settle. So tests install this and get a plain placeholder;
  /// leaving it null is what a device sees.
  @visibleForTesting
  static Widget Function()? viewerOverride;

  @override
  State<DiceLabScreen> createState() => _DiceLabScreenState();
}

class _DiceLabScreenState extends State<DiceLabScreen> {
  /// Each die number to its symbol art as a base64 `data:` URI, keyed the way
  /// the page's `SYMBOL_IMAGES` map is. Null until the assets have loaded.
  Map<int, String>? _symbolImages;

  @override
  void initState() {
    super.initState();
    // Tests replace the whole viewer, so there is nothing for the art to be
    // painted into: skip the read and go straight to the placeholder.
    if (DiceLabScreen.viewerOverride == null) {
      unawaited(_loadSymbolImages());
    }
  }

  Future<void> _loadSymbolImages() async {
    try {
      final Map<int, String> images = <int, String>{};
      for (final Symbol symbol in Symbol.values) {
        final ByteData data = await rootBundle.load(symbol.whiteBgImageAsset);
        final String base64 = base64Encode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        images[symbol.dieNumber] = 'data:image/png;base64,$base64';
      }
      if (!mounted) return;
      setState(() => _symbolImages = images);
    } catch (_) {
      // A missing or unreadable asset costs the art, not the table: the page
      // falls back to its own symbols and every throw still works.
      if (!mounted) return;
      setState(() => _symbolImages = const <int, String>{});
    }
  }

  /// Pops the route. Called from the back arrow inside the page's app bar.
  void _goBack() {
    if (mounted) Navigator.of(context).maybePop();
  }

  /// Called from the page the moment the dice leave the cup.
  ///
  /// A practice throw is a throw and nothing else, so it makes one sound, at
  /// the instant it happens: the rattle that the dice are in the hand. There is
  /// no landing sound and no delay held back for one, so a quick tap is heard
  /// the moment it lands rather than a beat later.
  void _onThrow() {
    if (!mounted) return;
    unawaited(widget.controller.audio.play(GameSound.diceRattle));
  }

  @override
  Widget build(BuildContext context) {
    final Widget viewer =
        DiceLabScreen.viewerOverride?.call() ??
        (_symbolImages == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: GameColors.brass,
                  semanticsLabel: 'Loading the dice table',
                ),
              )
            : buildDiceLabViewer(
                onBack: _goBack,
                onThrow: _onThrow,
                symbolImages: _symbolImages!,
              ));

    return Scaffold(
      // Matches the page's own app bar, so the web view never flashes white
      // behind its chrome while the loopback server is starting.
      backgroundColor: const Color(0xFF14501A),
      body: SafeArea(
        // The page draws its own bar and positions its dice against the top of
        // the window, so only the bottom is left alone.
        bottom: false,
        child: viewer,
      ),
    );
  }
}
