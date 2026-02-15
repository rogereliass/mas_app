import 'package:flutter/material.dart';

/// Text File Viewer Widget
/// 
/// Displays text file content directly from the database
/// Text content is stored in the database, not in Supabase Storage
class TxtViewerWidget extends StatefulWidget {
  final String url;
  final String? textContent;
  final String? iconUrl;

  const TxtViewerWidget({
    super.key,
    required this.url,
    this.textContent,
    this.iconUrl,
  });

  @override
  State<TxtViewerWidget> createState() => _TxtViewerWidgetState();
}

class _TxtViewerWidgetState extends State<TxtViewerWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Check if we have text content
    if (widget.textContent == null || widget.textContent!.isEmpty) {
      return _buildEmpty();
    }

    // Detect if content contains Arabic characters
    final hasArabic = _containsArabic(widget.textContent!);
    final hasImage = widget.iconUrl != null && widget.iconUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.scaffoldBackgroundColor, // Use app's theme background color
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: hasArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Display image if iconUrl is provided
            if (hasImage) ...[
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 400,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.iconUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const Divider(height: 32),
            ],
            // Display text content
            SelectableText(
              widget.textContent!,
              textAlign: hasArabic ? TextAlign.right : TextAlign.left,
              textDirection: hasArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontSize: 16,
                height: 1.8,
                fontFamily: hasArabic ? null : 'monospace', // Use system font for Arabic
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if text contains Arabic characters
  bool _containsArabic(String text) {
    // Arabic Unicode range: U+0600 to U+06FF
    return text.runes.any((rune) => rune >= 0x0600 && rune <= 0x06FF);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Empty text file',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

