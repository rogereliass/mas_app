import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/attendance/logic/attendance_provider.dart';
import 'package:masapp/meetings/pages/attendance/logic/attendance_scan_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.attendanceProvider});

  final AttendanceProvider attendanceProvider;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  late final AttendanceScanHandler _scanHandler;

  final ValueNotifier<String> _statusText = ValueNotifier<String>(
    'Scanning...',
  );
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      formats: const [BarcodeFormat.qrCode],
    );
    _scanHandler = AttendanceScanHandler(
      attendanceProvider: widget.attendanceProvider,
      duplicateCooldown: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.resumed && !_isPaused) {
      unawaited(_setScannerActive(true));
      return;
    }

    unawaited(_setScannerActive(false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusText.dispose();
    _scanHandler.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scoutEliteNavy,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) => _handleCapture(capture.barcodes),
            ),
          ),
          const Positioned.fill(child: _ScanFrameOverlay()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.scoutEliteNavy.withValues(
                      alpha: 0.48,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimaryDark,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scan Attendance QR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 42,
            child: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: _statusText,
                builder: (context, status, _) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? AppColors.cardDarkElevated
                                  : AppColors.cardLight)
                              .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCapture(List<Barcode> barcodes) async {
    if (_isPaused || !mounted || barcodes.isEmpty) {
      return;
    }

    final rawValue = barcodes
        .map((code) => code.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (rawValue.isEmpty) {
      return;
    }

    final feedback = await _scanHandler.handleRawCode(rawValue);
    if (!mounted || feedback == null) {
      return;
    }

    _statusText.value = feedback.message;

    switch (feedback.type) {
      case AttendanceScanFeedbackType.success:
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        _showSnack(feedback.message);
        await _pauseBriefly(const Duration(milliseconds: 350));
        break;
      case AttendanceScanFeedbackType.alreadyMarked:
        _showSnack(feedback.message);
        await _pauseBriefly(const Duration(milliseconds: 250));
        break;
      case AttendanceScanFeedbackType.invalidCode:
      case AttendanceScanFeedbackType.notInContext:
      case AttendanceScanFeedbackType.unauthorized:
      case AttendanceScanFeedbackType.error:
        _showSnack(feedback.message);
        await _pauseBriefly(const Duration(milliseconds: 300));
        break;
    }
  }

  Future<void> _pauseBriefly(Duration delay) async {
    _isPaused = true;
    await _setScannerActive(false);
    await Future<void>.delayed(delay);
    if (!mounted) {
      return;
    }
    await _setScannerActive(true);
    _isPaused = false;
    _statusText.value = 'Scanning...';
  }

  Future<void> _setScannerActive(bool isActive) async {
    try {
      if (isActive) {
        await _scannerController.start();
      } else {
        await _scannerController.stop();
      }
    } catch (_) {
      // Ignore camera state transitions that can race with disposal/navigation.
    }
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameSize = (constraints.maxWidth * 0.64).clamp(210.0, 300.0);
          final frameTop = (constraints.maxHeight * 0.2).clamp(120.0, 220.0);

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: AppColors.scoutEliteNavy.withValues(alpha: 0.24),
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - frameSize) / 2,
                top: frameTop,
                child: Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardLight, width: 2.2),
                    color: Colors.transparent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
