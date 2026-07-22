import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logger_service.dart';

class AuthService {
  // Method to request access via Power Automate Webhook or Simulation
  Future<AuthResult> requestAccess({
    required String email,
    required String webhookUrl,
    bool simulateImmediate = false,
  }) async {
    logger.log('AuthService: Requesting access for $email');
    
    if (webhookUrl.trim().isEmpty) {
      logger.log('AuthService: Webhook URL is empty. Operating in Simulated Demo Mode.');
      
      // If we simulate immediate, resolve instantly, otherwise let UI manual controls handle it
      if (simulateImmediate) {
        await Future.delayed(const Duration(seconds: 2));
        return AuthResult(
          isSuccess: true,
          message: 'Simulated approval successful!',
          isMock: true,
        );
      }
      
      // Return a pending result that the simulator screen will control manually
      return AuthResult(
        isSuccess: false,
        message: 'Awaiting manual simulation actions.',
        isMock: true,
        isPending: true,
      );
    }

    try {
      logger.log('AuthService: Sending HTTP POST request to $webhookUrl');
      final response = await http.post(
        Uri.parse(webhookUrl.trim()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'deviceInfo': 'iCharger Remote Client',
          'requestTime': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(minutes: 5)); // Allow a generous timeout for manual approvals

      logger.log('AuthService: Received response code ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final status = data['status']?.toString().toLowerCase();
        
        if (status == 'approved') {
          return AuthResult(
            isSuccess: true,
            message: 'Access granted by Administrator.',
            isMock: false,
          );
        } else {
          return AuthResult(
            isSuccess: false,
            message: data['message'] ?? 'Access request was rejected by the Administrator.',
            isMock: false,
          );
        }
      } else {
        return AuthResult(
          isSuccess: false,
          message: 'Server responded with status code ${response.statusCode}.',
          isMock: false,
        );
      }
    } catch (e) {
      logger.log('AuthService Webhook Connection Exception: $e');
      return AuthResult(
        isSuccess: false,
        message: 'Failed to contact Power Automate Webhook. Check connection and URL.',
        isMock: false,
      );
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String message;
  final bool isMock;
  final bool isPending;

  AuthResult({
    required this.isSuccess,
    required this.message,
    required this.isMock,
    this.isPending = false,
  });
}
