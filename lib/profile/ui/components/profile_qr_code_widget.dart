import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';

/// Reusable QR renderer for profile identity payloads.
class ProfileQrCodeWidget extends StatelessWidget {
  final String profileId;
  final double size;

  const ProfileQrCodeWidget({
    super.key,
    required this.profileId,
    this.size = 260,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedProfileId = profileId.trim();

    if (trimmedProfileId.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Profile ID unavailable',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final qrPayload = 'user:$trimmedProfileId';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: QrImageView(
        data: qrPayload,
        version: QrVersions.auto,
        size: size,
        gapless: true,
        backgroundColor: AppColors.cardLight,
      ),
    );
  }
}
