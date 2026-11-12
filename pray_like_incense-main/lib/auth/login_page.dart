import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/app_theme.dart';
import '../home/home_page.dart';
import 'registration_flow.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  bool _sent = false, _loading = false;
  int _seconds = 0;
  Timer? _timer;

  String _error = '', _message = '';

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _countdown() {
    _timer?.cancel();

    setState(() {
      _seconds = 90;
      _sent = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();

    setState(() {
      _error = '';
      _message = '';
    });

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _error = 'Please enter a valid email address.';
      });
      return;
    }

    if (_loading || _seconds > 0) return;

    setState(() => _loading = true);

    try {
      await authService.requestOtp(email);

      if (!mounted) return;

      _countdown();

      setState(() {
        _message = 'Verification code sent. Please check your email.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirm() async {
    final email = _email.text.trim();
    final code = _code.text.trim();

    setState(() {
      _error = '';
      _message = '';
    });

    if (!_sent) {
      setState(() {
        _error = 'Please request a verification code first.';
      });
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = 'Please enter the 6-digit verification code.';
      });
      return;
    }

    if (_loading) return;

    setState(() => _loading = true);

    try {
      final result = await authService.verifyOtp(email: email, code: code);

      final status = (findValue(result, 'status') ?? '')
          .toString()
          .toLowerCase();

      final token = findValue(result, 'registrationToken');

      if (!mounted) return;

      if (status == 'registration' || (token is String && token.isNotEmpty)) {
        if (token is! String || token.isEmpty) {
          throw Exception('Registration token was not returned by the server.');
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RegistrationPage(email: email, registrationToken: token),
          ),
        );
      } else if (status == 'authenticated') {
        final user = await authService.getMe();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: user)),
        );
      } else {
        throw Exception('Unable to identify the OTP response: $result');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _googleLogin() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = '';
      _message = '';
    });

    try {
      await authService.startGoogleLogin();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = cleanError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    bool email = false,
    int max = 100,
  }) => SizedBox(
    height: 48,
    child: TextField(
      controller: c,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.number,
      maxLength: max,
      autocorrect: false,
      textAlign: email ? TextAlign.start : TextAlign.center,
      style: const TextStyle(fontSize: 13, color: Colors.black),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: cream,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navy),
        ),
      ),
      onChanged: (_) {
        setState(() {
          _error = '';
          _message = '';
        });
      },
    ),
  );

  Widget _button(
    String label,
    VoidCallback? action, {
    bool creamButton = false,
  }) => SizedBox(
    height: 48,
    child: ElevatedButton(
      onPressed: action,
      style: ElevatedButton.styleFrom(
        backgroundColor: creamButton ? cream : Colors.white,
        foregroundColor: navy,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: prayerGradient(),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/pray-logo.png',
                      width: 120,
                      height: 120,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.favorite,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _field(_email, 'EMAIL', email: true)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: width < 360 ? 65 : 75,
                          child: _button(
                            _seconds > 0
                                ? '${_seconds}s'
                                : (_sent ? 'RESEND' : 'VERIFY'),
                            _loading || _seconds > 0 ? null : _sendCode,
                          ),
                        ),
                      ],
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 14),
                      _field(_code, '123456', max: 6),
                    ],
                    if (_error.isNotEmpty) _notice(_error, true),
                    if (_message.isNotEmpty) _notice(_message, false),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _button(
                        _loading ? 'PLEASE WAIT...' : 'CONFIRM',
                        _loading ? null : _confirm,
                        creamButton: _code.text.length == 6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _social('assets/icons/apple-icon.png', 'Apple'),
                        const SizedBox(width: 16),
                        _social('assets/icons/facebook-icon.png', 'Facebook'),
                        const SizedBox(width: 16),
                        _social('assets/icons/google-icon.png', 'Google'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(String text, bool error) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFEBCBCB) : const Color(0xFFD4EDDA),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: error ? Colors.red.shade900 : Colors.green.shade900,
        fontSize: 12,
      ),
    ),
  );

  Widget _social(String path, String provider) => SizedBox(
    width: 48,
    height: 48,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: provider == 'Google'
            ? _googleLogin
            : () => setState(() {
                _error = '$provider sign-in is not connected yet.';
              }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
          ),
        ),
      ),
    ),
  );
}

String cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

// ==================== 註冊流程 ====================
