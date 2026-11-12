import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/app_theme.dart';
import '../home/home_page.dart';

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

      setState(() => _error = cleanError(e));

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
                    decoration: inputDecoration('Email'),
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
                    style: creamButton(),
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

Widget _registrationField(
  TextEditingController controller,
  String label,
  String hint,
) => TextField(
  controller: controller,
  decoration: inputDecoration(label, hint: hint),
);

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
                      style: creamButton(),
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
                  style: creamButton(),
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
                        style: creamButton(),
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
            style: creamButton(),
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
