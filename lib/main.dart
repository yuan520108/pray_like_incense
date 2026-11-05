import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/posts_service.dart';

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
    theme: ThemeData(useMaterial3: false, fontFamily: 'Arial'),
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
  late Future<Map<String, dynamic>?> _loginCheck;

  @override
  void initState() {
    super.initState();
    _loginCheck = _checkLogin();
  }

  Future<Map<String, dynamic>?> _checkLogin() async {
    try {
      return await authService.getMe();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  void _retryLoginCheck() {
    setState(() => _loginCheck = _checkLogin());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _loginCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('無法確認登入狀態，請檢查網路後重試。'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retryLoginCheck,
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data is Map) {
          return HomePage(user: Map<String, dynamic>.from(data));
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
      final result = findValue(Map<String, dynamic>.from(nested), key);

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

String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

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
  State<RegistrationPage> createState() => _RegistrationPageState();
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

    if (!RegExp(r'^[a-zA-Z0-9_-]{3,30}$').hasMatch(handle)) {
      setState(() {
        _error = 'User ID must be 3–30 characters: letters, numbers, _ or -.';
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
                                      _finishRegistration(name, handle, tribe),
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
        MaterialPageRoute(builder: (_) => HomePage(user: user)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = _cleanError(e));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_error)));
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/images/pray-logo.png', height: 105),
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
                  _registrationField(_handle, 'User ID', '3–30 characters'),
                  const SizedBox(height: 14),
                  _registrationField(_name, 'Name', 'Enter your name'),
                  const SizedBox(height: 14),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: widget.email),
                    decoration: _inputDecoration('Email'),
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Color(0xFF7A1010)),
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
                    style: TextStyle(color: Colors.white, fontSize: 12),
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

InputDecoration _inputDecoration(String label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
    );

Widget _registrationField(
  TextEditingController controller,
  String label,
  String hint,
) => TextField(
  controller: controller,
  decoration: _inputDecoration(label, hint: hint),
);

ButtonStyle _creamButton() => ElevatedButton.styleFrom(
  backgroundColor: cream,
  foregroundColor: navy,
  elevation: 0,
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
);

// ==================== 隱私條款 ====================

class TermsPage extends StatefulWidget {
  final VoidCallback onAgree;

  const TermsPage({super.key, required this.onAgree});

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
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Please review each section before continuing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: _sections
                    .map(
                      (s) => Card(
                        color: cream,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            s['title']!,
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            18,
                          ),
                          children: [
                            Text(
                              s['body']!,
                              style: const TextStyle(height: 1.45),
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
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _checked,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                    activeColor: gold,
                    checkColor: navy,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I have read and agree to the Privacy Policy and Terms.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checked ? widget.onAgree : null,
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

  const TransitionPage({super.key, required this.onComplete});

  @override
  State<TransitionPage> createState() => _TransitionPageState();
}

class _TransitionPageState extends State<TransitionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
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
          colors: [Color(0xFF2C3E50), Color(0xFF3A6073), Color(0xFFC9A961)],
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(_controller),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Image.asset(
              'assets/images/transition-prayer.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.volunteer_activism, size: 150, color: cream),
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

  const Tribe(this.code, this.name, this.image, this.description, this.color);
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

  const TribeInfoPage({super.key, required this.onContinue});

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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
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
            Image.asset('assets/images/pray-logo.png', height: 82),
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
                          onTap: () => setState(() => _selected = t),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
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
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _selected!.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selected = null),
                            child: const Text(
                              'VIEW ALL TRIBES',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
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
    border: Border.all(color: tribe.color, width: 2),
  ),
  child: Image.asset(
    'assets/images/tribes/${tribe.image}',
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) =>
        Icon(Icons.auto_awesome, color: tribe.color, size: size * .55),
  ),
);

// ==================== 支派選擇頁面 ====================

class TribeSelectionPage extends StatefulWidget {
  final ValueChanged<Tribe?> onFinish;

  const TribeSelectionPage({super.key, required this.onFinish});

  @override
  State<TribeSelectionPage> createState() => _TribeSelectionPageState();
}

class _TribeSelectionPageState extends State<TribeSelectionPage> {
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
                  border: Border.all(color: gold, width: 3),
                  color: Colors.white,
                ),
                child: Image.asset('assets/images/pray-logo.png'),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .82,
                  ),
                  itemBuilder: (_, i) {
                    final tribe = visible[i];
                    final selected = _selected?.code == tribe.code;

                    return InkWell(
                      onTap: () => setState(() => _selected = tribe),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected ? cream : const Color(0xFF999999),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? gold : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _tribeImage(tribe, 70),
                            const SizedBox(height: 8),
                            Text(
                              tribe.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? navy : Colors.white,
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
                    style: const TextStyle(color: Colors.white, fontSize: 18),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
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
                        style: TextStyle(color: Colors.white, fontSize: 12),
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
          content: Text('Please select a tribe or choose no selection.'),
        ),
      );
      return;
    }

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Your Sacred Calling',
          textAlign: TextAlign.center,
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
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
                style: TextStyle(color: cream, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'No changes allowed\n'
                'No second chances\n'
                'No undo option\n'
                'This is your final choice\n'
                'Think twice before confirming.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, height: 1.6),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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

const Color appBackground = Color(0xFF2D395D);
const Color appSurface = Color(0xFF414D70);
const Color appDarkSurface = Color(0xFF191A31);
const Color appSelected = Color(0xFFFFDA82);
const Color appIconBrown = Color(0xFF76502D);

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final PostsRepository? postsRepository;

  const HomePage({super.key, required this.user, this.postsRepository});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _selectedCategory = 0;
  int _selectedFeedFilter = 0;
  String? _createMode;
  String _postCategory = 'Personal & Family';
  String _postPrivacy = 'public';
  bool _isFeedLoading = false;
  bool _isCreatingPost = false;
  bool _hasMorePosts = true;
  String? _nextCursor;
  String? _feedError;
  String? _createPostError;
  int _feedGeneration = 0;
  final List<PrayerPost> _posts = [];
  final TextEditingController _postTitle = TextEditingController();
  final TextEditingController _postContent = TextEditingController();
  final TextEditingController _searchUser = TextEditingController();
  final TextEditingController _chatMessage = TextEditingController();

  PostsRepository get _postsRepository =>
      widget.postsRepository ?? PostsService(authService.apiClient.dio);

  static const _navigationItems = [
    (asset: 'assets/icons/Homeicon.png'),
    (asset: 'assets/icons/pray.png'),
    (asset: 'assets/icons/Addicon.png'),
    (asset: 'assets/icons/Profileicon.png'),
    (asset: 'assets/icons/Nova.png'),
  ];

  static const _categories = [
    (label: 'Personal & Family', asset: 'assets/icons/family_and_personal.png'),
    (label: 'Church & Ministry', asset: 'assets/icons/church.png'),
    (label: 'Kingdom Prayer', asset: 'assets/icons/kingdom.png'),
    (label: 'Tribe Prayer', asset: 'assets/icons/tribe.png'),
  ];

  String get _name =>
      (findValue(widget.user, 'displayName') ??
              findValue(widget.user, 'name') ??
              'Prayerlike User')
          .toString();

  String get _email =>
      (findValue(widget.user, 'email') ?? 'No email').toString();

  String get _handle =>
      (findValue(widget.user, 'handle') ??
              findValue(widget.user, 'userId') ??
              _name)
          .toString();

  String get _tribe {
    final value =
        findValue(widget.user, 'tribeCode') ??
        findValue(widget.user, 'tribe') ??
        'Judah';
    if (value is Map) {
      return (value['name'] ?? value['code'] ?? 'Judah').toString();
    }
    return value.toString();
  }

  String? get _avatarUrl {
    final value =
        findValue(widget.user, 'avatarUrl') ??
        findValue(widget.user, 'photoUrl') ??
        findValue(widget.user, 'picture') ??
        findValue(widget.user, 'avatar');
    if (value is! String || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return value;
  }

  @override
  void initState() {
    super.initState();
    _loadFeed(reset: true);
  }

  @override
  void dispose() {
    _postTitle.dispose();
    _postContent.dispose();
    _searchUser.dispose();
    _chatMessage.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool reset = false}) async {
    if ((!reset && _isFeedLoading) || (!reset && !_hasMorePosts)) return;
    if (!reset && (_nextCursor == null || _nextCursor!.isEmpty)) return;

    final generation = reset ? ++_feedGeneration : _feedGeneration;
    final category = _categories[_selectedCategory].label;
    final cursor = reset ? null : _nextCursor;
    setState(() {
      _isFeedLoading = true;
      _feedError = null;
      if (reset) {
        _posts.clear();
        _nextCursor = null;
        _hasMorePosts = true;
      }
    });

    try {
      final page = await _postsRepository.getFeed(
        category: category,
        cursor: cursor,
      );
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        final existingIds = _posts.map((post) => post.postId).toSet();
        _posts.addAll(page.items.where((post) => existingIds.add(post.postId)));
        _nextCursor = page.nextCursor;
        _hasMorePosts = page.nextCursor != null;
        _isFeedLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _isFeedLoading = false;
        _feedError = _cleanError(error);
      });
    }
  }

  Future<void> _publishPost() async {
    final content = _postContent.text.trim();
    final title = _postTitle.text.trim();
    if (content.isEmpty || content.length > 500) {
      setState(() {
        _createPostError = 'Content must be between 1 and 500 characters.';
      });
      return;
    }
    if (title.length > 100) {
      setState(
        () => _createPostError = 'Title must be 100 characters or fewer.',
      );
      return;
    }
    if (_isCreatingPost) return;

    setState(() {
      _isCreatingPost = true;
      _createPostError = null;
    });
    try {
      await _postsRepository.createPost(
        content: content,
        title: title.isEmpty ? null : title,
        category: _postCategory,
        privacy: _postPrivacy,
      );
      if (!mounted) return;

      _postTitle.clear();
      _postContent.clear();
      setState(() {
        _isCreatingPost = false;
        _createMode = null;
        _selectedIndex = 0;
        _selectedCategory = _categories.indexWhere(
          (category) => category.label == _postCategory,
        );
      });
      await _loadFeed(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post published.')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCreatingPost = false;
        _createPostError = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: appBackground,
      body: SafeArea(child: _buildSelectedPage()),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
        return _buildFeedPage();
      case 2:
        return _buildCreatePage();
      case 3:
        return _buildSearchPage();
      case 4:
        return _buildNovaPage();
      default:
        return _buildFeedPage();
    }
  }

  Widget _buildFeedPage() {
    return Column(
      children: [
        _buildFeedHeader(),
        _buildCategoryBar(),
        _buildFeedFilters(),
        Expanded(child: _buildEmptyFeed()),
      ],
    );
  }

  Widget _buildFeedHeader() {
    final tribeImage = 'assets/images/tribes/${_tribe.toLowerCase()}.png';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              GestureDetector(
                key: const ValueKey('profile-avatar'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProfilePage(
                      name: _name,
                      handle: _handle,
                      email: _email,
                      tribe: _tribe,
                      avatarUrl: _avatarUrl,
                    ),
                  ),
                ),
                child: _buildAvatar(size: 44),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 105),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
              const Spacer(),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  border: Border.all(color: const Color(0xFFB7B7B7), width: 2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Color(0xFFFFD000)),
                    SizedBox(width: 5),
                    Text(
                      '4.4',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            children: [
              Image.asset(
                tribeImage,
                width: 40,
                height: 40,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.groups, color: cream, size: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tribe.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _headerAction(
                icon: Icons.groups,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _confirmLogout(context),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: const BoxDecoration(
                    color: cream,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: appIconBrown, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFD1D1D1)),
      ],
    );
  }

  Widget _buildAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF9BC7FA),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: _avatarUrl == null
            ? Icon(
                Icons.person,
                color: const Color(0xFF347BE5),
                size: size * 0.9,
              )
            : Image.network(
                _avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person,
                  color: const Color(0xFF347BE5),
                  size: size * 0.9,
                ),
              ),
      ),
    );
  }

  Widget _headerAction({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: const BoxDecoration(color: cream, shape: BoxShape.circle),
        child: Icon(icon, color: appIconBrown, size: 25),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        children: List.generate(_categories.length, (index) {
          final category = _categories[index];
          final selected = index == _selectedCategory;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedCategory == index) return;
                setState(() => _selectedCategory = index);
                _loadFeed(reset: true);
              },
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: selected ? appSelected : cream,
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: appIconBrown, width: 2)
                          : null,
                    ),
                    child: Image.asset(category.asset),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 94),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? appSelected : const Color(0xFFFFE7B3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appIconBrown, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeedFilters() {
    final filters = _selectedIndex == 1
        ? const ['Original Post', 'Witness Wall', 'Activity']
        : const ['Original Post', 'Witness Wall'];

    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFD1D1D1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: List.generate(filters.length, (index) {
              final selected = index == _selectedFeedFilter;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFeedFilter = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? appSelected : cream,
                        border: Border.all(
                          color: const Color(0xFFFFD000),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        filters[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFeed() {
    if (_posts.isEmpty && _isFeedLoading) {
      return const Center(child: CircularProgressIndicator(color: appSelected));
    }

    if (_posts.isEmpty && _feedError != null) {
      return _feedMessage(
        icon: Icons.cloud_off,
        message: _feedError!,
        actionLabel: 'Retry',
        onAction: () => _loadFeed(reset: true),
      );
    }

    if (_posts.isEmpty) {
      return _feedMessage(
        icon: Icons.mail_outline,
        message: 'No posts matching this filter',
        detail:
            'Current category: ${_categories[_selectedCategory].label} - No data available',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 280 &&
            !_isFeedLoading &&
            _hasMorePosts) {
          _loadFeed();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 12),
        itemCount:
            _posts.length + (_isFeedLoading || _feedError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            if (_feedError != null) {
              return TextButton(
                onPressed: _loadFeed,
                child: Text('Could not load more posts: $_feedError · Retry'),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: appSelected),
              ),
            );
          }
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  Widget _feedMessage({
    required IconData icon,
    required String message,
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 8, 9, 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: appSelected, size: 60),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB9C1D5), fontSize: 15),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _buildPostCard(PrayerPost post) {
    final author = post.author;
    final authorName = author?.displayName ?? 'Unknown user';
    final avatar = author?.avatarUrl;
    final date =
        '${post.createdAt.toLocal().year.toString().padLeft(4, '0')}-'
        '${post.createdAt.toLocal().month.toString().padLeft(2, '0')}-'
        '${post.createdAt.toLocal().day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostAvatar(avatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: const TextStyle(color: gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (post.category != null)
                _postTag(post.category!, category: true),
              const SizedBox(width: 5),
              _postTag(_privacyLabel(post.privacy)),
            ],
          ),
          if (post.title != null && post.title!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              post.title!,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            post.content,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _postAction(
                  icon: Icons.volunteer_activism,
                  label: 'AMEN (${post.amenCount})',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _postAction(
                  icon: Icons.favorite_border,
                  label: 'PRAY FOR ME (${post.commentCount})',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostAvatar(String? avatarUrl) {
    final uri = avatarUrl == null ? null : Uri.tryParse(avatarUrl);
    final validUrl =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF9BC7FA),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: !validUrl
            ? const Icon(Icons.person, color: Color(0xFF347BE5), size: 36)
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person,
                  color: Color(0xFF347BE5),
                  size: 36,
                ),
              ),
      ),
    );
  }

  Widget _postTag(String label, {bool category = false}) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: category ? const Color(0xFFFFFBE3) : const Color(0xFFFFFBE3),
          border: Border.all(color: const Color(0xFFFFE76A)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category ? label : _privacyLabel(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE0C300), fontSize: 10),
        ),
      ),
    );
  }

  String _privacyLabel(String privacy) {
    switch (privacy) {
      case 'public':
        return 'PUBLIC';
      case 'family':
        return 'FAMILY';
      case 'tribe':
        return 'TRIBE';
      case 'individual':
        return 'INDIVIDUAL';
      default:
        return privacy.toUpperCase();
    }
  }

  Widget _postAction({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD990),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: appIconBrown),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: appIconBrown, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePage() {
    if (_createMode == 'text') return _buildTextPostPage();
    if (_createMode == 'voice') return _buildVoicePostPage();

    return Column(
      children: [
        _backButton(() => setState(() => _selectedIndex = 0)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _createChoice(
                    'Create text post',
                    () => setState(() => _createMode = 'text'),
                  ),
                  const SizedBox(height: 54),
                  _createChoice(
                    'Create voice post',
                    () => setState(() => _createMode = 'voice'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backButton(VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _createChoice(String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: cream,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildTextPostPage() {
    return Column(
      children: [
        _backButton(() => setState(() => _createMode = null)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(17, 26, 17, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    _postDropdown(
                      value: _postPrivacy,
                      options: const {
                        'public': 'Public',
                        'family': 'Family',
                        'tribe': 'Tribe',
                        'individual': 'Individual',
                      },
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _postPrivacy = value);
                        }
                      },
                    ),
                    const SizedBox(width: 14),
                    _postDropdown(
                      value: _postCategory,
                      options: {
                        for (final category in _categories)
                          category.label: category.label,
                      },
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _postCategory = value);
                        }
                      },
                    ),
                  ],
                ),
                if (_createPostError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _createPostError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey('post-title'),
                        controller: _postTitle,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          hintText: 'Title',
                          filled: true,
                          fillColor: Color(0xFFD8D8D8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        key: const ValueKey('post-content'),
                        controller: _postContent,
                        maxLength: 500,
                        maxLines: 9,
                        decoration: const InputDecoration(
                          hintText: 'Write your prayer here... (Max 500 words)',
                          filled: true,
                          fillColor: Color(0xFFD8D8D8),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('publish-post'),
                        onPressed: _isCreatingPost ? null : _publishPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appSelected,
                          foregroundColor: appBackground,
                        ),
                        child: _isCreatingPost
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('post'),
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: TextButton(
                        onPressed: _isCreatingPost
                            ? null
                            : () => setState(() => _createMode = null),
                        child: const Text(
                          'cancel',
                          style: TextStyle(color: Color(0xFF8994AD)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _postDropdown({
    required String value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            items: options.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildVoicePostPage() {
    return Column(
      children: [
        _backButton(() => setState(() => _createMode = null)),
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Voice Post',
                      style: TextStyle(
                        color: navy,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text('🎤', style: TextStyle(fontSize: 62)),
                  const SizedBox(height: 18),
                  const Text(
                    'Ready to Record',
                    style: TextStyle(
                      color: navy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click "Start Recording" to begin speaking',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: gray, fontSize: 17),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appSelected,
                            foregroundColor: navy,
                          ),
                          child: const Text('Start Recording'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _createMode = null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: navy,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(() => setState(() => _selectedIndex = 0)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchUser,
                  style: const TextStyle(color: appBackground),
                  decoration: InputDecoration(
                    hintText: 'Search by User ID (e.g., yaa, john123)',
                    hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Text('🔍', style: TextStyle(fontSize: 23)),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                '🔍 Search for friends by User ID to start connecting!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9BAAC9),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNovaPage() {
    return Column(
      children: [
        Container(
          height: 64,
          color: const Color(0xFF15233E),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.menu, color: Colors.white, size: 27),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nova AI Assistant',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '● Online  ·  10 questions remaining',
                      style: TextStyle(color: Color(0xFF00B98E), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: appDarkSurface,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/icons/Nova_com.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B394A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Hello! I am Nova, your AI assistant. How can I help you today?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 5, top: 8),
                        child: Text(
                          '11:39 AM',
                          style: TextStyle(
                            color: Color(0xFF9BAAC9),
                            fontStyle: FontStyle.italic,
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
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF15233E),
            border: Border(top: BorderSide(color: Color(0xFF384564))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatMessage,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ask Nova anything...',
                    hintStyle: const TextStyle(color: Color(0xFF9BAAC9)),
                    filled: true,
                    fillColor: appDarkSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF34415D)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.send, color: Color(0xFF34415D), size: 27),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      key: const ValueKey('home-bottom-navigation'),
      decoration: const BoxDecoration(color: appBackground),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: List.generate(_navigationItems.length, (index) {
              final item = _navigationItems[index];
              final isSelected = _selectedIndex == index;
              return Expanded(
                child: IconButton(
                  key: ValueKey('bottom-nav-$index'),
                  tooltip: switch (index) {
                    0 => 'Home',
                    1 => 'Prayer',
                    2 => 'Create',
                    3 => 'Search friends',
                    _ => 'Nova AI',
                  },
                  onPressed: () => setState(() => _selectedIndex = index),
                  icon: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? appSelected : cream,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? const [
                              BoxShadow(
                                color: Color(0x80FFDA82),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: index == 2
                        ? const Icon(Icons.add, color: appIconBrown, size: 31)
                        : Image.asset(
                            item.asset,
                            key: ValueKey('bottom-nav-icon-$index'),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              );
            }),
          ),
        ),
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
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
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
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged out locally, but server logout failed: ${_cleanError(e)}',
          ),
        ),
      );
    }
  }
}

class ProfilePage extends StatelessWidget {
  final String name;
  final String handle;
  final String email;
  final String tribe;
  final String? avatarUrl;

  const ProfilePage({
    super.key,
    required this.name,
    required this.handle,
    required this.email,
    required this.tribe,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Profile',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ],
              ),
              const Divider(height: 32, color: Color(0xFF485473)),
              const SizedBox(height: 38),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9BC7FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: cream, width: 2),
                    ),
                    child: ClipOval(
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF347BE5),
                              size: 112,
                            )
                          : Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                color: Color(0xFF347BE5),
                                size: 112,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A451),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: appSurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email_outlined, color: Colors.lightBlueAccent),
                    SizedBox(width: 10),
                    Text(
                      'Email',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 68),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
                decoration: BoxDecoration(
                  color: appSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _profileValue('Email', email),
                    _profileValue('Nickname', name),
                    _profileValue('User ID', handle),
                    _profileValue('Tribe', tribe, showDivider: false),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
                decoration: BoxDecoration(
                  color: appSurface,
                  border: Border.all(color: const Color(0xFF485473)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TERMS & CONDITIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 35),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(color: Colors.white, fontSize: 17),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFADB5C6),
                            side: const BorderSide(color: Color(0xFF596581)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Read in detail →'),
                        ),
                      ],
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

  Widget _profileValue(String label, String value, {bool showDivider = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFD0D2DC), fontSize: 17),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 21),
          ),
          if (showDivider) ...[
            const SizedBox(height: 26),
            const Divider(height: 1, color: Color(0xFF56617E)),
          ],
        ],
      ),
    );
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
      appBar: AppBar(title: Text(title), backgroundColor: navy),
      body: Container(
        width: double.infinity,
        decoration: prayerGradient(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 80, color: cream),
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
                  style: TextStyle(color: Colors.white, fontSize: 16),
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
