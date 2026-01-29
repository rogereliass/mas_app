import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Video Viewer Widget
/// 
/// Displays YouTube videos embedded in the app
/// Extracts video ID from YouTube URLs stored in storagePath
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
  YoutubePlayerController? _controller;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlayerReady = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Extract YouTube video ID from URL
      final videoId = YoutubePlayer.convertUrlToId(widget.url);
      
      if (videoId == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid YouTube URL';
        });
        return;
      }

      // Initialize YouTube player controller
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          loop: false,
          controlsVisibleAtStart: true,
          hideControls: false,
          forceHD: false,
        ),
      )..addListener(_listener);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading video: $e';
        });
      }
    }
  }

  void _listener() {
    if (_controller != null && mounted) {
      if (_controller!.value.isReady && !_isPlayerReady) {
        setState(() {
          _isPlayerReady = true;
        });
      }
      
      // Handle fullscreen changes only when state actually changes
      if (_controller!.value.isFullScreen != _isFullScreen) {
        _isFullScreen = _controller!.value.isFullScreen;
        if (_isFullScreen) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener);
    _controller?.dispose();
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildError();
    }

    if (_controller == null) {
      return _buildLoading();
    }

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        // Reset orientation when exiting fullscreen
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
        ),
        onReady: () {
          setState(() {
            _isPlayerReady = true;
          });
        },
        aspectRatio: 16 / 9,
      ),
      builder: (context, player) {
        return player;
      },
    );
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
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Failed to load video',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
