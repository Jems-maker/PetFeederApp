import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

/// A meal slot model used inside the schedule screen.
class _MealSlot {
  final String key;       // 'morning', 'noon', 'afternoon'
  final String label;
  final IconData icon;
  final Color color;
  final int notifId;      // 1, 2, 3

  TimeOfDay time;
  bool enabled;

  _MealSlot({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.notifId,
    required this.time,
    required this.enabled,
  });
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  bool _isSaving = false;

  // Global reminder toggle
  bool _reminderEnabled = true;

  // The three meal slots
  late List<_MealSlot> _slots;

  @override
  void initState() {
    super.initState();
    _initSlots();
    _loadFromFirebase();
  }

  void _initSlots() {
    _slots = [
      _MealSlot(
        key: 'morning',
        label: 'Morning',
        icon: Icons.wb_twilight,
        color: Colors.orange,
        notifId: 1,
        time: const TimeOfDay(hour: 7, minute: 0),
        enabled: false,
      ),
      _MealSlot(
        key: 'noon',
        label: 'Noon',
        icon: Icons.wb_sunny,
        color: Colors.amber,
        notifId: 2,
        time: const TimeOfDay(hour: 12, minute: 0),
        enabled: false,
      ),
      _MealSlot(
        key: 'afternoon',
        label: 'Afternoon',
        icon: Icons.wb_cloudy,
        color: Colors.deepOrange,
        notifId: 3,
        time: const TimeOfDay(hour: 17, minute: 0),
        enabled: false,
      ),
    ];
  }

  Future<void> _loadFromFirebase() async {
    setState(() => _isLoading = true);
    try {
      final data = await _firebaseService.getMealSchedules();
      setState(() {
        for (final slot in _slots) {
          final saved = data[slot.key];
          if (saved != null && saved['time'] != null) {
            final parts = (saved['time'] as String).split(':');
            slot.time = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
            slot.enabled = saved['enabled'] ?? false;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(_MealSlot slot) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: slot.time,
    );
    if (picked != null) {
      setState(() => slot.time = picked);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      for (final slot in _slots) {
        final timeStr =
            '${slot.time.hour.toString().padLeft(2, '0')}:${slot.time.minute.toString().padLeft(2, '0')}';

        // Save to Firebase
        await _firebaseService.setMealSlot(slot.key, timeStr, slot.enabled);

        // Handle reminder notifications
        if (_reminderEnabled && slot.enabled) {
          // Schedule the next occurrence of this time
          DateTime mealDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            slot.time.hour,
            slot.time.minute,
          );
          // If time is already past today, schedule for tomorrow
          if (mealDateTime.isBefore(now)) {
            mealDateTime = mealDateTime.add(const Duration(days: 1));
          }

          await _notificationService.scheduleReminderNotification(
            notifId: slot.notifId,
            title: '🐾 ${slot.label} Meal Reminder',
            body:
                'Your pet\'s ${slot.label.toLowerCase()} feeding is in 5 minutes!',
            mealTime: mealDateTime,
          );
        } else {
          // Cancel reminder for disabled or globally off slots
          await _notificationService.cancelNotification(slot.notifId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Schedules saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Return true so HomeScreen knows to reload
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Schedule", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Toggle each meal to enable automatic feeding. Set the time for each slot.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Meal Slot Cards
                  ...List.generate(_slots.length, (i) {
                    final slot = _slots[i];
                    return _buildSlotCard(slot);
                  }),

                  const SizedBox(height: 12),

                  // Notification Reminder Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.notifications_active,
                                  color: Colors.deepPurple),
                              SizedBox(width: 8),
                              Text(
                                'Notification Reminder',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Get notified 5 minutes before each enabled meal time.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _reminderEnabled
                                  ? 'Reminders: ON'
                                  : 'Reminders: OFF',
                              style: TextStyle(
                                color: _reminderEnabled
                                    ? Colors.deepPurple
                                    : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            secondary: Icon(
                              _reminderEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              color: _reminderEnabled
                                  ? Colors.deepPurple
                                  : Colors.grey,
                            ),
                            value: _reminderEnabled,
                            activeColor: Colors.deepPurple,
                            onChanged: (val) =>
                                setState(() => _reminderEnabled = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_alt),
                      label: Text(_isSaving ? 'Saving...' : 'Save All Schedules'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 100), // Height of Bottom Nav + Padding
                ],
              ),
            ),
    );
  }

  Widget _buildSlotCard(_MealSlot slot) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slot header with toggle
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: slot.color.withOpacity(0.15),
                  child: Icon(slot.icon, color: slot.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: slot.color,
                    ),
                  ),
                ),
                Switch(
                  value: slot.enabled,
                  activeColor: slot.color,
                  onChanged: (val) => setState(() => slot.enabled = val),
                ),
              ],
            ),

            const Divider(height: 20),

            // Time display & picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Feeding Time',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      slot.time.format(context),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: slot.enabled ? slot.color : Colors.grey,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: slot.enabled ? () => _pickTime(slot) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: slot.color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.access_time, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),

            // Status chip
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: slot.enabled
                    ? slot.color.withOpacity(0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    slot.enabled ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14,
                    color: slot.enabled ? slot.color : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    slot.enabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: slot.enabled ? slot.color : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
