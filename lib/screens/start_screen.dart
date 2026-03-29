import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart'; // Make sure this import path is correct
import 'auth/login_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _isInitialized = false; // Tracks if Firebase is ready
  String _loadingText = "Initializing..."; // Shows what is happening

  @override
  void initState() {
    super.initState();
    _setupFirebase();
  }

  Future<void> _setupFirebase() async {
    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Update UI to say we are ready
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _loadingText = "Ready";
        });
      }
    } catch (e) {
      debugPrint("Firebase Error: $e");
      if (mounted) {
        setState(() {
          _loadingText = "Error: Check Console";
        });
      }
    }
  }

  void _handleStart() {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => const LoginScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(45),
                child: Image.asset(
                  'assets/Pawcare.png', 
                  height: 180, 
                  width: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => const Icon(Icons.pets, size: 180, color: Colors.orange),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text(
                "PawCare",
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                "Feed your pet, anytime, anywhere.",
                style: TextStyle(color: Colors.grey[600]),
              ),
              
              const SizedBox(height: 50),

              // Button Logic: Show Spinner if loading, Show START if ready
              if (!_isInitialized)
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 10),
                    Text(_loadingText, style: const TextStyle(color: Colors.grey)),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _handleStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: const Text("START", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}