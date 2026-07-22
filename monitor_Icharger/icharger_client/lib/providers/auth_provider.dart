import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/auth_service.dart';
import '../core/services/logger_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
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

  // Load persisted session and settings
  Future<void> init() async {
    logger.log('AuthProvider: Initializing session state...');
    final prefs = await SharedPreferences.getInstance();
    
    _webhookUrl = prefs.getString('pa_webhook_url') ?? '';
    _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    _authenticatedEmail = prefs.getString('auth_email');
    
    if (_isAuthenticated) {
      _currentStatus = 'approved';
      logger.log('AuthProvider: Restored authenticated session for $_authenticatedEmail');
    } else {
      logger.log('AuthProvider: No active session found. Redirecting to login.');
    }
    notifyListeners();
  }

  // Submit request for login
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

    logger.log('AuthProvider: Login requested for $email (Mock Mode: $_isMock)');

    // Call the Auth Service
    final result = await _authService.requestAccess(
      email: email,
      webhookUrl: _webhookUrl,
    );

    if (_isMock) {
      // In Mock Mode, the status stays 'pending' until the user interacts with the mock simulator console
      _statusMessage = 'Awaiting mock approval from administrator...';
      _authenticatedEmail = email;
      notifyListeners();
      return;
    }

    // Live Webhook Response path
    if (result.isSuccess) {
      await _persistLogin(email);
      _currentStatus = 'approved';
      _statusMessage = result.message;
    } else {
      _isAuthenticated = false;
      _currentStatus = 'rejected';
      _statusMessage = result.message;
    }
    notifyListeners();
  }

  // Actions triggered by the Mock Admin approval console on-screen
  Future<void> simulateApproval() async {
    if (!_isMock || _authenticatedEmail == null) return;
    
    logger.log('AuthProvider: Simulated Admin Approval action triggered.');
    _statusMessage = 'Simulated Approval SUCCESS!';
    await _persistLogin(_authenticatedEmail!);
    _currentStatus = 'approved';
    notifyListeners();
  }

  Future<void> simulateRejection() async {
    if (!_isMock) return;
    
    logger.log('AuthProvider: Simulated Admin Rejection action triggered.');
    _isAuthenticated = false;
    _currentStatus = 'rejected';
    _statusMessage = 'Simulated access request rejected by administrator.';
    notifyListeners();
  }

  // Reset to input state on error or rejection
  void resetStatus() {
    _currentStatus = 'idle';
    _statusMessage = null;
    notifyListeners();
  }

  // Persist session to disk
  Future<void> _persistLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_authenticated', true);
    await prefs.setString('auth_email', email);
    _isAuthenticated = true;
    _authenticatedEmail = email;
  }

  // Configure and persist Power Automate Webhook URL
  Future<void> saveWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pa_webhook_url', url.trim());
    _webhookUrl = url.trim();
    logger.log('AuthProvider: Webhook URL updated to $_webhookUrl');
    notifyListeners();
  }

  // Clear session (Logout)
  Future<void> logout() async {
    logger.log('AuthProvider: User logging out.');
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
