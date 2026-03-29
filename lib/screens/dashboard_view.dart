import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; 
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/email_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/translations.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_iot/wifi_iot.dart';
import '../widgets/tailwind_card.dart';
import '../widgets/feeding_chart.dart';
import '../widgets/success_pie_chart.dart';

class DashboardView extends StatefulWidget {
  final VoidCallback onNavigateToSchedule;

  const DashboardView({super.key, required this.onNavigateToSchedule});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  final EmailService _emailService = EmailService();
  
  final ValueNotifier<String> _statusNotifier = ValueNotifier("Ready");
  String _firstName = "";
  String _petName = "Your Pet";
  String _petImageUrl = "";
  
  bool _isLoading = false;
  bool _isOfflineMode = false;
  Map<String, dynamic>? _morningSlot;
  Map<String, dynamic>? _noonSlot;
  Map<String, dynamic>? _afternoonSlot;
  Timer? _checkTimer;
  Timer? _resetTimer;
  String? _lastFedTime; 
  late Stream<DateTime> _clockStream;
  bool _hasInitialized = false; 
  String? _lastKnownStatus;
  int _totalFeeds = 0;
  int _feedsToday = 0;
  int? _userCreatedAt;
  Map<dynamic, dynamic>? _logsData;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
    _notificationService.requestPermissions();
    _loadSchedule();
    _loadInitialStatus(); 
    _checkNewAccount(); 
    _listenToTotalFeeds(); 
    _fetchUserName(); 
    
    _clockStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _hasInitialized = true);
    });

    _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkSchedule();
    });

    _firebaseService.feedingStatusStream.listen((event) {
      if (event.snapshot.value != null) {
        final newStatus = event.snapshot.value.toString();
        
        if (_lastKnownStatus != null && _lastKnownStatus == newStatus) {
           _statusNotifier.value = newStatus;
          return;
        }
        
        _lastKnownStatus = newStatus;
        _statusNotifier.value = newStatus;
        
        if (newStatus == 'SUCCESS') {
          if (_statusNotifier.value != 'SUCCESS') { 
             _showNotification("Feeding Successful!", "Your pet has been fed.");
             final user = FirebaseAuth.instance.currentUser;
             if (user != null && user.email != null) {
                _emailService.sendFeedNotification(user.email!, "Pet");
             }
             
             // Log the feed online
             FirebaseDatabase.instance.ref('logs').push().set({
                'status': 'SUCCESS',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'mode': 'ONLINE'
             });
          }
          _completeFeeding(newStatus);
          _clearSchedule();
        } else if (newStatus == 'FAILED') {
          _showNotification("Feeding Failed", "Please check the machine.");
          _completeFeeding(newStatus);
        }
      }
    });
  }

  void _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        if (mounted) {
          setState(() {
            _firstName = data['firstname'] ?? (data['fullname']?.split(' ').first ?? "User");
            _petName = data['petName'] ?? "Your Pet";
            _petImageUrl = data['petImageUrl'] ?? "";
            if (data['createdAt'] != null) {
              _userCreatedAt = DateTime.tryParse(data['createdAt'])?.millisecondsSinceEpoch;
            }
          });
          _updateTotalFeeds();
        }
      }
    }
  }

  void _checkNewAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final isNew = prefs.getBool('is_new_account') ?? false;
    
    if (isNew) {
      await prefs.setBool('is_new_account', false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeModal();
      });
    }
  }

  void _showWelcomeModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Column(
          children: [
             Icon(Icons.pets, size: 50, color: Colors.orange),
             SizedBox(height: 10),
             Text("Welcome to PawCare!", textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          "We're glad to have you here! Set up a schedule or feed your pet manually from this dashboard.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Okay, Let's Go!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _listenToTotalFeeds() {
    FirebaseDatabase.instance.ref("logs").onValue.listen((event) {
      if (event.snapshot.value != null) {
         _logsData = event.snapshot.value as Map;
      } else {
         _logsData = null;
      }
      _updateTotalFeeds();
    });
  }

  void _updateTotalFeeds() {
      if (!mounted) return;
      
      if (_logsData == null) {
          setState(() {
            _totalFeeds = 0;
            _feedsToday = 0;
          });
          return;
      }

      int total = 0;
      int today = 0;
      final now = DateTime.now();
      
      _logsData!.forEach((key, value) {
        bool isSuccess = value['status'] == 'SUCCESS';
        bool isAfterCreation = true;
        final logTime = (value['timestamp'] is int) ? value['timestamp'] : 0;
        
        if (_userCreatedAt != null && value['timestamp'] != null) {
            if (logTime <= _userCreatedAt!) {
                isAfterCreation = false;
            }
        }
        
        if (isSuccess && isAfterCreation) {
          total++;
          final dt = DateTime.fromMillisecondsSinceEpoch(logTime);
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            today++;
          }
        }
      });
      
      setState(() {
        _totalFeeds = total;
        _feedsToday = today;
      });
  }

  void _loadSchedule() async {
    try {
      final data = await _firebaseService.getMealSchedules();
      setState(() {
        _morningSlot = data['morning'];
        _noonSlot = data['noon'];
        _afternoonSlot = data['afternoon'];
      });
    } catch (e) {
      debugPrint('Error loading multi-slot schedule: $e');
    }
  }

  void _loadInitialStatus() async {
    final snapshot = await FirebaseDatabase.instance.ref("feed_command/status").get();
    if (snapshot.exists && snapshot.value != null) {
      _lastKnownStatus = snapshot.value.toString();
      _statusNotifier.value = _lastKnownStatus!;
    }
  }

  void _clearSchedule() {
    debugPrint("Feed complete. Slots remain for next scheduled feeding.");
  }

  void _checkSchedule() {
    if (!_hasInitialized) return;
    if (_isLoading) return;

    final now = DateTime.now();
    final nowKey = "${now.hour}:${now.minute}";

    for (final entry in [
      {'slot': _morningSlot, 'label': 'Morning'},
      {'slot': _noonSlot, 'label': 'Noon'},
      {'slot': _afternoonSlot, 'label': 'Afternoon'},
    ]) {
      final slot = entry['slot'] as Map<String, dynamic>?;
      if (slot == null) continue;
      if (slot['enabled'] != true) continue;
      final timeStr = slot['time'] as String?;
      if (timeStr == null) continue;

      final parts = timeStr.split(':');
      final slotHour = int.tryParse(parts[0]) ?? -1;
      final slotMin = int.tryParse(parts[1]) ?? -1;

      if (now.hour == slotHour && now.minute == slotMin) {
        if (_lastFedTime != nowKey) {
          _lastFedTime = nowKey;
          debugPrint('Auto-Feeding triggered for ${entry['label']} at $nowKey');
          _handleFeedNow(isAuto: true);
          break; 
        }
      }
    }
  }

  void _showNotification(String title, String body) {
    _notificationService.showNotification(title, body);
  }

  void _completeFeeding(String finalStatus) {
    // Reset feed command status in Firebase after completion
    FirebaseDatabase.instance.ref("feed_command/status").set("Ready").catchError((e) {
      debugPrint("Error resetting feed command: $e");
    });
    
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), () {
       _statusNotifier.value = "Ready";
       if (mounted) setState(() => _isLoading = false);
    });
  }

  void _handleFeedNow({bool isAuto = false}) async {
    setState(() => _isLoading = true);
    
    if (!isAuto) {
      _showFeedingModal();
    }
    
    if (_isOfflineMode) {
      _statusNotifier.value = "Sending...";
      try {
        // Force Android to route over the Wi-Fi AP even without internet
        await WiFiForIoTPlugin.forceWifiUsage(true);

        final url = Uri.parse('http://192.168.4.1/feed');
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        
        await WiFiForIoTPlugin.forceWifiUsage(false);

        if (response.statusCode == 200) {
          _statusNotifier.value = "SUCCESS";
          _completeFeeding("SUCCESS");
          _showNotification("Offline Feeding Successful!", "Pet fed directly via ESP Wi-Fi.");
          
          // Log the feed locally. Firebase queues this until internet is restored!
          FirebaseDatabase.instance.ref('logs').push().set({
            'status': 'SUCCESS',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'mode': 'OFFLINE'
          });
        } else {
          _statusNotifier.value = "FAILED";
          _completeFeeding("FAILED");
        }
      } catch (e) {
        debugPrint("Offline feed error: $e");
        await WiFiForIoTPlugin.forceWifiUsage(false);
        _statusNotifier.value = "FAILED";
        _completeFeeding("FAILED");
      }
    } else {
      _statusNotifier.value = "Sending...";
      await _firebaseService.feedNow();
      
      // Auto-fail if Firebase hangs due to no internet (e.g. connected to ESP Wi-Fi without Offline mode enabled)
      Timer(const Duration(seconds: 15), () {
        if (_statusNotifier.value == "Sending..." && mounted) {
           _statusNotifier.value = "FAILED";
           _completeFeeding("FAILED");
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Cloud timeout. Please check internet connection or switch to Offline Mode if connected directly to device Wi-Fi.")),
           );
        }
      });
    }
  }

  void _showFeedingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<String>(
          valueListenable: _statusNotifier,
          builder: (context, status, child) {
            
            // Auto close on Success after delay
            if (status == 'SUCCESS') {
              Future.delayed(const Duration(seconds: 2), () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
            }

            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'SUCCESS') ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 60),
                    const SizedBox(height: 20),
                    const Text("Feeding Successful!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ] else if (status == 'FAILED') ...[
                    const Icon(Icons.error, color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    const Text("Feeding Failed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 20),
                    const Text("Sending Command...", style: TextStyle(fontSize: 16)),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _checkTimer?.cancel();
    _statusNotifier.dispose();
    super.dispose();
  }

  String _t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppTranslations.get(locale, key);
  }

  void reloadSchedule() {
    _loadSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Softer background for cards to pop
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Beautiful Custom Header
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 30),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  // Top row: App Name & Wifi Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            backgroundImage: AssetImage('assets/paw_logo.png'),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _t(context, 'dashboard'),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18), 
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            _isOfflineMode ? Icons.wifi_off : Icons.wifi,
                            color: Colors.white,
                            size: 20,
                          ),
                          Switch(
                            value: _isOfflineMode,
                            activeColor: Colors.white,
                            activeTrackColor: Colors.orange.shade300,
                            inactiveThumbColor: Colors.white70,
                            inactiveTrackColor: Colors.orange.shade800,
                            onChanged: (val) {
                              setState(() {
                                _isOfflineMode = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Greeting & Pet Info
                  Row(
                    children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("Hello", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                             const SizedBox(height: 5),
                             Text(
                               _firstName.isNotEmpty ? _firstName : "User",
                               style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white),
                             ),
                           ],
                         ),
                       ),
                       Container(
                         padding: const EdgeInsets.all(3),
                         decoration: const BoxDecoration(
                           color: Colors.white,
                           shape: BoxShape.circle,
                         ),
                         child: CircleAvatar(
                           radius: 35,
                           backgroundColor: Colors.orange.shade50,
                           backgroundImage: _petImageUrl.isNotEmpty 
                               ? NetworkImage(_petImageUrl) 
                               : const AssetImage('assets/paw_logo.png') as ImageProvider,
                         ),
                       ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: 25),

              // Top Metrics Row
              Row(
                children: [
                  Expanded(
                    child: TailwindCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.check_circle_outline, color: Colors.green[600]),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "$_totalFeeds", 
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green[800])
                          ),
                          Text(_t(context, 'total_feeds'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TailwindCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.today, color: Colors.blue[600]),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "$_feedsToday", 
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[800])
                          ),
                          Text(_t(context, 'feeds_today'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Pending Feed Schedule Card
              TailwindCard(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.orange[600]),
                        const SizedBox(width: 10),
                        Text(_t(context, 'pending_feed'),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildMealSlotRow('morning',  Icons.wb_twilight,  Colors.orange,     _morningSlot),
                    const SizedBox(height: 12),
                    _buildMealSlotRow('noon',     Icons.wb_sunny,     Colors.amber,      _noonSlot),
                    const SizedBox(height: 12),
                    _buildMealSlotRow('afternoon',Icons.wb_cloudy,    Colors.deepOrange, _afternoonSlot),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: widget.onNavigateToSchedule,
                      icon: const Icon(Icons.edit_calendar, color: Colors.orange),
                      label: Text(_t(context, 'set_schedule'),
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20), 
              
              // Dynamic Graph
              FeedingChart(logsData: _logsData),

              const SizedBox(height: 20),

              // Success Pie Chart
              SuccessPieChart(logsData: _logsData, userCreatedAt: _userCreatedAt),

              const SizedBox(height: 25),

              // Feed Now Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleFeedNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: Colors.orange.withOpacity(0.5),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.restaurant, size: 28),
                  label: Text(_t(context, 'feed_now')),
                ),
              ),

              const SizedBox(height: 120), // Height of Bottom Nav + Padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSlotRow(
    String label,
    IconData icon,
    Color color,
    Map<String, dynamic>? slot,
  ) {
    final enabled = slot?['enabled'] == true;
    final timeStr = slot?['time'] as String?;
    final displayLabel = label[0].toUpperCase() + label.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? color.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? color.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled ? color.withOpacity(0.2) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            displayLabel,
            style: TextStyle(
              color: enabled ? Colors.black87 : Colors.grey.shade500,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            enabled && timeStr != null
                ? _formatSlotTime(timeStr)
                : 'Not set',
            style: TextStyle(
              color: enabled ? color : Colors.grey.shade400,
              fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            enabled ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: enabled ? color : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  String _formatSlotTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }
}
