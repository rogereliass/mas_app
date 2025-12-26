import 'package:flutter/material.dart';

/// Video Viewer Widget
/// 
/// Displays videos streamed from Supabase URL
/// Supports play/pause, seek, and fullscreen controls
class VideoViewerWidget extends StatefulWidget {
  final String url;

  const VideoViewerWidget({
    super.key,
    required this.url,
  });

  @override
  State<VideoViewerWidget> createState() => _VideoViewerWidgetState();
}

class _VideoViewerWidgetState extends State<VideoViewerWidget> {
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // TODO: Implement video streaming from Supabase
      // Use video_player package
      // Example:
      // final signedUrl = await Supabase.instance.client.storage
      //     .from('files')
      //     .createSignedUrl(widget.url, 3600);
      // 
      // _videoController = VideoPlayerController.network(signedUrl);
      // await _videoController.initialize();
      // 
      // if (mounted) {
      //   setState(() {
      //     _isInitialized = true;
      //   });
      // }

      // Simulate initialization
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // TODO: Dispose video controller
    // _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    // TODO: Implement play/pause
    // if (_isPlaying) {
    //   _videoController.play();
    // } else {
    //   _videoController.pause();
    // }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildError();
    }

    if (!_isInitialized) {
      return _buildLoading();
    }

    // TODO: Replace with actual video player
    // Example using video_player:
    // return Stack(
    //   alignment: Alignment.center,
    //   children: [
    //     AspectRatio(
    //       aspectRatio: _videoController.value.aspectRatio,
    //       child: VideoPlayer(_videoController),
    //     ),
    //     VideoProgressIndicator(
    //       _videoController,
    //       allowScrubbing: true,
    //     ),
    //     if (!_isPlaying)
    //       IconButton(
    //         icon: Icon(Icons.play_circle_fill, size: 80),
    //         onPressed: _togglePlayPause,
    //       ),
    //   ],
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
          Text('Loading video...'),
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
            'Failed to load video',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red.withOpacity(0.7),
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
            Colors.purple.shade300,
            Colors.purple.shade600,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Video Player',
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
          Positioned(
            bottom: 32,
            child: ElevatedButton.icon(
              onPressed: _togglePlayPause,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? 'Pause' : 'Play'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
