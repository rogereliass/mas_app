import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class VideoViewerWidget extends StatefulWidget {
  final String url;

  const VideoViewerWidget({super.key, required this.url});

  @override
  State<VideoViewerWidget> createState() => _VideoViewerWidgetState();
}

class _VideoViewerWidgetState extends State<VideoViewerWidget> {
  YoutubePlayerController? _controller;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlayerReady = false;
  bool _isInitializing = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _initializeVideo();
    }
  }

  void _disposeController() {
    if (_controller != null) {
      _controller!.close();
      _controller = null;
    }
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;

    if (widget.url.isEmpty) {
      if (_isDisposed) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'No video URL provided';
        _isInitializing = false;
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      debugPrint('🎬 Initializing YouTube player with URL: ${widget.url}');
      final videoId = YoutubePlayerController.convertUrlToId(widget.url);

      if (videoId == null) {
        if (_isDisposed) return;
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid YouTube URL';
          _isInitializing = false;
        });
        return;
      }

      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          showControls: true,
          enableKeyboard: false,
          playsInline: true,
          strictRelatedVideos: true,
          enableCaption: true,
        ),
      );

      _controller!.listen((event) {
        if (_isDisposed || !mounted) return;

        if (event.playerState == PlayerState.playing) {
          if (!_isPlayerReady) {
            setState(() {
              _isPlayerReady = true;
              _isInitializing = false;
            });
          }
        }

        if (event.playerState == PlayerState.unknown && event.hasError) {
          if (!_isDisposed) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Error loading video';
              _isInitializing = false;
            });
          }
        }

        if (event.playerState == PlayerState.ended) {
          if (!_isDisposed) {
            setState(() {
              _isInitializing = false;
            });
          }
        }
      });

      if (!_isDisposed && mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading video: $e';
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeController();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    if (_hasError) {
      return _buildError();
    }

    if (_isInitializing || _controller == null) {
      return _buildLoading();
    }

    return Container(
      color: Colors.black,
      child: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
        backgroundColor: Colors.black,
        enableFullScreenOnVerticalDrag: true,
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'Failed to load video',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _isDisposed ? null : _initializeVideo,
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
