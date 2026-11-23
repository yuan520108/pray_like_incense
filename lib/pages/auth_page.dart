import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  final AuthService authService;
  final Future<void> Function() onAuthenticated;

  const AuthPage({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _cream = Color(0xFFFFF9EC);
  static const _buttonGold = Color(0xFFFFE4A8);
  static const _countdownSeconds = 90;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();
  String? _registrationToken;
  String? _errorMessage;
  bool _codeSent = false;
  bool _termsAgreed = false;
  bool _isBusy = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool get _isRegistering => _registrationToken != null;

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    await _runRequest(() async {
      await widget.authService.requestOtp(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _errorMessage = null;
      });
      _startResendCountdown();
    });
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _countdownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(
        () => _errorMessage = 'Please enter the 6-digit verification code.',
      );
      return;
    }
    await _runRequest(() async {
      final result = await widget.authService.verifyOtp(
        email: _emailController.text.trim(),
        code: code,
      );
      if (result['status'] == 'registration') {
        final token = result['registrationToken'];
        if (token is! String || token.isEmpty) {
          throw const FormatException(
            'The registration response is missing registrationToken.',
          );
        }
        if (!mounted) return;
        setState(() {
          _registrationToken = token;
          final hint = result['displayNameHint'];
          if (hint is String) _displayNameController.text = hint;
          _errorMessage = null;
        });
        return;
      }
      if (result['status'] != 'authenticated') {
        throw const FormatException('Unexpected sign-in status.');
      }
      await widget.onAuthenticated();
    });
  }

  Future<void> _register() async {
    final displayName = _displayNameController.text.trim();
    final handle = _handleController.text.trim();
    if (handle.length < 3 || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(handle)) {
      setState(
        () => _errorMessage =
            'Username must be 3–30 characters using letters, numbers, underscores, or hyphens.',
      );
      return;
    }
    if (displayName.length < 2) {
      setState(
        () => _errorMessage = 'Display name must be at least 2 characters.',
      );
      return;
    }
    if (!_termsAgreed) {
      setState(() => _errorMessage = 'Please agree to the Terms of Use.');
      return;
    }
    final token = _registrationToken;
    if (token == null) {
      setState(
        () => _errorMessage =
            'Your registration has expired. Please verify your email again.',
      );
      return;
    }
    await _runRequest(() async {
      await widget.authService.register(
        displayName: displayName,
        handle: handle,
        registrationToken: token,
        termsAgreed: true,
      );
      await widget.onAuthenticated();
    });
  }

  Future<void> _runRequest(Future<void> Function() request) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await request();
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _returnToLogin() {
    _resendTimer?.cancel();
    setState(() {
      _registrationToken = null;
      _codeSent = false;
      _codeController.clear();
      _termsAgreed = false;
      _resendSeconds = 0;
      _errorMessage = null;
    });
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFF8A867D),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: _cream,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _buttonGold, width: 2),
    ),
  );

  Widget _actionButton({
    required String label,
    required VoidCallback? onPressed,
    bool emphasized = false,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: emphasized ? _buttonGold : Colors.white,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: const Color(0xFFE5E1D8),
          disabledForegroundColor: Colors.black45,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        child: _isBusy
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, maxLines: 1, softWrap: false),
      ),
    );
  }

  Widget _socialLoginButton(String provider, String assetPath) => Semantics(
    button: true,
    enabled: false,
    label: '$provider sign-in (not available yet)',
    child: SizedBox.square(
      dimension: 50,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white,
          elevation: 2,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: Image.asset(
          assetPath,
          width: 22,
          height: 22,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );

  Widget _socialLoginButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _socialLoginButton('Apple', 'assets/icons/apple-icon.png'),
      const SizedBox(width: 16),
      _socialLoginButton('Facebook', 'assets/icons/facebook-icon.png'),
      const SizedBox(width: 16),
      _socialLoginButton('Google', 'assets/icons/google-icon.png'),
    ],
  );

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _displayNameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegistering = _isRegistering;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF142049), Color(0xFF848484), Color(0xFFFFDF9E)],
            stops: [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isRegistering ? 320 : 280,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/pray-logo.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!isRegistering) ...[
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: TextField(
                                    controller: _emailController,
                                    enabled: !_codeSent && !_isBusy,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.email],
                                    onChanged: (_) => setState(() {
                                      _errorMessage = null;
                                    }),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: _inputDecoration(
                                      'Email address',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 78,
                                child: _actionButton(
                                  label: _resendSeconds > 0
                                      ? '${_resendSeconds}s'
                                      : _codeSent
                                      ? 'Resend'
                                      : 'Verify',
                                  onPressed:
                                      _isBusy ||
                                          _resendSeconds > 0 ||
                                          _emailController.text.trim().isEmpty
                                      ? null
                                      : _requestOtp,
                                  emphasized: _emailController.text.isNotEmpty,
                                ),
                              ),
                            ],
                          ),
                          if (_codeSent) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 48,
                              child: TextField(
                                controller: _codeController,
                                enabled: !_isBusy,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: _inputDecoration('6-digit code'),
                              ),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _message(_errorMessage!, isError: true),
                          ],
                          const SizedBox(height: 14),
                          _actionButton(
                            label: 'Confirm',
                            onPressed: _isBusy || !_codeSent
                                ? null
                                : _verifyOtp,
                            emphasized: _codeController.text.length == 6,
                          ),
                          const SizedBox(height: 16),
                          _socialLoginButtons(),
                        ] else ...[
                          SizedBox(
                            height: 48,
                            child: TextField(
                              controller: _handleController,
                              enabled: !_isBusy,
                              maxLength: 30,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9_-]'),
                                ),
                                LengthLimitingTextInputFormatter(30),
                              ],
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                'Username (3–30 characters)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: TextField(
                              controller: _displayNameController,
                              enabled: !_isBusy,
                              maxLength: 50,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(50),
                              ],
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(fontSize: 13),
                              decoration: _inputDecoration(
                                'Display name (2–50 characters)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Checkbox(
                                  value: _termsAgreed,
                                  activeColor: const Color(0xFF76502D),
                                  onChanged: _isBusy
                                      ? null
                                      : (value) => setState(
                                          () => _termsAgreed = value ?? false,
                                        ),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'I agree to the Terms of Use',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            _message(_errorMessage!, isError: true),
                          ],
                          const SizedBox(height: 10),
                          _actionButton(
                            label: 'Create account',
                            onPressed: _isBusy ? null : _register,
                            emphasized: _termsAgreed,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isBusy ? null : _returnToLogin,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: const Text('Back to sign in'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String message, {required bool isError}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: isError
          ? const Color(0xFFFFEEEE).withValues(alpha: 0.94)
          : const Color(0xFFE9F7EC).withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isError ? const Color(0xFF9D2525) : const Color(0xFF276437),
        fontSize: 12,
      ),
    ),
  );
}
