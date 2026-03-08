import 'package:flutter/material.dart';

import 'ui/profile_page.dart' as profile_ui;

/// Route-level entry widget for the Profile tab.
///
/// Keeping a concrete widget here avoids re-export lookup edge-cases
/// during incremental compilation while preserving route imports.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const profile_ui.ProfilePage();
  }
}
