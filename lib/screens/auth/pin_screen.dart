import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../home_screen.dart';
import '../../main.dart';
import '../../utils/translations.dart';

class PinScreen extends StatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, required this.isSetup});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  
  // Helper to get translation
  String _t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppTranslations.get(locale, key);
  }

  void _submit() async {
    final pin = _pinController.text;
    if (pin.length != 4) return;

    // Show Loading Modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 20),
            Text(_t(context, 'processing')),
          ],
        ),
      ),
    );

    // Simulate delay for "Dynamic loading spin"
    await Future.delayed(const Duration(seconds: 2));

    try {
      final prefs = await SharedPreferences.getInstance();

      if (widget.isSetup) {
        // Save locally
        await prefs.setString('user_pin', pin);
        
        // Save to Firebase for account sync
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseDatabase.instance.ref('users/${user.uid}/pin').set(pin);
        }

        if (mounted) {
          Navigator.pop(context); // Dismiss loading
          FocusScope.of(context).unfocus(); // Close keyboard
          await Future.delayed(const Duration(milliseconds: 300)); // Wait for keyboard
          if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomeScreen()));
          }
        }
      } else {
        final savedPin = prefs.getString('user_pin');
        if (savedPin == pin) {
          if (mounted) {
            Navigator.pop(context); // Dismiss loading
            FocusScope.of(context).unfocus(); // Close keyboard
            await Future.delayed(const Duration(milliseconds: 300)); // Wait for keyboard
            if (mounted) {
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomeScreen()));
            }
          }
        } else {
          if (mounted) {
            Navigator.pop(context); // Dismiss loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_t(context, 'incorrect_pin'))),
            );
            _pinController.clear();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/paw_logo.png',
                  height: 80,
                  width: 80,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.pets,
                    size: 80,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Title
              Text(
                widget.isSetup ? "Create PIN" : _t(context, 'welcome_back'), // Reusing welcome back for enter pin logic? 
                // Wait, "Enter PIN" is translation 'enter_pin' in subtitle. Title "Welcome Back" matches LoginScreen.
                // But if isSetup is true, it's "Create PIN".
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                widget.isSetup 
                    ? "Set a 4-digit PIN for quick access" 
                    : _t(context, 'enter_pin'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),
              
              // PIN Input Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "• • • •",
                    counterText: "",
                    hintStyle: TextStyle(fontSize: 32, letterSpacing: 20),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, letterSpacing: 20, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    if (val.length == 4) _submit();
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_pin');
                  if (mounted) {
                     Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                child: const Text("Log out / Switch Account", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
