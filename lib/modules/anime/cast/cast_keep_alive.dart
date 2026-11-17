import 'dart:io';

import 'package:flutter/services.dart';

/// Casting in the background and on the lock screen, done on the iOS side
/// (CastBackgroundAudio in AppDelegate.swift).
///
/// The TV reads the video through a small server inside the app, so the app
/// has to keep running while casting. iOS freezes an app shortly after it
/// leaves the screen unless it is playing audio, so the iOS side plays a loop
/// of silence, mixing with other apps when they play sound. It also shows the
/// cast on the lock screen, whose buttons come back through [onCommand].
class CastKeepAlive {
  CastKeepAlive({required this.onCommand}) {
    if (_supported) _channel.setMethodCallHandler(_handleCall);
  }

  /// A lock-screen button: `play`, `pause`, `toggle`, `skip` (by `value`
  /// seconds, negative for back) or `seek` (to `value` seconds).
  final void Function(String action, double? value) onCommand;

  static const _channel = MethodChannel(
    'com.kodjodevf.mangayomi.cast_background',
  );

  static bool get _supported => Platform.isIOS;

  bool _running = false;

  Future<void> start() async {
    if (!_supported || _running) return;
    _running = true;
    await _invoke('start');
  }

  Future<void> stop() async {
    if (!_supported || !_running) return;
    _running = false;
    await _invoke('stop');
  }

  /// What the lock screen shows. Between updates it moves the time on by
  /// itself while [playing].
  Future<void> update({
    required String title,
    String? subtitle,
    String? artworkUrl,
    required Duration position,
    required Duration duration,
    required bool playing,
  }) async {
    if (!_supported || !_running) return;
    await _invoke('update', <String, Object>{
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (artworkUrl != null) 'artwork': artworkUrl,
      'position': position.inMilliseconds / 1000.0,
      'duration': duration.inMilliseconds / 1000.0,
      'playing': playing,
    });
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {}
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'command') return;
    final args = call.arguments;
    if (args is! Map) return;
    final action = args['action'];
    final value = args['value'];
    if (action is String) {
      onCommand(action, value is num ? value.toDouble() : null);
    }
  }
}
