import 'package:flutter/material.dart';

/// Text File Viewer Widget
/// 
/// Displays text file content streamed from Supabase
/// Renders text directly inside the app with formatting
class TxtViewerWidget extends StatefulWidget {
  final String url;

  const TxtViewerWidget({
    super.key,
    required this.url,
  });

  @override
  State<TxtViewerWidget> createState() => _TxtViewerWidgetState();
}

class _TxtViewerWidgetState extends State<TxtViewerWidget> {
  bool _isLoading = true;
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTextContent();
  }

  Future<void> _loadTextContent() async {
    try {
      // TODO: Fetch text content from Supabase
      // Example:
      // final response = await Supabase.instance.client.storage
      //     .from('files')
      //     .download(widget.url);
      // 
      // final content = utf8.decode(response);
      // 
      // if (mounted) {
      //   setState(() {
      //     _content = content;
      //     _isLoading = false;
      //   });
      // }

      // Simulate loading with sample content
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _content = '''Scout Survival Guide - Level 1

This comprehensive guide covers essential survival skills for scouts, including:

1. Navigation Techniques
   - Using a compass
   - Reading topographic maps
   - Natural navigation (sun, stars, moss)
   - GPS basics

2. First Aid Basics
   - Treating cuts and wounds
   - Managing sprains and fractures
   - Recognizing shock
   - CPR fundamentals

3. Shelter Building
   - Selecting appropriate locations
   - Types of emergency shelters
   - Materials and tools needed
   - Weather considerations

4. Fire Starting
   - Gathering tinder, kindling, and fuel
   - Match and lighter techniques
   - Friction-based methods
   - Fire safety protocols

5. Water Procurement
   - Finding water sources
   - Purification methods
   - Storage techniques
   - Hydration guidelines

6. Outdoor Safety Protocols
   - Wildlife awareness
   - Weather preparedness
   - Emergency signaling
   - Leave No Trace principles

Remember: Practice these skills in safe, supervised environments before relying on them in emergency situations.

Stay safe, stay prepared!''';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildLoading();
    }

    if (_error != null) {
      return _buildError();
    }

    if (_content == null || _content!.isEmpty) {
      return _buildEmpty();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.brightness == Brightness.dark
          ? Colors.black87
          : Colors.white,
      child: SingleChildScrollView(
        child: SelectableText(
          _content!,
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

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading text content...'),
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
            'Failed to load text',
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
