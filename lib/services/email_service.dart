import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  // TODO: Ideally, store these securely or ask user to input them. 
  // For this personal app, we will use the provided App Password.
  final String _username = 'jemminguito13@gmail.com';
  final String _password = 'xjyp vfzc mkub xnyq'; 

  Future<void> sendOtpEmail(String recipientEmail, String userName, String otp) async {
    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'Pet Feeder App')
      ..recipients.add(recipientEmail)
      ..subject = 'Your Pet Feeder Verification Code'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #FF9800;">Pet Feeder Verification</h2>
          <p>Hello $userName,</p>
          <p>Your verification code is:</p>
          <div style="background: #f5f5f5; padding: 15px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #FF9800;">
            $otp
          </div>
          <p>This code will expire in 10 minutes.</p>
          <p>If you didn't request this code, please ignore this email.</p>
          <br>
          <p style="color: #666;">- Smart Pet Feeder Team</p>
        </div>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('OTP sent: $sendReport');
    } on MailerException catch (e) {
      debugPrint('OTP not sent: ${e.toString()}');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      rethrow;
    }
  }

  Future<void> sendFeedNotification(String recipientEmail, String petName) async {
    if (_username == 'your-email@gmail.com') {
      debugPrint("EmailService: Username not configured.");
      return;
    }

    final smtpServer = gmail(_username, _password);

    final message = Message()
      ..from = Address(_username, 'Pet Feeder App')
      ..recipients.add(recipientEmail)
      ..subject = 'Feeding Successful: $petName'
      ..text = 'Your pet $petName has been successfully fed at ${DateTime.now().toString()}.\n\n- Smart Pet Feeder';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: ' + sendReport.toString());
    } on MailerException catch (e) {
      debugPrint('Message not sent. \n' + e.toString());
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
    }
  }
}
