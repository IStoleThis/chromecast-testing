import 'dart:async';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'cast_discovery.dart';
import 'cast_keep_alive.dart';

enum CastStatus { idle, searching, connecting, casting }

/// What the lock screen shows while casting.
class CastNowPlaying {
  const CastNowPlaying({required this.title, this.subtitle, this.artworkUrl});

  final String title;
  final String? subtitle;
  final String? artworkUrl;
}

/// App-wide Chromecast state.
///
/// It is a singleton so a cast session outlives a single player screen: when
/// "play next episode" replaces the player, the new screen finds the session
/// still open and loads the next episode onto the same TV.
///
/// Playback position and duration are separate [ValueNotifier]s because they
/// tick every second, and most listeners only care about the structural state
/// (device list, connecting, casting, errors) that [notifyListeners] reports.
class CastController extends ChangeNotifier {
  CastController._();

  static final CastController instance = CastController._();

  late final CastService _service = CastService(
    discoveryProviders: [
      ChromecastDiscoveryProvider(
        mdnsLookup: useNativeDiscovery ? bonsoirLookup : null,
      ),
    ],
    sessionFactory: (device) => ChromecastSession(device: device),
  );

  /// Where the TV is in the media, while casting.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  /// How long the media on the TV is, once the receiver has reported it.
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  final StreamController<void> _finished = StreamController<void>.broadcast();

  /// Fires when the media on the TV plays through to its end.
  Stream<void> get onFinished => _finished.stream;

  CastStatus _status = CastStatus.idle;
  List<CastDevice> _devices = const [];
  CastDevice? _device;
  CastSession? _session;
  SessionState _sessionState = SessionState.disconnected;
  double? _volume;
  String? _error;
  Duration _lastLivePosition = Duration.zero;

  StreamSubscription<List<CastDevice>>? _discoverySub;
  Timer? _searchTimer;
  final List<StreamSubscription<dynamic>> _sessionSubs = [];

  int _attachedViews = 0;
  Timer? _orphanTimer;

  late final CastKeepAlive _keepAlive = CastKeepAlive(
    onCommand: _onLockScreenCommand,
  );
  CastNowPlaying? _nowPlaying;
  DateTime _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _lastSyncedPosition = Duration.zero;
  bool _lastSyncedPlaying = false;

  CastStatus get status => _status;
  bool get isCasting => _status == CastStatus.casting;
  bool get isBusy =>
      _status == CastStatus.connecting || _status == CastStatus.casting;
  List<CastDevice> get devices => _devices;
  CastDevice? get device => _device;
  double? get volume => _volume;
  String? get error => _error;
  bool get isPlaying =>
      _sessionState == SessionState.playing ||
      _sessionState == SessionState.buffering ||
      _sessionState == SessionState.loading;

  // ---------------------------------------------------------------------------
  // Player screens come and go; the session is dropped once none is left.
  // ---------------------------------------------------------------------------

  /// A player screen started using the controller.
  void attach() {
    _attachedViews++;
    _orphanTimer?.cancel();
    _orphanTimer = null;
  }

  /// A player screen is done. If it was the last one and a session is open,
  /// the session ends after a short grace period, which lets the next
  /// episode's screen take it over instead.
  void detach() {
    if (_attachedViews > 0) _attachedViews--;
    if (_attachedViews > 0) return;
    if (_session == null) {
      _stopSearching();
      return;
    }
    _orphanTimer?.cancel();
    _orphanTimer = Timer(const Duration(seconds: 6), () {
      if (_attachedViews == 0) unawaited(end());
    });
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Looks for Chromecasts on the local network for a few seconds.
  Future<void> discover() async {
    if (isBusy) return;
    await _discoverySub?.cancel();
    _discoverySub = null;
    _searchTimer?.cancel();

    _devices = const [];
    _error = null;
    _status = CastStatus.searching;
    notifyListeners();

    const timeout = Duration(seconds: 8);
    try {
      _discoverySub = _service
          .startDiscovery(
            protocols: {CastProtocol.chromecast},
            timeout: timeout,
          )
          .listen(
            (found) {
              _devices = [...found]
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
              notifyListeners();
            },
            onError: (Object error) {
              _error = 'Could not search for devices: $error';
              _endSearch();
            },
            onDone: _endSearch,
          );
      // Discovery should close itself at the timeout; this is the backstop.
      _searchTimer = Timer(timeout + const Duration(seconds: 2), _endSearch);
    } catch (error) {
      _error = 'Could not search for devices: $error';
      _endSearch();
    }
  }

  void _endSearch() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (_status == CastStatus.searching) {
      _status = CastStatus.idle;
      notifyListeners();
    }
  }

  void _stopSearching() {
    unawaited(_discoverySub?.cancel());
    _discoverySub = null;
    _service.stopDiscovery();
    _endSearch();
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  /// Connects to [device] and starts the media [buildMedia] returns on it.
  /// Returns whether it worked; on failure [error] says why.
  ///
  /// The media is built once connected so the "connecting" state shows while
  /// the stream is being inspected, which can take a few seconds.
  Future<bool> start(
    CastDevice device,
    Future<CastMedia> Function() buildMedia, {
    CastNowPlaying? nowPlaying,
  }) async {
    _orphanTimer?.cancel();
    _stopSearching();

    _error = null;
    _device = device;
    _nowPlaying = nowPlaying;
    _status = CastStatus.connecting;
    notifyListeners();

    try {
      final session = await _service.connect(device);
      _bind(session);
      final media = await buildMedia();
      _resetProgress(media);
      await session.loadMedia(media);
      _status = CastStatus.casting;
      unawaited(_stayAwake(true));
      notifyListeners();
      return true;
    } catch (error) {
      await _abort('Could not cast to ${device.name}: $error');
      return false;
    }
  }

  /// Switches the TV to [media] on the open session, e.g. for the next
  /// episode or another quality.
  Future<bool> load(CastMedia media, {CastNowPlaying? nowPlaying}) async {
    final session = _session;
    if (session == null) return false;
    try {
      if (nowPlaying != null) _nowPlaying = nowPlaying;
      _resetProgress(media);
      await session.loadMedia(media);
      _error = null;
      notifyListeners();
      _syncNowPlaying(force: true);
      return true;
    } catch (error) {
      _error = 'The TV could not play this: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> play() => _command((s) => s.play());

  Future<void> pause() => _command((s) => s.pause());

  Future<void> togglePlayPause() => isPlaying ? pause() : play();

  Future<void> seek(Duration to) async {
    final total = duration.value;
    var target = to < Duration.zero ? Duration.zero : to;
    if (total > Duration.zero && target > total) target = total;
    position.value = target;
    _syncNowPlaying(force: true);
    await _command((s) => s.seek(target));
  }

  Future<void> seekBy(Duration delta) => seek(position.value + delta);

  Future<void> setVolume(double value) {
    final volume = value.clamp(0.0, 1.0).toDouble();
    _volume = volume;
    notifyListeners();
    return _command((s) => s.setVolume(volume));
  }

  /// Stops what is playing on the TV and disconnects from it.
  Future<void> end() async {
    final session = _session;
    await _release();
    if (session == null) return;
    try {
      await session.stop();
    } catch (_) {}
    try {
      await session.disconnect();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _bind(CastSession session) {
    _session = session;
    _sessionState = session.state;
    // Filled in by volumeStream once the TV reports its volume.
    _volume = null;
    _sessionSubs
      ..add(session.stateStream.listen(_onSessionState))
      ..add(
        session.positionStream.listen((value) {
          position.value = value;
          if (_sessionState == SessionState.playing) _lastLivePosition = value;
          _syncNowPlaying();
        }),
      )
      ..add(
        session.durationStream.listen((value) {
          duration.value = value;
          _syncNowPlaying(force: true);
        }),
      )
      ..add(
        session.volumeStream.listen((value) {
          _volume = value;
          notifyListeners();
        }),
      );
  }

  void _resetProgress(CastMedia media) {
    position.value = media.startPosition ?? Duration.zero;
    duration.value = Duration.zero;
    _lastLivePosition = position.value;
  }

  void _onSessionState(SessionState next) {
    final previous = _sessionState;
    _sessionState = next;

    if (next == SessionState.disconnected) {
      // The TV (or the network) ended the session.
      if (_session != null) unawaited(_release());
      return;
    }

    final wasPlaying =
        previous == SessionState.playing ||
        previous == SessionState.buffering ||
        previous == SessionState.paused;
    if (next == SessionState.idle &&
        wasPlaying &&
        _status == CastStatus.casting &&
        _endedNearTheEnd()) {
      _finished.add(null);
    }
    notifyListeners();
    _syncNowPlaying();
  }

  bool _endedNearTheEnd() {
    final total = duration.value;
    return total > Duration.zero &&
        _lastLivePosition >= total - const Duration(seconds: 15);
  }

  Future<void> _command(Future<void> Function(CastSession session) run) async {
    final session = _session;
    if (session == null) return;
    try {
      await run(session);
    } catch (error) {
      _error = 'The TV did not respond: $error';
      notifyListeners();
    }
  }

  /// Gives up on a session that failed to start, remembering [message].
  Future<void> _abort(String message) async {
    final session = _session;
    await _release();
    _error = message;
    notifyListeners();
    try {
      await session?.disconnect();
    } catch (_) {}
  }

  Future<void> _release() async {
    for (final sub in _sessionSubs) {
      unawaited(sub.cancel());
    }
    _sessionSubs.clear();
    _session = null;
    _device = null;
    _sessionState = SessionState.disconnected;
    _status = CastStatus.idle;
    _nowPlaying = null;
    unawaited(_stayAwake(false));
    notifyListeners();
  }

  /// Lets casting carry on with the screen off or another app in front: on
  /// iOS the app keeps running by playing silence. Elsewhere the screen is
  /// just kept on (an Android app would need a foreground service instead).
  Future<void> _stayAwake(bool on) async {
    try {
      if (Platform.isIOS) {
        if (on) {
          await _keepAlive.start();
          _syncNowPlaying(force: true);
        } else {
          await _keepAlive.stop();
        }
      } else {
        await (on ? WakelockPlus.enable() : WakelockPlus.disable());
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Lock screen
  // ---------------------------------------------------------------------------

  void _onLockScreenCommand(String action, double? value) {
    final amount = value == null
        ? null
        : Duration(milliseconds: (value * 1000).round());
    switch (action) {
      case 'play':
        unawaited(play());
      case 'pause':
        unawaited(pause());
      case 'toggle':
        unawaited(togglePlayPause());
      case 'skip':
        if (amount != null) unawaited(seekBy(amount));
      case 'seek':
        if (amount != null) unawaited(seek(amount));
    }
  }

  /// Tells the lock screen where the TV is. It moves the time on by itself
  /// while playing, so this only sends when that would go wrong: a pause or
  /// play, a seek, a new duration, or every 15 seconds to stay in step.
  void _syncNowPlaying({bool force = false}) {
    final info = _nowPlaying;
    if (info == null || !isCasting) return;
    final now = DateTime.now();
    final playing = _sessionState == SessionState.playing;
    final current = position.value;
    final expected =
        _lastSyncedPosition +
        (_lastSyncedPlaying ? now.difference(_lastSyncAt) : Duration.zero);
    final unchanged =
        playing == _lastSyncedPlaying &&
        (current - expected).abs() < const Duration(seconds: 3) &&
        now.difference(_lastSyncAt) < const Duration(seconds: 15);
    if (!force && unchanged) return;
    _lastSyncAt = now;
    _lastSyncedPosition = current;
    _lastSyncedPlaying = playing;
    unawaited(
      _keepAlive.update(
        title: info.title,
        subtitle: info.subtitle,
        artworkUrl: info.artworkUrl,
        position: current,
        duration: duration.value,
        playing: playing,
      ),
    );
  }
}
