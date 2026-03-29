import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'tailwind_card.dart';

class HealthTracker extends StatefulWidget {
  const HealthTracker({super.key});

  @override
  State<HealthTracker> createState() => _HealthTrackerState();
}

class _HealthTrackerState extends State<HealthTracker> {
  bool _vaccineDone = false;
  bool _dewormingDone = false;
  DateTime? _lastVetVisit;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vaccineDone = prefs.getBool('ht_vaccine') ?? false;
      _dewormingDone = prefs.getBool('ht_deworming') ?? false;
      final vetStr = prefs.getString('ht_vet_visit');
      if (vetStr != null) {
        _lastVetVisit = DateTime.tryParse(vetStr);
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ht_vaccine', _vaccineDone);
    await prefs.setBool('ht_deworming', _dewormingDone);
    if (_lastVetVisit != null) {
      await prefs.setString('ht_vet_visit', _lastVetVisit!.toIso8601String());
    }
  }

  void _pickVetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastVetVisit ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _lastVetVisit = picked);
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TailwindCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.red[400], size: 24),
              const SizedBox(width: 10),
              Text(
                "Health Tracker",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // Vaccination Reminder
          _buildCheckItem(
            title: "Annual Vaccination",
            value: _vaccineDone,
            icon: Icons.vaccines,
            color: Colors.blue,
            onChanged: (val) {
              setState(() => _vaccineDone = val!);
              _saveData();
            },
          ),
          
          // Deworming Reminder
          _buildCheckItem(
            title: "Deworming (Quarterly)",
            value: _dewormingDone,
            icon: Icons.bug_report,
            color: Colors.teal,
            onChanged: (val) {
              setState(() => _dewormingDone = val!);
              _saveData();
            },
          ),
          
          const Divider(height: 24),
          
          // Vet Visit Log
          InkWell(
            onTap: _pickVetDate,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_hospital, color: Colors.purple, size: 20),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Last Vet Visit", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          _lastVetVisit != null 
                              ? DateFormat('MMMM d, yyyy').format(_lastVetVisit!) 
                              : "Tap to record visit",
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String title, 
    required bool value, 
    required ValueChanged<bool?> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                decoration: value ? TextDecoration.lineThrough : null,
                color: value ? Colors.grey : Colors.black87,
              ),
            ),
          ),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }
}
