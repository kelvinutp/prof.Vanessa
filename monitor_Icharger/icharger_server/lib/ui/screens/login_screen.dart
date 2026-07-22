import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _webhookController = TextEditingController();
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _webhookController.text = context.read<AuthProvider>().webhookUrl;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _webhookController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // Server Midnight Navy
              Color(0xFF1B263B), // Deep Blue Grey
              Color(0xFF415A77), // Slate Blue
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glowing mesh circles
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.12),
                      blurRadius: 120,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.08),
                      blurRadius: 150,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            // Glassmorphic Card content
            SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: authProvider.currentStatus == 'pending'
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: _buildLoginForm(authProvider),
                    secondChild: _buildPendingApprovalScreen(authProvider),
                  ),
                ),
              ),
            ),

            // Webhook Settings Action
            if (authProvider.currentStatus != 'pending')
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
                  onPressed: () => setState(() => _showSettings = !_showSettings),
                  tooltip: 'Power Automate Webhook Settings',
                ),
              ),

            // Settings Modal configuration drawer
            if (_showSettings) _buildSettingsDrawer(authProvider),
          ],
        ),
      ),
    );
  }

  // LOGIN FORM
  Widget _buildLoginForm(AuthProvider authProvider) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMicrosoftLogo(),
              const SizedBox(width: 12),
              const Text(
                'Office 365',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            'iCharger Multi-Battery Logger (Server)',
            style: TextStyle(
              color: Colors.blue.shade200,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 36),

          // Action Info
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sign in with your administrator email',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),

          // Input Email
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              prefixIcon: const Icon(Icons.admin_panel_settings, color: Colors.white60),
              hintText: 'admin@company.onmicrosoft.com',
              hintStyle: const TextStyle(color: Colors.white30),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Request Access Button
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF0078d4), Color(0xFF005a9e)], // Microsoft Blue
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0078d4).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  authProvider.submitLoginRequest(_emailController.text);
                },
                child: const Center(
                  child: Text(
                    'Request Server Authorization',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // Settings Info Tag
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                authProvider.webhookUrl.isEmpty ? Icons.code : Icons.verified,
                size: 14,
                color: authProvider.webhookUrl.isEmpty ? Colors.cyanAccent : Colors.greenAccent,
              ),
              const SizedBox(width: 6),
              Text(
                authProvider.webhookUrl.isEmpty
                    ? 'Simulated Server Demo Mode (No Webhook)'
                    : 'Live Power Automate Security Active',
                style: TextStyle(
                  color: authProvider.webhookUrl.isEmpty ? Colors.cyan.shade200 : Colors.green.shade200,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          // Error Alerts
          if (authProvider.currentStatus == 'rejected' || authProvider.currentStatus == 'error')
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authProvider.statusMessage ?? 'Failed to authenticate server.',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // PENDING APPROVAL SCREEN
  Widget _buildPendingApprovalScreen(AuthProvider authProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 440,
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 25,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              const _PulsingRingWidget(),
              const SizedBox(height: 24),
              const Text(
                'Server Approval Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Awaiting server deployment approval from your Office 365 system administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Visual Step Chart
              _buildConnectionWorkflowMap(authProvider.isMock),
              const SizedBox(height: 28),

              // Cancel button
              TextButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: Colors.white54),
                label: const Text('Cancel Request', style: TextStyle(color: Colors.white70)),
                onPressed: authProvider.resetStatus,
              ),
            ],
          ),
        ),

        // Floating Simulated Console
        if (authProvider.isMock) ...[
          const SizedBox(height: 20),
          _buildSimulatorConsole(authProvider),
        ]
      ],
    );
  }

  // CONNECTION WORKFLOW VISUAL MAP
  Widget _buildConnectionWorkflowMap(bool isMock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SERVER SECURITY DISPATCH TRACKER',
          style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _workflowStep(Icons.computer, '1. Dispatch', true),
            _workflowArrow(true),
            _workflowStep(Icons.sync_alt, isMock ? '2. Power Automate (Sim)' : '2. Power Automate', true),
            _workflowArrow(true),
            _workflowStep(Icons.gavel, '3. Approval', false),
          ],
        ),
      ],
    );
  }

  Widget _workflowStep(IconData icon, String label, bool active) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.blueAccent.withOpacity(0.15) : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: active ? Colors.blueAccent : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: active ? Colors.blueAccent : Colors.white38, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _workflowArrow(bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Icon(
        Icons.double_arrow,
        color: active ? Colors.blueAccent.withOpacity(0.5) : Colors.white12,
        size: 16,
      ),
    );
  }

  // SIMULATOR CONSOLE DESIGN
  Widget _buildSimulatorConsole(AuthProvider authProvider) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_outlined, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'LOCAL SIMULATION CONSOLE',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SERVER',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Act as the Administrator to test approval outcome and routing directly in the server application:',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve Deployment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: authProvider.simulateApproval,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.highlight_off, size: 16),
                  label: const Text('Reject Deployment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: authProvider.simulateRejection,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // WEBHOOK CONFIGURATION DRAWER
  Widget _buildSettingsDrawer(AuthProvider authProvider) {
    return Stack(
      children: [
        // Backdrop overlay
        GestureDetector(
          onTap: () => setState(() => _showSettings = false),
          child: Container(
            color: Colors.black.withOpacity(0.55),
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Central Dialogue Dialog
        Center(
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B), // Dark Navy Blue
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.webhook, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text(
                          'Server Security Webhook',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => setState(() => _showSettings = false),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Text(
                  'Power Automate Webhook URL',
                  style: TextStyle(color: Colors.blue.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _webhookController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black12,
                    hintText: 'https://prod-XX.westus.logic.azure.com:443/workflows/...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Note: If left blank, the server app runs in local simulation demo mode, letting you mock approval transitions during local development.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      onPressed: () => setState(() => _showSettings = false),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await authProvider.saveWebhookUrl(_webhookController.text);
                        setState(() => _showSettings = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Webhook configuration updated!')),
                          );
                        }
                      },
                      child: const Text('Save Webhook'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Microsoft Quad Logo Helper
  Widget _buildMicrosoftLogo() {
    return SizedBox(
      width: 22,
      height: 22,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(color: const Color(0xFFF25022)), // Red
          Container(color: const Color(0xFF7FBA00)), // Green
          Container(color: const Color(0xFF00A4EF)), // Blue
          Container(color: const Color(0xFFFFB900)), // Yellow
        ],
      ),
    );
  }
}

// PULSING GRAPHIC WIDGET
class _PulsingRingWidget extends StatefulWidget {
  const _PulsingRingWidget();

  @override
  State<_PulsingRingWidget> createState() => _PulsingRingWidgetState();
}

class _PulsingRingWidgetState extends State<_PulsingRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outermost circle
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(1.0 - _controller.value),
                  width: 2,
                ),
              ),
              transform: Matrix4.identity()..scale(1.0 + (_controller.value * 0.3)),
            ),
            // Middle circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.05),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
            ),
            // Inner icon center
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue,
              child: Icon(Icons.dns, color: Colors.white, size: 28),
            ),
          ],
        );
      },
    );
  }
}
