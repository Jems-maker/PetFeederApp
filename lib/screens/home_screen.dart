import 'package:flutter/material.dart';
import 'dashboard_view.dart';
import 'history_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'health_screen.dart';
import '../utils/translations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // List of screens for IndexedStack
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardView(
        onNavigateToSchedule: () {
          // Switch to Schedule tab (index 1)
          _onTabTapped(1);
        },
      ),
      const ScheduleScreen(),
      const HistoryScreen(),
      const HealthScreen(),
      const SettingsScreen(),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  String _t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppTranslations.get(locale, key);
  }

  @override
  Widget build(BuildContext context) {
    // If we want each tab to handle its own Scaffold/AppBar, we just show them in body.
    // However, if we want a shared BottomNav, we put it here.
    return Scaffold(
      extendBody: true, // Key for floating effect
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).colorScheme.surface, 
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            iconSize: 24, // Enforce icon size
            selectedFontSize: 12, // Enforce font size
            unselectedFontSize: 12, // Enforce font size
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            elevation: 0, 
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_outlined),
                activeIcon: const Icon(Icons.dashboard),
                label: _t(context, 'dashboard'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.access_time_outlined),
                activeIcon: const Icon(Icons.access_time_filled),
                label: _t(context, 'set_schedule'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_outlined),
                activeIcon: const Icon(Icons.history),
                label: _t(context, 'history'),
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.medical_services_outlined),
                activeIcon: Icon(Icons.medical_services),
                label: "Health",
              ),
              BottomNavigationBarItem(
                icon: const Badge(
                  label: Text('1'),
                  backgroundColor: Colors.red,
                  child: Icon(Icons.person_outline),
                ),
                activeIcon: const Badge(
                  label: Text('1'),
                  backgroundColor: Colors.red,
                  child: Icon(Icons.person),
                ),
                label: _t(context, 'profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}