import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class SimulatorService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _subscription;
  bool _isSimulating = false;

  bool get isSimulating => _isSimulating;

  void toggleSimulation(bool enable) {
    _isSimulating = enable;
    if (_isSimulating) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _startListening() {
    _subscription = _database.child('feed_command/status').onValue.listen((event) async {
      if (event.snapshot.value == 'PENDING') {
        print("Simulator: Received PENDING command. Processing...");
        
        // Simulate processing delay
        await Future.delayed(const Duration(seconds: 2));
        await _database.child('feed_command').update({'status': 'PROCESSING'});
        print("Simulator: Status updated to PROCESSING");

        // Simulate dispensing delay
        await Future.delayed(const Duration(seconds: 2));
        await _database.child('feed_command').update({'status': 'SUCCESS'});
        print("Simulator: Status updated to SUCCESS");

        // Log the event (Mocking ESP32 logging)
         final timestamp = DateTime.now().millisecondsSinceEpoch;
         await _database.child('logs').push().set({
           'status': 'SUCCESS',
           'timestamp': timestamp,
           'source': 'SIMULATOR'
         });
      }
    });
  }

  void _stopListening() {
    _subscription?.cancel();
  }
}
