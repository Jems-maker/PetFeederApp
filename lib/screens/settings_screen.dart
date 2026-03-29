import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/translations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings/account_screen.dart';
import 'settings/legal_screens.dart';
import 'settings/device_connection_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'start_screen.dart'; // Import StartScreen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    // Check Wifi
    try {
      bool isWifiConnected = await WiFiForIoTPlugin.isConnected();
      if (isWifiConnected) {
        String? ssid = await WiFiForIoTPlugin.getSSID();
        if (ssid != null && ssid.toUpperCase().contains('ESP')) {
          if (mounted) setState(() => _isConnected = true);
          return;
        }
      }
    } catch (e) {
      debugPrint("Wifi Status Error: $e");
    }
    
    // Check BLE
    try {
      List<BluetoothDevice> connectedDevices = FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        if (device.platformName.toUpperCase().contains('ESP')) {
          if (mounted) setState(() => _isConnected = true);
          return;
        }
      }
    } catch (e) {
      debugPrint("BLE Status Error: $e");
    }
    
    if (mounted) setState(() => _isConnected = false);
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Logic (firebase auth signout and clear pin)
                try {
                  await FirebaseAuth.instance.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_pin');
                } catch (e) {
                  debugPrint("Logout error: $e");
                }
                
                if (mounted) {
                  // Pop dialogue
                  Navigator.of(ctx).pop();
                
                  // Navigate to the StartScreen, clearing stack
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (c) => const StartScreen()),
                    (Route<dynamic> route) => false
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _checkForUpdates(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Checking for Updates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 20),
              Text('Please wait...'),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        _showUpdateAvailableDialog(context);
      }
    });
  }

  void _showUpdateAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: const Text('Version 1.1.0 is available! Would you like to install the new updated version?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading and automatically installing update...')),
                );
                // The actual APK download/install logic goes here
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Install Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final locale = Localizations.localeOf(context).languageCode;
    String t(String key) => AppTranslations.get(locale, key);

    // Reusable box decoration for Tailwind aesthetic
    final boxDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
        children: [
          // Device Connection Section (New)
          Text(t('device_settings').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Container(
            decoration: boxDecoration,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.devices_other, color: Colors.orange.shade700),
              ),
              title: Text(t('device_connection'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.cancel,
                    color: _isConnected ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? "Connected" : "Not Connected",
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceConnectionScreen()));
                _checkConnection(); // Re-check after coming back
              },
            ),
          ),

          const SizedBox(height: 25),

          // Appearance Section
          Text(t('appearance').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Container(
            decoration: boxDecoration,
            child: SwitchListTile(
              title: Text(t('dark_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.blue.shade700),
              ),
              value: isDark,
              activeColor: Colors.white,
              activeTrackColor: Colors.orange.shade400,
              onChanged: (val) {
                if (appState != null) {
                  appState.changeTheme(val ? ThemeMode.dark : ThemeMode.light);
                }
              },
            ),
          ),

          const SizedBox(height: 25),

          // Language Section
          Text(t('language').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Container(
            decoration: boxDecoration,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: Icon(Icons.language, color: Colors.green.shade700),
              ),
              title: Text(t('app_language'), style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: DropdownButton<String>(
                value: ['en', 'es', 'tl'].contains(locale) ? locale : 'en',
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                underline: Container(),
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text("English")),
                  DropdownMenuItem(value: 'es', child: Text("Español")),
                  DropdownMenuItem(value: 'tl', child: Text("Tagalog")),
                ],
                onChanged: (val) async {
                  if (val != null && appState != null) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    appState.changeLocale(Locale(val));
                    if (context.mounted) {
                      Navigator.pop(context); // Dismiss loading
                    }
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 25),

          // Account & Support Section
          Text(t('account_support').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Container(
            decoration: boxDecoration,
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts, color: Colors.grey),
                  title: Text(t('account_details'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.grey),
                  title: Text(t('help_center'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () async {
                    final Uri url = Uri.parse('https://example.com/faq');
                    if (!await launchUrl(url)) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch Help Center")));
                       }
                    }
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: Colors.grey),
                  title: Text(t('contact_support'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'support@petfeeder.com',
                      queryParameters: {'subject': 'Pet Feeder Support Request'},
                    );
                    if (!await launchUrl(emailLaunchUri)) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open email app")));
                       }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // About / Legal Section
          Text(t('about_legal').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Container(
            decoration: boxDecoration,
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        backgroundImage: AssetImage('assets/Pawcare.png'),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("PawCare", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Colors.grey),
                  title: Text(t('privacy_policy'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Colors.grey),
                  title: Text(t('terms_of_service'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: const Icon(Icons.system_update, color: Colors.grey),
                  title: Row(
                    children: [
                      const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: const Text("New", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    _checkForUpdates(context);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 35),
          
          // Logout Section
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showLogoutConfirmation(context);
              },
              icon: const Icon(Icons.logout, size: 20),
              label: Text(t('logout').isEmpty || t('logout') == 'logout' ? 'Logout' : t('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.red.shade100, width: 2),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
