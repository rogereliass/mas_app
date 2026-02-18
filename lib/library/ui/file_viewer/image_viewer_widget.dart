import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Image Viewer Widget
/// 
/// Displays images from both network URLs and local file paths
/// Supports pinch-to-zoom and pan gestures
class ImageViewerWidget extends StatefulWidget {
  final String url;

  const ImageViewerWidget({
    super.key,
    required this.url,
  });

  @override
  State<ImageViewerWidget> createState() => _ImageViewerWidgetState();
}

class _ImageViewerWidgetState extends State<ImageViewerWidget> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// Check if the URL is a local file path
  bool _isLocalFile(String url) {
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty or null URLs
    if (widget.url.isEmpty) {
      return _buildPlaceholder();
    }

    final isLocal = _isLocalFile(widget.url);
    if (kDebugMode) {
      debugPrint('🖼️ ImageViewer loading ${isLocal ? "local file" : "network URL"}: ${widget.url}');
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: isLocal
            ? Image.file(
                File(widget.url),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    debugPrint('❌ Error loading local image: $error');
                  }
                  return _buildErrorWidget();
                },
              )
            : Image.network(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Loading image...'),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  if (kDebugMode) {
                    debugPrint('❌ Error loading network image: $error');
                  }
                  return _buildErrorWidget();
                },
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade300,
            Colors.green.shade600,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.image,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Image Not Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'File not found in storage\nCheck storage_path in database',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

