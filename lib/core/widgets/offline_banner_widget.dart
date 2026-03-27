import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/core/services/connectivity_service.dart';

class OfflineBannerWidget extends StatefulWidget {
  const OfflineBannerWidget({super.key});

  @override
  State<OfflineBannerWidget> createState() => _OfflineBannerWidgetState();
}

class _OfflineBannerWidgetState extends State<OfflineBannerWidget> {
  late bool _isOnline;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.instance.isOnline;
    _subscription = ConnectivityService.instance.statusStream.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.warning.withValues(alpha: 0.3)
        : AppColors.warning;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isOnline) {
      return const SizedBox(height: 0);
    }

    return SizedBox(
      height: 40,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: bgColor,
          child: Text(
            'Offline mode',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
