import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

/// Privacy policy for Jhanda Burja.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _intro =
      'This Privacy Policy explains how Lumino Technology Pvt. Ltd. handles '
      'information when you use Jhanda Burja. The developer does not operate '
      'an account system or collect personal information directly through the '
      'game. Google Mobile Ads may process information to provide and measure '
      'advertising, as described below.';

  Future<void> _openAdMobPolicy() async {
    final Uri uri = Uri.parse(
      'https://policies.google.com/privacy',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser available; ignore.
    }
  }

  Future<void> _contact() async {
    final Uri email = Uri(scheme: 'mailto', path: AppConfig.supportEmail);
    try {
      await launchUrl(email, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No mail app available; ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _Card(
            title: 'Overview',
            children: <Widget>[
              Text(_intro, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          _Card(
            title: 'Information We Collect',
            children: <Widget>[
              const Text(
                'We do not require you to create an account or provide personal '
                'information such as your name, email address, or phone number.',
                style: TextStyle(color: GameColors.cream),
              ),
              const SizedBox(height: 8),
              const Text(
                'The game saves data on your device: your virtual coin balance, '
                'selected chip denomination, last bet layout, lifetime statistics, '
                'sound setting, throw mode (2D/3D), and whether you have seen the '
                'age acknowledgement. The developer does not receive this saved '
                'game data through the game. Ad-related data handled by Google is '
                'described in “Third-Party Services.”',
                style: TextStyle(color: GameColors.cream),
              ),
            ],
          ),
          _Card(
            title: 'Third-Party Services',
            children: <Widget>[
              const Text(
                'This app uses Google Mobile Ads (AdMob) for banner ads and optional '
                'rewarded videos that grant in-game coins. AdMob may collect '
                'information '
                'such as device identifiers, IP address, approximate location, '
                'diagnostics, and ad interactions to provide and measure ads. '
                'This data is '
                'handled by Google in accordance with Google’s Privacy Policy.',
                style: TextStyle(color: GameColors.cream),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.open_in_new,
                  color: GameColors.brass,
                ),
                title: const Text("Google's Privacy Policy"),
                onTap: _openAdMobPolicy,
              ),
            ],
          ),
          _Card(
            title: 'Data Security',
            children: <Widget>[
              const Text(
                'The game does not operate its own servers for player data. Game '
                'settings, balance, bets, and statistics are stored locally by the '
                'app on your device. Google Mobile Ads may transmit and process '
                'ad-related information under Google’s privacy practices. Please '
                'protect access to your device; locally stored game data is subject '
                'to your device’s security.',
                style: TextStyle(color: GameColors.cream),
              ),
            ],
          ),
          _Card(
            title: 'Data Retention and Deletion',
            children: <Widget>[
              const Text(
                'Game settings, virtual coin balance, bet layout, and statistics '
                'remain in local app storage until you clear the app data or '
                'uninstall the app. The developer does not receive this saved '
                'game data through the game. Google handles ad-related data under '
                'its own retention and deletion practices, described in Google’s '
                'Privacy Policy and account controls.',
                style: TextStyle(color: GameColors.cream),
              ),
            ],
          ),
          _Card(
            title: "Children's Privacy",
            children: <Widget>[
              const Text(
                'Jhanda Burja is intended for adults aged 18 and over and includes '
                'simulated betting using virtual coins with no cash value. The '
                'first-launch notice asks players to acknowledge this, but the game '
                'does not collect a date of birth or independently verify age. The '
                'game does not ask players to provide personal information. The '
                'Google Mobile Ads SDK may process device and advertising data; '
                'see Google’s Privacy Policy above for details about Google’s '
                'handling of that data.',
                style: TextStyle(color: GameColors.cream),
              ),
            ],
          ),
          _Card(
            title: 'Changes to This Policy',
            children: <Widget>[
              const Text(
                'We may update this Privacy Policy from time to time. Any changes '
                'will be reflected by updating the policy in this app. Continued '
                'use of the app after changes constitutes acceptance of the updated '
                'policy.',
                style: TextStyle(color: GameColors.cream),
              ),
            ],
          ),
          _Card(
            title: 'Contact Us',
            children: <Widget>[
              const Text(
                'If you email support, we receive the email address and message '
                'you choose to send and use them to respond to your request.',
                style: TextStyle(color: GameColors.cream),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.email_outlined,
                  color: GameColors.brass,
                ),
                title: const Text(AppConfig.supportEmail),
                subtitle: const Text('Questions or concerns'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: _contact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Last updated: October 2026',
            style: TextStyle(color: GameColors.cream, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: GameColors.feltMid,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GameColors.feltLight),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
