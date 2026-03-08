import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'components/profile_qr_code_widget.dart';

/// Dialog/screen content that displays a profile QR code and guidance text.
class ProfileQrCodeScreen extends StatelessWidget {
  final String profileId;
  final String profileName;

  const ProfileQrCodeScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final displayName = profileName.trim().isEmpty
        ? 'Member'
        : profileName.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final qrSize = isNarrow ? 230.0 : 260.0;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile QR Code',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.goldAccent
                              : AppColors.rankBronze,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ProfileQrCodeWidget(
                    profileId: profileId,
                    size: qrSize,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Let another member scan this code to identify your profile.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
