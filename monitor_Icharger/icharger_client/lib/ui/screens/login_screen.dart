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
              Color(0xFF0F2027), // Deep Space Blue
              Color(0xFF203A43), // Midnight Teal
              Color(0xFF2C5364), // Slate Teal
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient glow effect
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.15),
                      blurRadius: 120,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.15),
                      blurRadius: 150,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            // Main glassmorphic container
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

            // Top-right settings action
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

            // Drawer-like settings overlay
            if (_showSettings) _buildSettingsDrawer(authProvider),
          ],
        ),
      ),
    );
  }

  // LOGIN SCREEN FORM
  Widget _buildLoginForm(AuthProvider authProvider) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo & Branding
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            'iCharger Multi-Battery Remote',
            style: TextStyle(
              color: Colors.teal.shade200,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 36),

          // User info label
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sign in with your organizational email',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),

          // Email Input field
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white60),
              hintText: 'user@company.onmicrosoft.com',
              hintStyle: const TextStyle(color: Colors.white30),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF0078d4), Color(0xFF005a9e)], // Microsoft Blue Gradient
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0078d4).withOpacity(0.4),
                  blurRadius: 12,
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
                    'Request Access Approval',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // Custom Mode Label helper
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                authProvider.webhookUrl.isEmpty ? Icons.offline_bolt : Icons.cloud_done,
                size: 14,
                color: authProvider.webhookUrl.isEmpty ? Colors.amberAccent : Colors.greenAccent,
              ),
              const SizedBox(width: 6),
              Text(
                authProvider.webhookUrl.isEmpty
                    ? 'Operating in Simulated Demo Mode (No Webhook Set)'
                    : 'Live Power Automate Mode Enabled',
                style: TextStyle(
                  color: authProvider.webhookUrl.isEmpty ? Colors.amber.shade200 : Colors.green.shade200,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          // Error / Status Message
          if (authProvider.currentStatus == 'rejected' || authProvider.currentStatus == 'error')
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authProvider.statusMessage ?? 'An error occurred during authentication.',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
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
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              // Pulser
              const _PulsingRingWidget(),
              const SizedBox(height: 24),
              const Text(
                'Approval Request Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent an authorization request to the administrator. Please check your Outlook / Teams approvals.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Visual Connection Map
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

        // Interactive Simulation Panel
        if (authProvider.isMock) ...[
          const SizedBox(height: 20),
          _buildSimulatorConsole(authProvider),
        ]
      ],
    );
  }

  // WORKFLOW MAP DESIGN
  Widget _buildConnectionWorkflowMap(bool isMock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCESS WORKFLOW TRACKER',
          style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _workflowStep(Icons.email, '1. Request', true),
            _workflowArrow(true),
            _workflowStep(Icons.sync_alt, isMock ? '2. Power Automate (Sim)' : '2. Power Automate', true),
            _workflowArrow(true),
            _workflowStep(Icons.verified_user, '3. Approval', false),
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
            color: active ? Colors.tealAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: active ? Colors.tealAccent : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: active ? Colors.tealAccent : Colors.white38, size: 20),
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
        color: active ? Colors.tealAccent.withOpacity(0.5) : Colors.white12,
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
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.tealAccent.withOpacity(0.05),
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
              const Icon(Icons.developer_mode, color: Colors.tealAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'LOCAL SIMULATION CONSOLE',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Act as the Administrator to test approval outcome and routing directly in the client application:',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve Access'),
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
                  label: const Text('Reject Access'),
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

  // SETTINGS DRAWER OVERLAY
  Widget _buildSettingsDrawer(AuthProvider authProvider) {
    return Stack(
      children: [
        // Backdrop tap dismiss
        GestureDetector(
          onTap: () => setState(() => _showSettings = false),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Settings Dialog Panel
        Center(
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A38), // Solid Dark Slate
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
                        Icon(Icons.webhook, color: Colors.tealAccent),
                        SizedBox(width: 8),
                        Text(
                          'Webhook Configuration',
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
                  style: TextStyle(color: Colors.teal.shade200, fontSize: 12, fontWeight: FontWeight.w600),
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
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Note: If this URL is left blank, the app will run in local simulation demo mode, letting you mock approval state changes directly.',
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
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await authProvider.saveWebhookUrl(_webhookController.text);
                        setState(() => _showSettings = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings saved successfully!')),
                          );
                        }
                      },
                      child: const Text('Save Settings'),
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

  // Microsoft Logo Graphic Helper
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
          Container(color: const Color(0xFFF25022)), // Red-Orange
          Container(color: const Color(0xFF7FBA00)), // Green
          Container(color: const Color(0xFF00A4EF)), // Blue
          Container(color: const Color(0xFFFFB900)), // Yellow
        ],
      ),
    );
  }
}

// PULSING RING GRAPHIC WIDGET
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
            // Outermost ring
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(1.0 - _controller.value),
                  width: 2,
                ),
              ),
              transform: Matrix4.identity()..scale(1.0 + (_controller.value * 0.3)),
            ),
            // Middle ring
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withOpacity(0.05),
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
            ),
            // Inner icon
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.teal,
              child: Icon(Icons.security, color: Colors.white, size: 28),
            ),
          ],
        );
      },
    );
  }
}
