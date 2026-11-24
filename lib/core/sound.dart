/// Sound effects and background music. Nothing here ever throws to the UI:
/// failures (web autoplay rules, missing codecs, no audio device) are swallowed
/// and recorded in [SoundService.lastError].
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Sound effects bundled in `assets/audio`.
enum Sfx {
  /// Soft tap on game screens.
  tap('audio/tap.mp3', volume: 0.35, maxPlayers: 2, minIntervalMs: 60),

  /// Wheel peg tick (limited to 25 per second).
  tick('audio/tick.mp3', volume: 0.3, maxPlayers: 4, minIntervalMs: 40),

  /// Kelopak received.
  claim('audio/claim.mp3'),

  /// Streak bonus (day 7, 14, ...).
  bonus('audio/bonus.mp3'),

  /// Wheel starts spinning.
  spinStart('audio/spin_start.mp3'),

  /// Free product won.
  winProduct('audio/win_product.mp3'),

  /// Gentle "not possible" cue.
  softError('audio/soft_error.mp3'),

  /// Voucher or stage unlocked.
  unlock('audio/unlock.mp3'),

  /// Brand notification chime.
  notifikasi('audio/brand_notifikasi.mp3');

  const Sfx(
    this.asset, {
    this.volume = 0.8,
    this.maxPlayers = 2,
    this.minIntervalMs = 120,
  });

  /// Path relative to `assets/` (the audioplayers cache prefix).
  final String asset;

  /// Playback volume 0..1.
  final double volume;

  /// Players kept warm in the pool.
  final int maxPlayers;

  /// Repeats closer than this are dropped.
  final int minIntervalMs;
}

/// Background music asset (relative to `assets/`).
const String bgmAsset = 'audio/bgm_jingle.mp3';

/// Background music volume.
const double bgmVolume = 0.35;

/// Plays [Sfx] through one lazily created [AudioPool] per effect and loops the
/// brand jingle as background music.
///
/// An effect whose pool is still loading is dropped instead of playing late
/// ([init] warms every pool at start-up).
///
/// Music is reference counted: every [startMusic] must be balanced by one
/// [stopMusic] (the `BgmScope` widget does this for a screen). It only sounds
/// while [musicEnabled] is on, at least one holder is active and the app is in
/// the foreground ([setForeground]).
class SoundService {
  /// Real audio output.
  SoundService() : _silent = false;

  /// No audio at all (tests, platforms without audio). All calls are no-ops.
  SoundService.silent() : _silent = true;

  static const int _retryAfterMs = 5000;

  final bool _silent;
  final Map<Sfx, AudioPool> _ready = <Sfx, AudioPool>{};
  final Map<Sfx, Future<AudioPool?>> _loading = <Sfx, Future<AudioPool?>>{};
  final Map<Sfx, int> _lastPlayMs = <Sfx, int>{};
  final Map<Sfx, int> _failedAtMs = <Sfx, int>{};
  final Stopwatch _stopwatch = Stopwatch()..start();
  Future<void>? _contextReady;
  Future<void> _musicQueue = Future<void>.value();
  AudioPlayer? _bgm;
  bool _bgmPlaying = false;
  bool _musicEnabled = false;
  bool _foreground = true;
  int _musicHolders = 0;
  bool _disposed = false;
  Object? _lastError;

  /// Whether this service never makes sound.
  bool get isSilent => _silent;

  /// Last swallowed audio error (diagnostics only).
  Object? get lastError => _lastError;

  /// Sound effects switch (Akun > Suara & getar).
  bool sfxEnabled = true;

  /// Background music switch (default off).
  bool get musicEnabled => _musicEnabled;
  set musicEnabled(bool value) {
    _musicEnabled = value;
    if (!_silent) _syncMusic();
  }

  /// Number of active music holders.
  int get musicHolders => _musicHolders;

  /// Configures the shared audio context and warms every effect pool.
  ///
  /// Safe to skip: [play] starts loading a missing pool. Never throws.
  Future<void> init() async {
    if (_silent || _disposed) return;
    await _ensureAudioContext();
    for (final sfx in Sfx.values) {
      await _poolFor(sfx);
    }
  }

  /// Plays [sfx] when effects are enabled. Returns immediately.
  void play(Sfx sfx) {
    if (_silent || _disposed || !sfxEnabled) return;
    final now = _stopwatch.elapsedMilliseconds;
    final last = _lastPlayMs[sfx];
    if (last != null && now - last < sfx.minIntervalMs) return;
    _lastPlayMs[sfx] = now;
    final pool = _ready[sfx];
    if (pool == null) {
      unawaited(_poolFor(sfx));
      return;
    }
    unawaited(_guard(() => pool.start(volume: sfx.volume)));
  }

  /// Adds a music holder (a screen that wants background music).
  void startMusic() {
    if (_silent || _disposed) return;
    _musicHolders++;
    _syncMusic();
  }

  /// Removes a music holder; music pauses when none is left.
  void stopMusic() {
    if (_silent || _disposed) return;
    if (_musicHolders > 0) _musicHolders--;
    _syncMusic();
  }

  /// Pauses music while the app is in the background and resumes it after.
  void setForeground(bool foreground) {
    if (_silent || _disposed) return;
    _foreground = foreground;
    _syncMusic();
  }

  /// Releases every player. The service is unusable afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final pending in List<Future<AudioPool?>>.of(_loading.values)) {
      await pending;
    }
    final pools = List<AudioPool>.of(_ready.values);
    _ready.clear();
    for (final pool in pools) {
      await _guard(pool.dispose);
    }
    await _musicQueue;
    final bgm = _bgm;
    _bgm = null;
    if (bgm != null) await _guard(bgm.dispose);
  }

  Future<AudioPool?> _poolFor(Sfx sfx) {
    final ready = _ready[sfx];
    if (ready != null) return Future<AudioPool?>.value(ready);
    final loading = _loading[sfx];
    if (loading != null) return loading;
    final failedAt = _failedAtMs[sfx];
    if (_disposed ||
        (failedAt != null &&
            _stopwatch.elapsedMilliseconds - failedAt < _retryAfterMs)) {
      return Future<AudioPool?>.value();
    }
    final created = _createPool(sfx).then((pool) {
      _loading.remove(sfx);
      if (pool == null) {
        _failedAtMs[sfx] = _stopwatch.elapsedMilliseconds;
      } else {
        _ready[sfx] = pool;
      }
      return pool;
    });
    _loading[sfx] = created;
    return created;
  }

  Future<AudioPool?> _createPool(Sfx sfx) async {
    try {
      await _ensureAudioContext();
      final pool = await AudioPool.createFromAsset(
        path: sfx.asset,
        maxPlayers: sfx.maxPlayers,
      );
      if (_disposed) {
        await _guard(pool.dispose);
        return null;
      }
      return pool;
    } catch (error) {
      _lastError = error;
      return null;
    }
  }

  Future<void> _ensureAudioContext() => _contextReady ??= _guard(
    () => AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    ),
  );

  void _syncMusic() {
    _musicQueue = _musicQueue.then((_) => _applyMusic()).catchError((
      Object error,
    ) {
      _lastError = error;
    });
  }

  Future<void> _applyMusic() async {
    final shouldPlay =
        !_disposed && _musicEnabled && _musicHolders > 0 && _foreground;
    if (shouldPlay == _bgmPlaying) return;
    if (shouldPlay) {
      final player = _bgm ??= await _createBgm();
      if (player == null) return;
      final started = await _guard(() async {
        await player.setVolume(bgmVolume);
        await player.resume();
      });
      _bgmPlaying = started;
    } else {
      final player = _bgm;
      if (player != null) await _guard(player.pause);
      _bgmPlaying = false;
    }
  }

  Future<AudioPlayer?> _createBgm() async {
    AudioPlayer? player;
    try {
      await _ensureAudioContext();
      player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource(bgmAsset));
      return player;
    } catch (error) {
      _lastError = error;
      if (player != null) await _guard(player.dispose);
      return null;
    }
  }

  /// Runs [action]; returns false (and records the error) instead of throwing.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      _lastError = error;
      return false;
    }
  }
}
