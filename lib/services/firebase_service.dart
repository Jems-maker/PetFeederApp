import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Feed Now
  Future<void> feedNow() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _database.child('feed_command').set({
      'timestamp': timestamp,
      'command': 'FEED',
      'status': 'PENDING'
    });
  }

  // Get Feeding Status Stream
  Stream<DatabaseEvent> get feedingStatusStream {
    return _database.child('feed_command/status').onValue;
  }

  // ── Multi-slot Schedule ──────────────────────────────────────────────────

  /// Save a single meal slot. [slot] is one of: 'morning', 'noon', 'afternoon'
  Future<void> setMealSlot(String slot, String time, bool enabled) async {
    await _database.child('schedule/$slot').set({
      'time': time,   // "HH:mm" e.g. "07:00"
      'enabled': enabled,
    });
  }

  /// Load all three meal slots from Firebase.
  /// Returns a map like: { 'morning': {'time':'07:00','enabled':true}, ... }
  Future<Map<String, Map<String, dynamic>>> getMealSchedules() async {
    final snapshot = await _database.child('schedule').get();
    final result = <String, Map<String, dynamic>>{};

    for (final slot in ['morning', 'noon', 'afternoon']) {
      result[slot] = {'time': null, 'enabled': false};
    }

    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map;
      for (final slot in ['morning', 'noon', 'afternoon']) {
        if (data[slot] != null) {
          final s = Map<String, dynamic>.from(data[slot] as Map);
          result[slot] = {
            'time': s['time'],
            'enabled': s['enabled'] ?? false,
          };
        }
      }
    }
    return result;
  }

  // ── Legacy single schedule (keep for backward compat) ───────────────────
  Future<void> setSchedule(DateTime time) async {
    final scheduleTime = DateFormat('HH:mm').format(time);
    await _database.child('schedule').update({
      'time': scheduleTime,
      'enabled': true,
    });
  }

  // Get Logs
  Query get logsQuery {
    return _database.child('logs').orderByChild('timestamp').limitToLast(20);
  }
}
