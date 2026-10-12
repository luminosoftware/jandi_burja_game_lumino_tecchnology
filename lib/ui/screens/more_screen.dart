import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/game_controller.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _Card(
            title: 'Information',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Statistics'),
                subtitle: const Text('Your play history and stats'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StatsScreen(controller: controller),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Settings'),
                subtitle: const Text('Sound, haptics and preferences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(controller: controller),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('About Us'),
                subtitle: const Text('Rules, payouts and information'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HelpScreen(),
                  ),
                ),
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
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            decoration: BoxDecoration(
              color: GameColors.feltMid,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GameColors.feltLight),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
