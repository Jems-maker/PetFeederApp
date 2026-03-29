import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../../services/email_service.dart';
import 'login_screen.dart';
import 'pin_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailService = EmailService();
  
  String _selectedGender = 'Male';
  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _isSuccess = false; 
  bool _isVerified = false;
  String _generatedOtp = '';

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      _generatedOtp = _generateOtp();
      
      // Use First Name for the email greeting
      await _emailService.sendOtpEmail(
        _emailController.text.trim(),
        _firstNameController.text.trim(),
        _generatedOtp,
      );
      
      setState(() {
        _isOtpSent = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent! Check your email.")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send OTP: ${e.toString()}")),
        );
      }
    }
  }

  void _verifyOtp() async {
    // Show Loading Modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 20),
            Text("Verifying..."),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1)); // Simulate check

    if (!mounted) return;
    Navigator.pop(context); // Dismiss Loading

    if (_otpController.text.trim() == _generatedOtp) {
      setState(() => _isVerified = true); // Allow user to set password now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email verified! Please set your password.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP. Please try again.")),
      );
    }
  }

  void _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Disable button interactions
    setState(() => _isLoading = true);

    // Show Loading Modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 20),
            Text("Creating Account..."),
          ],
        ),
      ),
    );

    try {
      // Create user with ENTERED password
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final String firstName = _firstNameController.text.trim();
      final String lastName = _lastNameController.text.trim();
      final String fullName = "$firstName $lastName";

      // Store user profile in Realtime Database
      await FirebaseDatabase.instance.ref('users/${credential.user!.uid}').set({
        'firstname': firstName,
        'lastname': lastName,
        'fullname': fullName,
        'age': int.parse(_ageController.text.trim()),
        'gender': _selectedGender,
        'email': _emailController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      // Store credentials in SharedPreferences for PIN login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', _emailController.text.trim());
      await prefs.setString('user_password', _passwordController.text);
      await prefs.setBool('is_new_account', true); // Flag for Welcome Modal on Dashboard
      
      if (mounted) {
        Navigator.pop(context); // Dismiss Loading Modal
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }

      // Delay to show the check icon before navigating
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
           Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (c) => const PinScreen(isSetup: true))
          );
        }
      });
      
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss Loading Modal on Error
        setState(() => _isLoading = false);
      }
      
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password is too weak. Please try again.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email. Please login instead.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid. Please check and try again.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled. Please contact support.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message ?? e.code}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss Loading Modal on Error
        setState(() => _isLoading = false);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unexpected error: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSuccess) ...[
                const SizedBox(height: 50),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 100),
                      SizedBox(height: 20),
                      Text("Account Created!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      SizedBox(height: 10),
                      Text("Redirecting to PIN setup...", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ] else if (_isVerified) ...[
                // Password Setup Step
                const Text(
                   "Set Your Password",
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text("Your email has been verified. Please create a password for your account."),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.length < 6) return "Password must be at least 6 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: "Confirm Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (val) {
                    if (val != _passwordController.text) return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("Set Password & Create Account", style: TextStyle(fontSize: 16)),
                ),
              ] else if (_isOtpSent) ...[
                // OTP Step
                const Text(
                  "Email Verification",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text("We've sent a 6-digit code to your email. Please enter it below:"),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: "Verification Code",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("Verify & Continue", style: TextStyle(fontSize: 16)),
                ),
              ] else ...[
                // Personal Info Step
                const Text(
                  "Personal Information",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: "First Name",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (val) => val!.isEmpty ? "Required" : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: "Last Name",
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val!.isEmpty ? "Required" : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: "Age",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val!.isEmpty) return "Required";
                    final age = int.tryParse(val);
                    if (age == null || age < 1 || age > 120) return "Invalid age";
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wc),
                  ),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedGender = val!),
                ),
                const SizedBox(height: 15),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val!.isEmpty) return "Required";
                    if (!val.contains('@')) return "Invalid email";
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Send Verification Code", style: TextStyle(fontSize: 16)),
                ),
              ],
              
              const SizedBox(height: 20),
              if (!_isSuccess) // Hide login link if success
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => const LoginScreen()),
                  );
                },
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
