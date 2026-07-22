import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/services/logger_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _authenticatedEmail;
  String _currentStatus = 'idle'; // idle, pending, approved, rejected, error
  String? _statusMessage;
  String _webhookUrl = '';
  bool _isMock = false;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get authenticatedEmail => _authenticatedEmail;
  String get currentStatus => _currentStatus;
  String? get statusMessage => _statusMessage;
  String get webhookUrl => _webhookUrl;
  bool get isMock => _isMock;

  AuthProvider() {
    init();
  }

  // Initialize and load saved sessions
  Future<void> init() async {
    logger.log('Server AuthProvider: Initializing session state...');
    final prefs = await SharedPreferences.getInstance();
    
    _webhookUrl = prefs.getString('pa_webhook_url') ?? '';
    _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    _authenticatedEmail = prefs.getString('auth_email');
    
    if (_isAuthenticated) {
      _currentStatus = 'approved';
      logger.log('Server AuthProvider: Restored authorized session for $_authenticatedEmail');
    } else {
      logger.log('Server AuthProvider: No active session. Redirecting to login.');
    }
    notifyListeners();
  }

  // Request Access Approval
  Future<void> submitLoginRequest(String email) async {
    if (email.trim().isEmpty) {
      _currentStatus = 'error';
      _statusMessage = 'Please enter a valid Office 365 email.';
      notifyListeners();
      return;
    }

    _currentStatus = 'pending';
    _statusMessage = 'Sending authorization request...';
    _isMock = _webhookUrl.trim().isEmpty;
    notifyListeners();

    logger.log('Server AuthProvider: Login requested for $email (Mock Mode: $_isMock)');

    if (_isMock) {
      // Stay in pending status until the simulated admin console approves it locally
      _statusMessage = 'Awaiting mock approval from administrator...';
      _authenticatedEmail = email;
      notifyListeners();
      return;
    }

    // Call live Power Automate Webhook
    try {
      logger.log('Server AuthProvider: Sending HTTP POST request to $_webhookUrl');
      final response = await http.post(
        Uri.parse(_webhookUrl.trim()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'deviceInfo': 'iCharger Logger Server',
          'requestTime': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(minutes: 5));

      logger.log('Server AuthProvider: Received status ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final status = data['status']?.toString().toLowerCase();
        
        if (status == 'approved') {
          await _persistLogin(email);
          _currentStatus = 'approved';
          _statusMessage = 'Access granted by Administrator.';
        } else {
          _isAuthenticated = false;
          _currentStatus = 'rejected';
          _statusMessage = data['message'] ?? 'Access request was rejected by the Administrator.';
        }
      } else {
        _isAuthenticated = false;
        _currentStatus = 'error';
        _statusMessage = 'Webhook returned status code: ${response.statusCode}';
      }
    } catch (e) {
      logger.log('Server AuthProvider Webhook Error: $e');
      _isAuthenticated = false;
      _currentStatus = 'error';
      _statusMessage = 'Failed to connect to Power Automate. Verify Webhook URL or network connection.';
    }
    notifyListeners();
  }

  // Simulator helper triggers
  Future<void> simulateApproval() async {
    if (!_isMock || _authenticatedEmail == null) return;
    
    logger.log('Server AuthProvider: Simulated Admin Approval action triggered.');
    _statusMessage = 'Simulated Approval SUCCESS!';
    await _persistLogin(_authenticatedEmail!);
    _currentStatus = 'approved';
    notifyListeners();
  }

  Future<void> simulateRejection() async {
    if (!_isMock) return;
    
    logger.log('Server AuthProvider: Simulated Admin Rejection action triggered.');
    _isAuthenticated = false;
    _currentStatus = 'rejected';
    _statusMessage = 'Simulated access request rejected by administrator.';
    notifyListeners();
  }

  void resetStatus() {
    _currentStatus = 'idle';
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> _persistLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_authenticated', true);
    await prefs.setString('auth_email', email);
    _isAuthenticated = true;
    _authenticatedEmail = email;
  }

  Future<void> saveWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pa_webhook_url', url.trim());
    _webhookUrl = url.trim();
    logger.log('Server AuthProvider: Webhook URL updated to $_webhookUrl');
    notifyListeners();
  }

  Future<void> logout() async {
    logger.log('Server AuthProvider: Operator logging out.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_authenticated');
    await prefs.remove('auth_email');
    
    _isAuthenticated = false;
    _authenticatedEmail = null;
    _currentStatus = 'idle';
    _statusMessage = null;
    notifyListeners();
  }
}
