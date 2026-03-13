import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';

/// Reusable QR renderer for profile identity payloads.
class ProfileQrCodeWidget extends StatelessWidget {
  final String profileId;
  final double size;
  final bool showCenterLogo;
  final String centerLogoAssetPath;
  final double? centerLogoSize;

  const ProfileQrCodeWidget({
    super.key,
    required this.profileId,
    this.size = 260,
    this.showCenterLogo = true,
    this.centerLogoAssetPath = 'assets/images/mas_logo.png',
    this.centerLogoSize,
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
    final resolvedLogoSize = (centerLogoSize ?? size * 0.22)
        .clamp(40.0, 64.0)
        .toDouble();

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
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: qrPayload,
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            size: size,
            gapless: true,
            backgroundColor: AppColors.cardLight,
          ),
          if (showCenterLogo)
            _CenterLogo(
              logoAssetPath: centerLogoAssetPath,
              size: resolvedLogoSize,
            ),
        ],
      ),
    );
  }
}

class _CenterLogo extends StatelessWidget {
  final String logoAssetPath;
  final double size;

  const _CenterLogo({required this.logoAssetPath, required this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size + 12,
      height: size + 12,
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          logoAssetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.qr_code_2_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
