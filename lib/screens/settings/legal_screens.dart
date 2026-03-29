import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          """
Privacy Policy

1. Introduction
Welcome to PawCare. We respect your privacy and are committed to protecting your personal data.

2. Data We Collect
We collect your email address and feeding schedules to provide the service. We do not sell your data.

3. How We Use Your Data
- To manage your account via Firebase Authentication.
- To sync your feeding schedules across devices.
- To send you notifications about feeding times.

4. Data Security
We use industry-standard security measures provided by Google Firebase to protect your data.

5. Contact Us
If you have questions, please contact us at support@petfeeder.com.
          """,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms of Service"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          """
Terms of Service

1. Acceptance of Terms
By using the PawCare app, you agree to these terms.

2. Usage
You agree to use this app only for its intended purpose of managing pet feeding schedules.

3. Account Responsibility
You are responsible for maintaining the confidentiality of your account credentials.

4. Limitation of Liability
PawCare is not liable for any damages arising from the use or inability to use this app.

5. Changes to Terms
We verify the right to modify these terms at any time. Continued use of the app constitutes acceptance of new terms.
          """,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
