import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// PDF Viewer Widget
/// 
/// Displays PDF files from both network URLs and local file paths
/// View-only mode with text selection and zoom support
class PDFViewerWidget extends StatefulWidget {
  final String url;

  const PDFViewerWidget({
    super.key,
    required this.url,
  });

  @override
  State<PDFViewerWidget> createState() => _PDFViewerWidgetState();
}

class _PDFViewerWidgetState extends State<PDFViewerWidget> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  /// Check if the URL is a local file path
  bool _isLocalFile(String url) {
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder if URL is empty
    if (widget.url.isEmpty) {
      return _buildPlaceholder();
    }

    final isLocal = _isLocalFile(widget.url);
    if (kDebugMode) {
      debugPrint('📄 PDFViewer loading ${isLocal ? "local file" : "network URL"}: ${widget.url}');
    }

    // Use appropriate constructor based on source type
    return isLocal
        ? SfPdfViewer.file(
            File(widget.url),
            key: _pdfViewerKey,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              if (kDebugMode) {
                debugPrint('❌ PDF load failed (local): ${details.error} - ${details.description}');
              }
            },
          )
        : SfPdfViewer.network(
            widget.url,
            key: _pdfViewerKey,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              if (kDebugMode) {
                debugPrint('❌ PDF load failed (network): ${details.error} - ${details.description}');
              }
            },
          );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.brown.shade300,
            Colors.brown.shade500,
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
                Icons.picture_as_pdf,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PDF Not Available',
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

