import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/translations.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
  }

  // Get translated string
  String _t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return AppTranslations.get(locale, key);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _updatePassword() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(context, 'change_password')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: _t(context, 'enter_new_password'),
            ),
            validator: (val) =>
                (val == null || val.length < 6) ? 'Min 6 chars' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newPassword = controller.text.trim();
                Navigator.pop(context); // Close dialog

                try {
                  await _user?.updatePassword(newPassword);
                  _showSuccess("Password updated successfully");
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'requires-recent-login') {
                    _showError("Please logout and login again to perform this action.");
                  } else {
                    _showError("Error: ${e.message}");
                  }
                }
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEmail() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(context, 'update_email')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: _t(context, 'enter_new_email'),
            ),
            validator: (val) =>
                (val != null && val.contains('@')) ? null : 'Invalid email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newEmail = controller.text.trim();
                Navigator.pop(context);

                try {
                  await _user?.verifyBeforeUpdateEmail(newEmail);
                  _showSuccess("Verification email sent to $newEmail. Please verify to update.");
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'requires-recent-login') {
                    _showError("Please logout and login again to perform this action.");
                  } else {
                    _showError("Error: ${e.message}");
                  }
                }
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(context, 'delete_account')),
        content: Text(
          _t(context, 'delete_warning'),
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t(context, 'cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _user?.delete();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          _showError("Please logout and login again to perform this action.");
        } else {
          _showError("Error: ${e.message}");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    final email = _user!.email ?? "No Email";

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'account_details')),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.orange.shade100,
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : "?",
              style: const TextStyle(fontSize: 40, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),

          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.blue),
            title: Text(_t(context, 'change_password')),
            onTap: _updatePassword,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.email_outlined, color: Colors.green),
            title: Text(_t(context, 'update_email')),
            onTap: _updateEmail,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 30),

          Divider(color: Colors.red.shade200),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(
              _t(context, 'delete_account'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("This action cannot be undone"),
            onTap: _deleteAccount,
            tileColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
