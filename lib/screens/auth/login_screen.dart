import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/register_screen.dart';
import 'pin_screen.dart';
import '../home_screen.dart';
import '../../main.dart';
import '../../utils/translations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController(); // For setting up new PIN
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Helper to get translation
  String _t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppTranslations.get(locale, key);
  }

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(context, 'fill_all_fields'))));
       return;
    }

    setState(() => _isLoading = true);

    try {
      // Authenticate with Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Save credentials locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', _emailController.text.trim());
      await prefs.setString('user_password', _passwordController.text);
      
      // Fetch PIN from Firebase
      final user = FirebaseAuth.instance.currentUser;
      String? cloudPin;
      if (user != null) {
         final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/pin').get();
         if (snapshot.exists) {
            cloudPin = snapshot.value.toString();
            await prefs.setString('user_pin', cloudPin); // Sync to local
         }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        
        // Navigate to PIN Screen for verification or setup
        if (cloudPin != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => const PinScreen(isSetup: false)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => const PinScreen(isSetup: true)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${_t(context, 'login_failed')}: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 // Logo
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
                    'assets/Pawcare.png',
                    height: 80,
                    width: 80,
                    errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 80, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 30),
                
                Text(
                  _t(context, 'login'), 
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(_t(context, 'enter_credentials'), style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 40),

                // Email Field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: _t(context, 'email'),
                    prefixIcon: const Icon(Icons.email, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: _t(context, 'password'),
                    prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(_t(context, 'login'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Register Link
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => const RegisterScreen()),
                    );
                  },
                  child: Text(_t(context, 'register_link')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
