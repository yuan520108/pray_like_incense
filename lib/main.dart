import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

late final AuthService authService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  authService = AuthService(apiClient);
  runApp(const PrayLikeApp());
}

class PrayLikeApp extends StatelessWidget {
  const PrayLikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pray like incense',
        theme: ThemeData(
          useMaterial3: false,
          fontFamily: 'Arial',
        ),
        home: const AuthGate(),
      );
}

// ==================== 啟動時檢查登入狀態 ====================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<dynamic> _loginCheck;

  @override
  void initState() {
    super.initState();
    _loginCheck = _checkLogin();
  }

  Future<dynamic> _checkLogin() async {
    try {
      return await authService.getMe();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _loginCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data;

        if (data is Map) {
          return HomePage(
            user: Map<String, dynamic>.from(data),
          );
        }

        return const LoginPage();
      },
    );
  }
}

// ==================== 共用資料處理 ====================

dynamic findValue(Map<String, dynamic> map, String key) {
  if (map.containsKey(key)) return map[key];

  for (final nestedKey in ['data', 'item']) {
    final nested = map[nestedKey];

    if (nested is Map) {
      final result = findValue(
        Map<String, dynamic>.from(nested),
        key,
      );

      if (result != null) return result;
    }
  }

  return null;
}

const Color navy = Color(0xFF142049);
const Color cream = Color(0xFFFFF9EC);
const Color gold = Color(0xFFFFDF9E);
const Color gray = Color(0xFF848484);

BoxDecoration prayerGradient() => const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [navy, gray, gold],
      ),
    );

// ==================== 登入頁面 ====================

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

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
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
      },
    );
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();

    setState(() {
      _error = '';
      _message = '';
    });

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(email)) {
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
        _message =
            'Verification code sent. Please check your email.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _cleanError(e));
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
      final result = await authService.verifyOtp(
        email: email,
        code: code,
      );

      final status =
          (findValue(result, 'status') ?? '')
              .toString()
              .toLowerCase();

      final token = findValue(result, 'registrationToken');

      if (!mounted) return;

      if (status == 'registration' ||
          (token is String && token.isNotEmpty)) {
        if (token is! String || token.isEmpty) {
          throw Exception(
            'Registration token was not returned by the server.',
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationPage(
              email: email,
              registrationToken: token,
            ),
          ),
        );
      } else if (status == 'authenticated') {
        final user = await authService.getMe();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(user: user),
          ),
        );
      } else {
        throw Exception(
          'Unable to identify the OTP response: $result',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _cleanError(e));
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
        _error = _cleanError(e);
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
  }) =>
      SizedBox(
        height: 48,
        child: TextField(
          controller: c,
          keyboardType: email
              ? TextInputType.emailAddress
              : TextInputType.number,
          maxLength: max,
          autocorrect: false,
          textAlign:
              email ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
          ),
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
  }) =>
      SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: action,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                creamButton ? cream : Colors.white,
            foregroundColor: navy,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
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
                constraints: const BoxConstraints(
                  maxWidth: 360,
                ),
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
                        Expanded(
                          child: _field(
                            _email,
                            'EMAIL',
                            email: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: width < 360 ? 65 : 75,
                          child: _button(
                            _seconds > 0
                                ? '${_seconds}s'
                                : (_sent ? 'RESEND' : 'VERIFY'),
                            _loading || _seconds > 0
                                ? null
                                : _sendCode,
                          ),
                        ),
                      ],
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 14),
                      _field(_code, '123456', max: 6),
                    ],
                    if (_error.isNotEmpty)
                      _notice(_error, true),
                    if (_message.isNotEmpty)
                      _notice(_message, false),
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
                        _social(
                          'assets/icons/apple-icon.png',
                          'Apple',
                        ),
                        const SizedBox(width: 16),
                        _social(
                          'assets/icons/facebook-icon.png',
                          'Facebook',
                        ),
                        const SizedBox(width: 16),
                        _social(
                          'assets/icons/google-icon.png',
                          'Google',
                        ),
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
          color: error
              ? const Color(0xFFEBCBCB)
              : const Color(0xFFD4EDDA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: error
                ? Colors.red.shade900
                : Colors.green.shade900,
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
                      _error =
                          '$provider sign-in is not connected yet.';
                    }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.image_not_supported),
              ),
            ),
          ),
        ),
      );
}

String _cleanError(Object e) =>
    e.toString().replaceFirst('Exception: ', '');

// ==================== 註冊流程 ====================

class RegistrationPage extends StatefulWidget {
  final String email;
  final String registrationToken;

  const RegistrationPage({
    super.key,
    required this.email,
    required this.registrationToken,
  });

  @override
  State<RegistrationPage> createState() =>
      _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _name = TextEditingController();
  final _handle = TextEditingController();

  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _name.text.trim();
    final handle = _handle.text.trim();

    setState(() => _error = '');

    if (!RegExp(r'^[a-zA-Z0-9_-]{3,30}$')
        .hasMatch(handle)) {
      setState(() {
        _error =
            'User ID must be 3–30 characters: letters, numbers, _ or -.';
      });
      return;
    }

    if (name.length < 2 || name.length > 50) {
      setState(() {
        _error = 'Name must be between 2 and 50 characters.';
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermsPage(
          onAgree: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransitionPage(
                  onComplete: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TribeInfoPage(
                          onContinue: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TribeSelectionPage(
                                  onFinish: (tribe) =>
                                      _finishRegistration(
                                    name,
                                    handle,
                                    tribe,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _finishRegistration(
    String name,
    String handle,
    Tribe? tribe,
  ) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      await authService.register(
        displayName: name,
        handle: handle,
        registrationToken: widget.registrationToken,
        termsAgreed: true,
        tribeCode: tribe?.code,
      );

      final user = await authService.getMe();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(user: user),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = _cleanError(e));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error)),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: prayerGradient(),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/pray-logo.png',
                        height: 105,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'CREATE YOUR ACCOUNT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cream,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Begin your spiritual journey.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 26),
                      _registrationField(
                        _handle,
                        'User ID',
                        '3–30 characters',
                      ),
                      const SizedBox(height: 14),
                      _registrationField(
                        _name,
                        'Name',
                        'Enter your name',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: widget.email,
                        ),
                        decoration: _inputDecoration('Email'),
                      ),
                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: Color(0xFF7A1010),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _busy ? null : _continue,
                        style: _creamButton(),
                        child: const Text('CONTINUE'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'You will review the privacy terms before completing registration.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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

InputDecoration _inputDecoration(
  String label, {
  String? hint,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cream,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
    );

Widget _registrationField(
  TextEditingController controller,
  String label,
  String hint,
) =>
    TextField(
      controller: controller,
      decoration: _inputDecoration(label, hint: hint),
    );

ButtonStyle _creamButton() => ElevatedButton.styleFrom(
      backgroundColor: cream,
      foregroundColor: navy,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
    );

// ==================== 隱私條款 ====================

class TermsPage extends StatefulWidget {
  final VoidCallback onAgree;

  const TermsPage({
    super.key,
    required this.onAgree,
  });

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _checked = false;

  final List<Map<String, String>> _sections = const [
    {
      'title': '1. Information We Collect',
      'body':
          'We may collect account details such as your name, user ID and email address, along with information you choose to provide while using the service.',
    },
    {
      'title': '2. How We Use Information',
      'body':
          'Information is used to create and secure your account, provide app features, respond to requests and improve the service.',
    },
    {
      'title': '3. Account and Authentication',
      'body':
          'Your email verification code is used to verify access. Keep your account credentials and verification codes private.',
    },
    {
      'title': '4. User Content',
      'body':
          'You are responsible for information and content you submit. Do not submit information that you are not permitted to share.',
    },
    {
      'title': '5. Data Sharing',
      'body':
          'We do not sell your personal information. Information may be processed by service providers or disclosed when required by applicable law.',
    },
    {
      'title': '6. Data Security',
      'body':
          'Reasonable safeguards are used to protect information. No internet transmission or storage method can be guaranteed completely secure.',
    },
    {
      'title': '7. Data Retention and Deletion',
      'body':
          'Information is retained as needed to provide the service, meet legal obligations and resolve disputes. You may contact us to request assistance.',
    },
    {
      'title': '8. Your Privacy Rights',
      'body':
          'Subject to applicable law, including Taiwan’s Personal Data Protection Act where applicable, you may request access, correction, cessation of use or deletion of personal data.',
    },
    {
      'title': '9. Contact and Updates',
      'body':
          'We may update these terms when the service or legal requirements change. For privacy questions, contact info@yalinelena.church.',
    },
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: prayerGradient(),
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Text(
                    'PRIVACY & TERMS',
                    style: TextStyle(
                      color: cream,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: Text(
                    'Please review each section before continuing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12,
                    ),
                    children: _sections
                        .map(
                          (s) => Card(
                            color: cream,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              title: Text(
                                s['title']!,
                                style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                18,
                              ),
                              children: [
                                Text(
                                  s['body']!,
                                  style: const TextStyle(
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xCC142049),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    18,
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _checked,
                        onChanged: (v) => setState(
                          () => _checked = v ?? false,
                        ),
                        activeColor: gold,
                        checkColor: navy,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'I have read and agree to the Privacy Policy and Terms.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        controlAffinity:
                            ListTileControlAffinity.leading,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _checked ? widget.onAgree : null,
                          style: _creamButton(),
                          child: const Text('CONTINUE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ==================== 過場頁面 ====================

class TransitionPage extends StatefulWidget {
  final VoidCallback onComplete;

  const TransitionPage({
    super.key,
    required this.onComplete,
  });

  @override
  State<TransitionPage> createState() =>
      _TransitionPageState();
}

class _TransitionPageState extends State<TransitionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _controller.forward();
    });

    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2C3E50),
                Color(0xFF3A6073),
                Color(0xFFC9A961),
              ],
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 1,
                end: 0,
              ).animate(_controller),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Image.asset(
                  'assets/images/transition-prayer.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.volunteer_activism,
                    size: 150,
                    color: cream,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ==================== 12 個支派資料 ====================

class Tribe {
  final String code;
  final String name;
  final String image;
  final String description;
  final Color color;

  const Tribe(
    this.code,
    this.name,
    this.image,
    this.description,
    this.color,
  );
}

const List<Tribe> tribes = [
  Tribe(
    'JUDAH',
    'Judah',
    'judah.png',
    'A calling associated with leadership, courage, praise and responsibility.',
    Color(0xFFD4AF37),
  ),
  Tribe(
    'REUBEN',
    'Reuben',
    'reuben.png',
    'A reminder of beginnings, reflection and the opportunity to grow in wisdom.',
    Color(0xFFC85A54),
  ),
  Tribe(
    'GAD',
    'Gad',
    'gad.png',
    'Represents resilience, readiness and perseverance through challenges.',
    Color(0xFF6B8E23),
  ),
  Tribe(
    'ASHER',
    'Asher',
    'asher.png',
    'Associated with gratitude, blessing, joy and sharing abundance.',
    Color(0xFF8FBC8F),
  ),
  Tribe(
    'NAPHTALI',
    'Naphtali',
    'naphtali.png',
    'Represents freedom, agility and expressing hope with grace.',
    Color(0xFF5F9EA0),
  ),
  Tribe(
    'MANASSEH',
    'Manasseh',
    'manasseh.png',
    'A reminder of healing, moving forward and learning from the past.',
    Color(0xFF4682B4),
  ),
  Tribe(
    'SIMEON',
    'Simeon',
    'simeon.png',
    'Represents attentiveness, conviction and the importance of listening.',
    Color(0xFF708090),
  ),
  Tribe(
    'LEVI',
    'Levi',
    'levi.png',
    'Associated with service, devotion and supporting a spiritual community.',
    Color(0xFF4169E1),
  ),
  Tribe(
    'ISSACHAR',
    'Issachar',
    'issachar.png',
    'Represents discernment, understanding and thoughtful decisions.',
    Color(0xFF6495ED),
  ),
  Tribe(
    'ZEBULUN',
    'Zebulun',
    'zebulun.png',
    'Associated with connection, cooperation and journeys with purpose.',
    Color(0xFF87CEEB),
  ),
  Tribe(
    'JOSEPH',
    'Joseph',
    'joseph.png',
    'Represents stewardship, hope and using gifts to serve others.',
    Color(0xFFDDA0DD),
  ),
  Tribe(
    'BENJAMIN',
    'Benjamin',
    'benjamin.png',
    'Associated with courage, loyalty and strength through community.',
    Color(0xFF9370DB),
  ),
];

// ==================== 支派介紹頁面 ====================

class TribeInfoPage extends StatefulWidget {
  final VoidCallback onContinue;

  const TribeInfoPage({
    super.key,
    required this.onContinue,
  });

  @override
  State<TribeInfoPage> createState() => _TribeInfoPageState();
}

class _TribeInfoPageState extends State<TribeInfoPage> {
  Tribe? _selected;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: prayerGradient(),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Text(
                  'CHOOSE YOUR',
                  style: TextStyle(
                    color: cream,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Image.asset(
                  'assets/images/pray-logo.png',
                  height: 82,
                ),
                const Text(
                  'SPIRITUAL TRIBE',
                  style: TextStyle(
                    color: cream,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _selected == null
                      ? GridView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: tribes.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                            childAspectRatio: .78,
                          ),
                          itemBuilder: (_, i) {
                            final t = tribes[i];

                            return InkWell(
                              onTap: () => setState(
                                () => _selected = t,
                              ),
                              child: Column(
                                children: [
                                  _tribeImage(t, 68),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.name,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              _tribeImage(_selected!, 140),
                              const SizedBox(height: 14),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(22),
                                ),
                                child: Text(
                                  _selected!.name,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                ),
                                child: Text(
                                  _selected!.description,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _selected = null,
                                ),
                                child: const Text(
                                  'VIEW ALL TRIBES',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    18,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onContinue,
                      style: _creamButton(),
                      child: const Text('CONTINUE'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

Widget _tribeImage(Tribe tribe, double size) => Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tribe.color.withValues(alpha: .22),
        border: Border.all(
          color: tribe.color,
          width: 2,
        ),
      ),
      child: Image.asset(
        'assets/images/tribes/${tribe.image}',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.auto_awesome,
          color: tribe.color,
          size: size * .55,
        ),
      ),
    );

// ==================== 支派選擇頁面 ====================

class TribeSelectionPage extends StatefulWidget {
  final ValueChanged<Tribe?> onFinish;

  const TribeSelectionPage({
    super.key,
    required this.onFinish,
  });

  @override
  State<TribeSelectionPage> createState() =>
      _TribeSelectionPageState();
}

class _TribeSelectionPageState
    extends State<TribeSelectionPage> {
  Tribe? _selected;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final visible = tribes.skip(_page * 6).take(6).toList();

    return Scaffold(
      body: Container(
        decoration: prayerGradient(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: gold,
                    width: 3,
                  ),
                  color: Colors.white,
                ),
                child: Image.asset(
                  'assets/images/pray-logo.png',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Discover Your Spiritual Heritage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cream,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose from 12 Sacred Tribes',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  itemCount: visible.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .82,
                  ),
                  itemBuilder: (_, i) {
                    final tribe = visible[i];
                    final selected =
                        _selected?.code == tribe.code;

                    return InkWell(
                      onTap: () => setState(
                        () => _selected = tribe,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? cream
                              : const Color(0xFF999999),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? gold
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            _tribeImage(tribe, 70),
                            const SizedBox(height: 8),
                            Text(
                              tribe.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? navy
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _page > 0
                        ? () => setState(() => _page = 0)
                        : null,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Text(
                    _page == 0 ? '●  ○' : '○  ●',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    onPressed: _page == 0
                        ? () => setState(() => _page = 1)
                        : null,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  18,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: _creamButton(),
                        child: const Text('CONTINUE'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onFinish(null),
                      child: const Text(
                        '[NO NEED TO SELECT]',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final tribe = _selected;

    if (tribe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a tribe or choose no selection.',
          ),
        ),
      );
      return;
    }

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Your Sacred Calling',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          decoration: prayerGradient(),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FINAL WARNING',
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Selection "${tribe.name}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'PLEASE READ CAREFULLY',
                style: TextStyle(
                  color: cream,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No changes allowed\n'
                'No second chances\n'
                'No undo option\n'
                'This is your final choice\n'
                'Think twice before confirming.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              false,
            ),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              true,
            ),
            style: _creamButton(),
            child: const Text('I AGREE'),
          ),
        ],
      ),
    );

    if (agreed == true && mounted) {
      widget.onFinish(tribe);
    }
  }
}

// ==================== 首頁 ====================

class HomePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const HomePage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final name = findValue(user, 'displayName') ??
        findValue(user, 'name') ??
        'Prayerlike User';

    final email = findValue(user, 'email') ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PrayLike'),
        backgroundColor: navy,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: prayerGradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    Center(
                      child: Image.asset(
                        'assets/images/pray-logo.png',
                        width: 110,
                        height: 110,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.favorite,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'WELCOME TO PRAYLIKE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cream,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Your spiritual journey starts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),

                    const SizedBox(height: 28),

                    // 使用者資訊
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCOUNT INFORMATION',
                            style: TextStyle(
                              color: gray,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Icon(
                            Icons.account_circle,
                            color: navy,
                            size: 42,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name.toString(),
                            style: const TextStyle(
                              color: navy,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email.toString(),
                            style: const TextStyle(
                              color: gray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'EXPLORE',
                      style: TextStyle(
                        color: cream,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _homeMenu(
                      context,
                      icon: Icons.person_outline,
                      title: 'My Profile',
                      subtitle: 'View your account profile',
                    ),

                    _homeMenu(
                      context,
                      icon: Icons.auto_awesome,
                      title: 'My Tribe',
                      subtitle: 'Explore your spiritual tribe',
                    ),

                    _homeMenu(
                      context,
                      icon: Icons.volunteer_activism,
                      title: 'Prayer',
                      subtitle: 'Prayer features',
                    ),

                    _homeMenu(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Account and app settings',
                    ),

                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('LOG OUT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        backgroundColor: cream,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 首頁功能選單
  Widget _homeMenu(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: cream,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Icon(icon, color: navy, size: 30),
        title: Text(
          title,
          style: const TextStyle(
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
          color: navy,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeaturePlaceholderPage(
                title: title,
                icon: icon,
              ),
            ),
          );
        },
      ),
    );
  }

  // 登出確認
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        title: const Text(
          'Log Out?',
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: _creamButton(),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // 清除本機 Cookie
      await authService.logout();

      if (!context.mounted) return;

      // 清除所有先前頁面，避免返回首頁
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${_cleanError(e)}'),
        ),
      );
    }
  }
}

// ==================== 功能佔位頁面 ====================

class FeaturePlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: navy,
      ),
      body: Container(
        width: double.infinity,
        decoration: prayerGradient(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 80,
                  color: cream,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This feature is coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: _creamButton(),
                  child: const Text('BACK TO HOME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}