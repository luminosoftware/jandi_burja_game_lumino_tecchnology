import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

/// Who makes Jhanda Burja, what it is, and how to reach the studio.
///
/// Deliberately not the rules screen. The payout table, the odds and the symbol
/// key used to live behind this tile and no longer do; everything on this page
/// is about the app and the people who built it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// A short, plain-language description of the game.
  static const String intro =
      'Jhanda Burja is a modern take on Jhandi Munda, the traditional Nepali '
      'dice game of chance. Six dice, six symbols and one green felt table: '
      'place your coins on the symbols you believe in, then throw and hope two '
      'or more dice land your way. Free to play with virtual coins that carry '
      'no cash value. The game works offline; ads require an internet connection.';

  /// Opens the mail app addressed to the studio.
  ///
  /// Nothing here is essential to playing, so a device without a mail handler
  /// simply does nothing rather than throwing. That is also what keeps widget
  /// tests honest, where the platform plugin is not registered.
  Future<void> _contact() async {
    final Uri email = Uri(scheme: 'mailto', path: AppConfig.supportEmail);
    try {
      await launchUrl(email, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No mail app, or no plugin under `flutter test`.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _Card(
            title: AppConfig.appName,
            children: <Widget>[
              Text(intro, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          _Card(
            title: 'Developed by',
            children: <Widget>[
              const Text(
                AppConfig.companyName,
                style: TextStyle(
                  color: GameColors.cream,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                AppConfig.companyAddress,
                style: TextStyle(color: GameColors.cream, fontSize: 13),
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.email_outlined,
                  color: GameColors.brass,
                ),
                title: const Text(AppConfig.supportEmail),
                subtitle: const Text('Email us'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: _contact,
              ),
            ],
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
            // A transparent Material between the card and its tiles lets the
            // email row's ink splash paint above the fill and clip to the
            // rounded corners, the same way the More screen's cards do.
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
