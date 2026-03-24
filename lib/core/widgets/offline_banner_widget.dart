import 'dart:async';

import 'package:flutter/material.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          offset: _isOnline ? const Offset(0, -1.2) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _isOnline ? 0 : 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.errorContainer,
              child: Text(
                'Offline mode',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
