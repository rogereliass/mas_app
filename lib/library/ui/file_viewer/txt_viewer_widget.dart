import 'package:flutter/material.dart';

/// Text File Viewer Widget
/// 
/// Displays text file content directly from the database
/// Text content is stored in the database, not in Supabase Storage
class TxtViewerWidget extends StatefulWidget {
  final String url;
  final String? textContent;

  const TxtViewerWidget({
    super.key,
    required this.url,
    this.textContent,
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

    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.brightness == Brightness.dark
          ? Colors.black87
          : Colors.white,
      child: SingleChildScrollView(
        child: SelectableText(
          widget.textContent!,
          style: TextStyle(
            fontSize: 16,
            height: 1.8,
            fontFamily: 'monospace',
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Empty text file',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
