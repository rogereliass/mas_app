import 'package:flutter/material.dart';

import 'profile_info_row.dart';
import 'profile_section.dart';

/// Prebuilt slots using the new component styling format.
class FutureModulesSection extends StatelessWidget {
  const FutureModulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chevronColor = theme.colorScheme.onSurfaceVariant;

    return ProfileSection(
      title: 'Extensions',
      children: [
        ProfileInfoRow(
          icon: Icons.workspace_premium_outlined,
          label: 'Achievements',
          value: 'Coming soon',
          trailing: Icon(Icons.chevron_right, size: 20, color: chevronColor),
          onTap: () {},
        ),
        ProfileInfoRow(
          icon: Icons.insights_outlined,
          label: 'Statistics',
          value: 'Coming soon',
          trailing: Icon(Icons.chevron_right, size: 20, color: chevronColor),
          onTap: () {},
        ),
        ProfileInfoRow(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Troop Permissions',
          value: 'Coming soon',
          trailing: Icon(Icons.chevron_right, size: 20, color: chevronColor),
          onTap: () {},
        ),
        ProfileInfoRow(
          icon: Icons.tune_outlined,
          label: 'App Settings',
          value: 'Coming soon',
          trailing: Icon(Icons.chevron_right, size: 20, color: chevronColor),
          onTap: () {},
        ),
      ],
    );
  }
}
