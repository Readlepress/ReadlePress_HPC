import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// GPS timestamp corroboration per the spec.
/// Priority order:
/// 1. GPS fix — highest quality offline timestamp
/// 2. Device clock with stored GPS offset — if GPS unavailable but fix in last 24h
/// 3. NTP-synced device clock
/// 4. Device clock only — lowest confidence (LOW)
class GpsTimestampService {
  GpsTimestampService({
    this.gpsOffsetStorage,
    this.ntpSyncChecker,
  });

  /// Storage for last known GPS clock offset (ms). Key: 'gps_clock_offset_ms'
  final GpsOffsetStorage? gpsOffsetStorage;

  /// Returns true if device clock is NTP-synced.
  final NtpSyncChecker? ntpSyncChecker;

  static const _gpsOffsetKey = 'gps_clock_offset_ms';
  static const _lastGpsFixKey = 'last_gps_fix_at';
  static const _maxOffsetAgeHours = 24;

  /// Get the best available timestamp with source and confidence.
  Future<TimestampResult> getTimestamp() async {
    final now = DateTime.now();

    // 1. Try GPS fix
    final gpsResult = await _tryGpsFix();
    if (gpsResult != null) return gpsResult;

    // 2. Device clock with stored GPS offset (if fix in last 24h)
    final offsetResult = await _tryStoredGpsOffset(now);
    if (offsetResult != null) return offsetResult;

    // 3. NTP-synced device clock
    final ntpResult = await _tryNtpSynced(now);
    if (ntpResult != null) return ntpResult;

    // 4. Device clock only — lowest confidence
    return TimestampResult(
      timestamp: now,
      source: TimestampSource.deviceClock,
      confidence: TimestampConfidence.low,
    );
  }

  Future<TimestampResult?> _tryGpsFix() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final timestamp = position.timestamp;
      await _storeGpsOffset(timestamp);
      return TimestampResult(
        timestamp: timestamp,
        source: TimestampSource.gpsFix,
        confidence: TimestampConfidence.high,
      );
    } catch (_) {
      // GPS unavailable
    }
    return null;
  }

  Future<TimestampResult?> _tryStoredGpsOffset(DateTime now) async {
    if (gpsOffsetStorage == null) return null;

    final offsetMs = await gpsOffsetStorage!.get(_gpsOffsetKey);
    final lastFixStr = await gpsOffsetStorage!.get(_lastGpsFixKey);

    if (offsetMs == null || lastFixStr == null) return null;

    final offset = int.tryParse(offsetMs);
    if (offset == null) return null;

    final lastFix = DateTime.tryParse(lastFixStr);
    if (lastFix == null) return null;

    final age = now.difference(lastFix);
    if (age.inHours > _maxOffsetAgeHours) return null;

    final adjusted = now.add(Duration(milliseconds: -offset));
    return TimestampResult(
      timestamp: adjusted,
      source: TimestampSource.gpsOffset,
      confidence: TimestampConfidence.medium,
    );
  }

  Future<void> _storeGpsOffset(DateTime gpsTime) async {
    if (gpsOffsetStorage == null) return;

    final deviceNow = DateTime.now();
    final offsetMs = deviceNow.difference(gpsTime).inMilliseconds;

    await gpsOffsetStorage!.set(_gpsOffsetKey, offsetMs.toString());
    await gpsOffsetStorage!.set(_lastGpsFixKey, gpsTime.toIso8601String());
  }

  Future<TimestampResult?> _tryNtpSynced(DateTime now) async {
    if (ntpSyncChecker == null) return null;
    final isSynced = await ntpSyncChecker!.isNtpSynced();
    if (!isSynced) return null;

    return TimestampResult(
      timestamp: now,
      source: TimestampSource.ntpSynced,
      confidence: TimestampConfidence.medium,
    );
  }
}

class TimestampResult {
  TimestampResult({
    required this.timestamp,
    required this.source,
    required this.confidence,
  });

  final DateTime timestamp;
  final TimestampSource source;
  final TimestampConfidence confidence;

  String get timestampSource => source.name;
  String get timestampConfidence => confidence.name;
}

enum TimestampSource {
  gpsFix,
  gpsOffset,
  ntpSynced,
  deviceClock,
}

extension on TimestampSource {
  String get name {
    switch (this) {
      case TimestampSource.gpsFix:
        return 'GPS_FIX';
      case TimestampSource.gpsOffset:
        return 'GPS_OFFSET';
      case TimestampSource.ntpSynced:
        return 'NTP_SYNCED';
      case TimestampSource.deviceClock:
        return 'DEVICE_CLOCK';
    }
  }
}

enum TimestampConfidence {
  high,
  medium,
  low,
}

extension on TimestampConfidence {
  String get name {
    switch (this) {
      case TimestampConfidence.high:
        return 'HIGH';
      case TimestampConfidence.medium:
        return 'MEDIUM';
      case TimestampConfidence.low:
        return 'LOW';
    }
  }
}

abstract class GpsOffsetStorage {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

abstract class NtpSyncChecker {
  Future<bool> isNtpSynced();
}
