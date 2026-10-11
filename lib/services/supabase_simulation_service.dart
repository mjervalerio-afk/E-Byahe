import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_state_manager.dart';

/// Optional Supabase integration that writes ONLY to gps_locations_test.
/// A publishable/anon key is safe for frontend use only with RLS enabled.
class SupabaseSimulationService {
  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String testShuttleId = 'shuttle-test-01';

  SupabaseClient? _client;

  bool get isConfigured => _url.startsWith('https://') && _publishableKey.isNotEmpty;
  bool get isInitialized => _client != null;

  SupabaseClient? get client {
    if (!isConfigured) return null;
    return _client ??= SupabaseClient(_url, _publishableKey);
  }

  Future<void> writeTestPosition({
    required String tripId,
    required GpsSample sample,
  }) async {
    if (sample.source != GpsSource.supabaseTestSimulation) {
      throw StateError('Only database test simulation may write test positions.');
    }
    final db = client;
    if (db == null) throw StateError('Supabase is not configured. Supply SUPABASE_URL and SUPABASE_ANON_KEY.');
    final LatLng position = sample.position;
    await db.from('gps_locations_test').insert({
      'shuttle_id': testShuttleId,
      'trip_id': tripId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'recorded_at': sample.timestamp.toUtc().toIso8601String(),
      'source_type': 'simulated',
    });
  }

  /// Emits the active test trip's location rows via Supabase Realtime.
  /// The caller must validate trip ID, timestamp, coordinate range, and source.
  Stream<List<Map<String, dynamic>>> watchTestTrip(String tripId) {
    final db = client;
    if (db == null) return const Stream<List<Map<String, dynamic>>>.empty();
    return db
        .from('gps_locations_test')
        .stream(primaryKey: const ['id'])
        .eq('shuttle_id', testShuttleId)
        .eq('trip_id', tripId);
  }
}
