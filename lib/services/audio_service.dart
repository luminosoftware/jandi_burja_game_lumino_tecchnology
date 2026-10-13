import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Every sound the game can make.
enum GameSound {
  chipPlace('audio/chip_place.wav'),
  select('audio/select.wav'),
  diceRattle('audio/dice_rattle.wav'),
  diceRoll3d('audio/dice_roll_3d.wav'),
  win('audio/win.wav'),
  winBig('audio/win_big.wav'),
  lose('audio/lose.wav');

  const GameSound(this.assetPath);

  final String assetPath;

  /// Sounds short and often repeated, which is what a chip being placed is.
  ///
  /// Taps and the dice are held in a low-latency voice, which is a sample in
  /// memory: fast enough to land under the player's finger and to overlap the
  /// dice rolling over the rattle. The win stingers are heard once, after the
  /// dice have stopped, so they play through a plain preloaded player.
  bool get isTap => this == GameSound.chipPlace || this == GameSound.select;

  /// Taps and the dice are replayed mid-flight as the player keeps tapping and
  /// the dice keep rolling, so each gets a second voice. A stinger lands once.
  int get voiceCount => isTap || _isDice ? 2 : 1;

  bool get _isDice =>
      this == GameSound.diceRattle || this == GameSound.diceRoll3d;

  /// A tap voice is a pooled sample; everything else is a prepared media player.
  PlayerMode get playerMode =>
      isTap ? PlayerMode.lowLatency : PlayerMode.mediaPlayer;

  /// A tap voice is released after it sounds; a longer sound is kept loaded so
  /// the next roll can replay it without reading the file again.
  ReleaseMode get releaseMode =>
      isTap ? ReleaseMode.release : ReleaseMode.stop;

  /// How loud the sound plays relative to the others.
  ///
  /// The chip and select clicks are what the player hears under their own
  /// finger, so they play at full level; the dice and the stingers are held a
  /// little back, partly for headroom and partly so the click still cuts
  /// through when a bet lands mid-celebration.
  double get volume => isTap ? 1.0 : 0.8;
}

/// Plays the bundled offline sound effects.
///
/// Playback is fire-and-forget: a failure to play a sound must never interrupt
/// gameplay, so every call is wrapped and swallowed. The game is designed to be
/// fully playable muted.
class AudioService {
  AudioService({AudioPlayer? player}) : _injected = player;

  /// Created on first use rather than in the constructor.
  ///
  /// Building an `AudioPlayer` reaches a platform channel, so constructing one
  /// eagerly would make merely creating a [GameController] depend on the audio
  /// plugin being present and working. Lazily, a device with a broken or
  /// missing audio implementation still gets a playable game.
  final AudioPlayer? _injected;
  AudioPlayer? _player;
  bool _configured = false;

  /// Ready-to-play voices for every sound, and the round-robin cursor into
  /// them. Empty until [warm] has run, and deliberately left empty when sound
  /// is off, so a muted game never touches the platform.
  final Map<GameSound, List<_Voice>> _voices = <GameSound, List<_Voice>>{};
  final Map<GameSound, int> _voiceCursor = <GameSound, int>{};
  bool _warmed = false;

  AudioPlayer? get _instance => _player ??= _injected ?? AudioPlayer();

  bool _soundEnabled = true;

  /// Set false by the player in settings. When false, [play] is a no-op.
  bool get soundEnabled => _soundEnabled;

  void configure({required bool sound}) {
    _soundEnabled = sound;
  }

  /// Low-latency pooled player, released when the game closes.
  final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Preloads every sound so the first play is as fast as the hundredth.
  ///
  /// This is the whole point of the class: [play] used to hand the player a
  /// promise that took three platform round trips to configure the player and
  /// then read the sound off disk, which is exactly the gap a chip click should
  /// never have, and which made the dice land a beat after they were thrown.
  /// The dice and the stingers used to go through that slow path; now all of
  /// them are prepared at startup. Each sound keeps its own player, so the
  /// rattle, the landing and the win no longer interrupt one another.
  ///
  /// Callers fire this and forget: it is not awaited by the game, and every
  /// failure inside it is swallowed, so a device without a working audio
  /// implementation simply falls back to playing unprepared.
  void warm() {
    if (_warmed || !_soundEnabled) return;
    _warmed = true;
    for (final GameSound sound in GameSound.values) {
      unawaited(_loadVoices(sound));
    }
  }

  Future<void> _loadVoices(GameSound sound) async {
    final int voicesPerSound = sound.voiceCount;
    final List<_Voice> loaded = <_Voice>[];
    for (int i = 0; i < voicesPerSound; i++) {
      try {
        final AudioPlayer player = AudioPlayer();
        await player.setPlayerMode(sound.playerMode);
        await player.setAudioContext(_audioContext);
        await player.setSource(AssetSource(sound.assetPath));
        await player.setReleaseMode(sound.releaseMode);
        // Keep the effects at a sensible level relative to each other, and
        // never duck whatever music the player has going.
        await player.setVolume(sound.volume);
        loaded.add(_Voice(player));
      } catch (error) {
        debugPrint('AudioService: could not preload ${sound.name}: $error');
        break;
      }
    }
    if (loaded.isEmpty) return;
    // A sound may have been played before warming finished, so anything the
    // fallback player already did is simply not repeated.
    if (loaded.length == voicesPerSound) _voices[sound] = loaded;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    final AudioPlayer? player = _instance;
    if (player == null) return;
    try {
      await player.setAudioContext(_audioContext);
      await player.setReleaseMode(ReleaseMode.stop);
      // Keep the sounds at a sensible level relative to whatever else the
      // player has going, and never duck music.
      await player.setVolume(0.8);
      _configured = true;
    } catch (error) {
      debugPrint('AudioService: could not configure player: $error');
    }
  }

  Future<void> play(GameSound sound) async {
    if (!_soundEnabled) return;

    final List<_Voice>? voices = _voices[sound];
    if (voices != null) {
      await _playReady(
        voices,
        _voiceCursor[sound] = (_voiceCursor[sound] ?? 0) + 1,
      );
      return;
    }

    // Not warmed yet, or a sound that has nothing to gain from warming.
    final AudioPlayer? player = _instance;
    if (player == null) return;
    try {
      await _ensureConfigured();
      await player.play(AssetSource(sound.assetPath));
    } catch (error) {
      debugPrint('AudioService: failed to play ${sound.name}: $error');
    }
  }

  /// Plays the next voice in rotation, seeking it back to the start first.
  ///
  /// A prepared voice already holds its sample in memory, so this is a rewind
  /// and a play, not a load. Seeking is the one thing a low-latency sample does
  /// not do, hence the fallback for the mock plugin.
  Future<void> _playReady(List<_Voice> voices, int cursor) async {
    final _Voice voice = voices[cursor % voices.length];
    try {
      try {
        await voice.player.seek(Duration.zero);
      } catch (error) {
        debugPrint('AudioService: seek unsupported, replaying: $error');
      }
      await voice.player.resume();
    } catch (error) {
      debugPrint('AudioService: failed to play a prepared voice: $error');
    }
  }

  Future<void> dispose() async {
    try {
      for (final List<_Voice> voices in _voices.values) {
        for (final _Voice voice in voices) {
          await voice.player.dispose();
        }
      }
      _voices.clear();
      _voiceCursor.clear();
      _warmed = false;
      await _player?.dispose();
    } catch (error) {
      debugPrint('AudioService: dispose failed: $error');
    } finally {
      _player = null;
      _configured = false;
    }
  }
}

/// One preloaded sound.
///
/// A wrapper rather than a bare [AudioPlayer] so the reason a sound is held in
/// a list of these, instead of played unprepared, is visible where it is built.
class _Voice {
  const _Voice(this.player);

  final AudioPlayer player;
}
