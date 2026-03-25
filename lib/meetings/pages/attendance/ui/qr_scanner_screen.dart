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
  bool _isInForeground = true;
  bool _isCameraActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isInForeground = lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      formats: const [BarcodeFormat.qrCode],
    );
    _scanHandler = AttendanceScanHandler(
      attendanceProvider: widget.attendanceProvider,
      duplicateCooldown: const Duration(seconds: 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isInForeground || _isPaused) {
        return;
      }
      unawaited(_startCameraWithRetry());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    _isInForeground = state == AppLifecycleState.resumed;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isPaused) {
          unawaited(_startCameraWithRetry());
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_setScannerActive(false));
        break;
      case AppLifecycleState.inactive:
        // Keep current camera state during transient inactive events.
        break;
    }
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.scoutEliteNavy,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              fit: BoxFit.cover,
              onDetect: (capture) => _handleCapture(capture.barcodes),
            ),
          ),
          const Positioned.fill(child: _ScanFrameOverlay()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.scoutEliteNavy.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.textPrimaryDark.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.scoutEliteNavy.withValues(
                        alpha: 0.58,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Scan Attendance QR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Align the QR code inside the frame',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimaryDark.withValues(
                                alpha: 0.88,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 + bottomInset,
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

    if (_isInForeground) {
      await _startCameraWithRetry();
    }

    _isPaused = false;
    _statusText.value = 'Scanning...';
  }

  Future<bool> _setScannerActive(bool isActive) async {
    if (_isCameraActive == isActive) {
      return true;
    }

    try {
      if (isActive) {
        await _scannerController.start();
        _isCameraActive = true;
      } else {
        await _scannerController.stop();
        _isCameraActive = false;
      }
      return true;
    } catch (_) {
      // Ignore camera state transitions that can race with disposal/navigation.
      return false;
    }
  }

  Future<void> _startCameraWithRetry() async {
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 140),
      Duration(milliseconds: 280),
    ];

    for (final delay in retryDelays) {
      if (!mounted || !_isInForeground || _isPaused) {
        return;
      }

      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final started = await _setScannerActive(true);
      if (started) {
        return;
      }
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
          final frameSize = (constraints.maxWidth * 0.74).clamp(240.0, 360.0);
          final frameLeft = (constraints.maxWidth - frameSize) / 2;
          final preferredTop = (constraints.maxHeight - frameSize) / 2;
          const minTop = 108.0;
          final maxTop = constraints.maxHeight - frameSize - 132.0;
          final frameTop = maxTop >= minTop
              ? preferredTop.clamp(minTop, maxTop).toDouble()
              : preferredTop.clamp(16.0, constraints.maxHeight - frameSize - 16.0)
                    .toDouble();
          final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameSize, frameSize);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScanMaskPainter(
                    frameRect: frameRect,
                    borderRadius: 20,
                  ),
                ),
              ),
              Positioned(
                left: frameLeft,
                top: frameTop,
                child: Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardLight, width: 2.6),
                    color: Colors.transparent,
                  ),
                ),
              ),
              Positioned(
                left: frameLeft,
                top: frameTop,
                child: SizedBox(
                  width: frameSize,
                  height: frameSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardLight.withValues(alpha: 0.24),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
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

class _ScanMaskPainter extends CustomPainter {
  _ScanMaskPainter({required this.frameRect, required this.borderRadius});

  final Rect frameRect;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = AppColors.scoutEliteNavy.withValues(alpha: 0.44)
      ..style = PaintingStyle.fill;

    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(frameRect, Radius.circular(borderRadius)),
      );

    final mask = Path.combine(PathOperation.difference, fullPath, cutoutPath);
    canvas.drawPath(mask, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanMaskPainter oldDelegate) {
    return oldDelegate.frameRect != frameRect ||
        oldDelegate.borderRadius != borderRadius;
  }
}
