import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';

const _tribeNames = {
  1: 'Judah',
  2: 'Reuben',
  3: 'Gad',
  4: 'Asher',
  5: 'Naphtali',
  6: 'Manasseh',
  7: 'Simeon',
  8: 'Levi',
  9: 'Issachar',
  10: 'Zebulun',
  11: 'Joseph',
  12: 'Benjamin',
};

const _privacyPolicyText = '''Pray Like Incense

Personal Data Protection and Privacy Policy (Taiwan PDPA Version)

1. Introduction

Pray Like Incense (hereinafter referred to as "the Service") values the privacy and personal data protection of every user. This Policy is established in accordance with the Personal Data Protection Act of Taiwan and relevant regulations, and explains how the Service collects, processes, uses, and protects users' personal data.

2. Purposes of Personal Data Collection

The Service collects personal data solely for the following purposes:
1. User account registration and identity verification
2. Publishing prayer requests, responses (Amen), and intercessory interaction features
3. Multilingual translation, system notifications, and service optimization
4. Account management, system maintenance, and security control
5. Internal statistics and analysis related to the Service's mission (without personal identification)

All collection purposes are reasonable, necessary, and directly related to religious and community services.

3. Categories of Personal Data Collected

The personal data collected by the Service may include, but is not limited to, the following:

Basic Information:
- Email address
- Username (nickname)
- Language preference

Usage Records:
- Login time
- Prayer and response records
- System operation behavior (for technical and security purposes only)

The Service does not proactively collect national identification numbers, physical addresses, phone numbers, financial account information, medical data, or other sensitive personal data.

4. Period, Area, Subjects, and Methods of Personal Data Use

1. Period: From the date of user registration until account deletion or termination of the Service.
2. Area: Primarily processed within Taiwan. If cross-border data storage is required due to cloud services, reasonable security protection measures will be implemented.
3. Subjects: Limited to necessary administrative personnel of the Service or legally commissioned technical service providers. The Service will not sell, exchange, or rent personal data to any third party.
4. Methods: Personal data is processed by automated or non-automated means within lawful and secure system environments.

5. Data Security and Protection Measures

The Service adopts reasonable technical and administrative measures to prevent unauthorized access, alteration, leakage, or destruction of personal data, including access control management, encrypted data transmission, confidentiality obligations for administrators, and regular review and improvement of security measures.

6. User Rights

In accordance with Article 3 of the Personal Data Protection Act, users may request access or review, a copy, supplementation or correction, cessation of collection, processing or use, or deletion of their personal data. Users may submit such requests through the contact channels provided by the Service.

7. Data Autonomy and Privacy Settings

Users may choose the visibility of prayer content published within the Service, including public display, limited groups, or personal private records. All disclosure settings are determined by the user. The Service will not alter visibility settings without user authorization.

8. Policy Amendments

The Service reserves the right to revise this Policy in response to legal amendments or service requirements. Revised versions will be announced on relevant Service pages without individual notice.

9. Contact Information

For questions regarding this Policy, personal data protection, or rights under the Personal Data Protection Act, contact the Service at info@yalinelena.church.''';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final ProfileService profileService;

  const ProfilePage({
    super.key,
    required this.user,
    required this.profileService,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<ProfileInfo> _profileFuture;
  bool _isUploadingAvatar = false;
  String? _uploadedAvatarUrl;

  Future<void> _changeAvatar() async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final avatarUrl = await widget.profileService.uploadAvatar(file);
      if (!mounted) return;
      setState(() {
        _uploadedAvatarUrl = avatarUrl;
        widget.user['avatarUrl'] = avatarUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileService.getMyProfile();
  }

  void _retry() {
    setState(() {
      _profileFuture = widget.profileService.getMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<ProfileInfo>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: appGold),
            );
          }
          if (snapshot.hasError) {
            final user = widget.user;
            final id = (user['id'] ?? user['userId'] ?? '').toString();
            if (id.isNotEmpty) {
              return _buildProfile(
                ProfileInfo(
                  userId: id,
                  displayName:
                      (user['displayName'] ??
                              user['name'] ??
                              user['username'] ??
                              'Not set')
                          .toString(),
                  handle: user['handle']?.toString(),
                  avatarUrl:
                      user['avatarUrl']?.toString() ??
                      user['avatar_url']?.toString(),
                  tribeCode: int.tryParse(
                    (user['tribeCode'] ?? user['tribe'] ?? '').toString(),
                  ),
                ),
              );
            }
            return _ErrorState(error: snapshot.error!, onRetry: _retry);
          }

          final profile = snapshot.data!;
          return _buildProfile(profile);
        },
      ),
    );
  }

  Widget _buildProfile(ProfileInfo profile) {
    final avatar =
        _uploadedAvatarUrl ??
        profile.avatarUrl ??
        widget.user['avatarUrl']?.toString() ??
        widget.user['avatar_url']?.toString() ??
        widget.user['avatar']?.toString();
    final avatarUrl = avatar == null || avatar.isEmpty
        ? null
        : _resolveMediaUrl(avatar);
    final email = widget.user['email']?.toString();
    final provider = widget.user['provider']?.toString() ?? 'Email';
    final tribe = profile.tribeCode == null
        ? null
        : _tribeNames[profile.tribeCode] ?? 'Tribe ${profile.tribeCode}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              InkWell(
                onTap: _isUploadingAvatar ? null : _changeAvatar,
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: 'Change avatar',
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 116,
                        height: 116,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFF667EEA),
                          backgroundImage: avatarUrl == null
                              ? null
                              : NetworkImage(avatarUrl),
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 56,
                                )
                              : null,
                        ),
                      ),
                      if (_isUploadingAvatar)
                        const CircularProgressIndicator(color: appGold)
                      else
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: appGold,
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 20,
                              color: Color(0xFF26314D),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.email_outlined, color: appGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      provider,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _InfoRow(label: 'Email', value: _orUnavailable(email)),
              _InfoRow(label: 'Nickname', value: profile.displayName),
              _InfoRow(label: 'User ID', value: profile.userId),
              if (tribe != null) _InfoRow(label: 'Tribe', value: tribe),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'TERMS & CONDITIONS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: appCream,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Color(0xFF26314D),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _showPrivacyPolicy,
                child: const Text('Read in detail'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _resolveMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(ApiClient.baseUrl).resolve(value).toString();
  }

  String _orUnavailable(String? value) =>
      value == null || value.isEmpty ? 'Not available' : value;

  Future<void> _showPrivacyPolicy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy Policy'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            _privacyPolicyText,
            style: const TextStyle(height: 1.55),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unable to load your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
