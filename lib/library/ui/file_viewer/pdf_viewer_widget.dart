import 'package:flutter/material.dart';

/// PDF Viewer Widget
/// 
/// Displays PDF files streamed from Supabase URL
/// View-only mode, does not save locally
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
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPDF();
  }

  Future<void> _loadPDF() async {
    try {
      // TODO: Implement PDF streaming from Supabase
      // Use packages like: flutter_pdfview, syncfusion_flutter_pdfviewer, or pdfx
      // Example:
      // final response = await Supabase.instance.client.storage
      //     .from('files')
      //     .createSignedUrl(widget.url, 3600); // 1 hour expiry
      // 
      // Load PDF from signed URL without downloading:
      // await PdfController.loadFromUrl(response);

      // Simulate loading
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_error != null) {
      return _buildError();
    }

    // TODO: Replace with actual PDF viewer
    // Example using syncfusion_flutter_pdfviewer:
    // return SfPdfViewer.network(
    //   widget.url,
    //   enableDoubleTapZooming: true,
    //   enableTextSelection: true,
    // );

    return _buildPlaceholder();
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading PDF...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load PDF',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
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
                color: Colors.white.withOpacity(0.3),
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
              'PDF Viewer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Streaming from Supabase',
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
