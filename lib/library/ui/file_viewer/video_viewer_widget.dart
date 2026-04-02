import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/constants/app_colors.dart';

class VideoViewerWidget extends StatefulWidget {
  final String url;

  const VideoViewerWidget({super.key, required this.url});

  @override
  State<VideoViewerWidget> createState() => _VideoViewerWidgetState();
}

class _VideoViewerWidgetState extends State<VideoViewerWidget> {
  YoutubePlayerController? _controller;
  bool _hasError = false;
  bool _isPlatformUnsupported = false;
  String? _errorMessage;
  bool _isPlayerReady = false;
  bool _isInitializing = true;
  bool _isDisposed = false;
  String? _resolvedVideoId;

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
      _controller!.removeListener(_controllerListener);
      _controller!.dispose();
      _controller = null;
    }
  }

  void _controllerListener() {
    if (_isDisposed || !mounted || _controller == null) return;

    final value = _controller!.value;

    if (value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _buildPlayerErrorMessage(value.errorCode);
        _isInitializing = false;
      });
    }
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;

    if (widget.url.isEmpty) {
      if (_isDisposed) return;
      setState(() {
        _hasError = true;
        _errorMessage =
            'This video has no link in the library record. Please contact an admin.';
        _isInitializing = false;
      });
      return;
    }

    if (!_isSupportedPlatform) {
      if (_isDisposed) return;
      setState(() {
        _isPlatformUnsupported = true;
        _isInitializing = false;
        _hasError = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _isPlatformUnsupported = false;
      _errorMessage = null;
      _isPlayerReady = false;
      _resolvedVideoId = null;
    });

    try {
      debugPrint('🎬 Initializing YouTube player with URL: ${widget.url}');
      final source = _parseVideoSource(widget.url);
      final videoId = source.videoId;

      if (videoId == null) {
        if (_isDisposed) return;
        setState(() {
          _hasError = true;
          _errorMessage = source.message;
          _isInitializing = false;
        });
        return;
      }

      final controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: true,
          controlsVisibleAtStart: true,
        ),
      );

      controller.addListener(_controllerListener);

      if (!_isDisposed && mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
          _isPlayerReady = false;
          _resolvedVideoId = videoId;
        });
      } else {
        controller.dispose();
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'Unable to start the video player. Please try again or open it in YouTube.';
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

    if (_isPlatformUnsupported) {
      return _buildUnsupportedPlatform();
    }

    if (_hasError) {
      return _buildError();
    }

    if (_isInitializing || _controller == null) {
      return _buildLoading();
    }

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      },
      player: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.goldAccent,
        progressColors: ProgressBarColors(
          playedColor: AppColors.goldAccent,
          bufferedColor: AppColors.goldAccent.withValues(alpha: 0.35),
          handleColor: AppColors.goldAccent,
        ),
        onReady: () {
          if (!mounted || _isDisposed) return;
          setState(() {
            _isPlayerReady = true;
          });
        },
        onEnded: (_) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _isPlayerReady = true;
          });
        },
      ),
      builder: (context, player) {
        return Container(
          color: AppColors.scoutEliteNavy,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: player),
              if (!_isPlayerReady)
                Positioned.fill(
                  child: _buildLoading(),
                ),
            ],
          ),
        );
      },
    );
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  String _buildPlayerErrorMessage(int errorCode) {
    switch (errorCode) {
      case 2:
        return 'The video link is invalid. Please verify the YouTube URL.';
      case 5:
        return 'This video cannot be played in the embedded player. Try opening it in YouTube.';
      case 100:
      case 105:
        return 'This video could not be found. It may have been removed or made private.';
      case 101:
      case 150:
        return 'This uploader disabled embedded playback. Open the video directly in YouTube.';
      default:
        return 'Video playback failed. Please try again or open it in YouTube.';
    }
  }

  ({String? videoId, String message}) _parseVideoSource(String source) {
    final cleaned = source.trim();
    if (cleaned.isEmpty) {
      return (
        videoId: null,
        message: 'This video has an empty link. Please contact an admin.',
      );
    }

    final fromPlugin = YoutubePlayer.convertUrlToId(cleaned);
    if (fromPlugin != null && fromPlugin.isNotEmpty) {
      return (videoId: fromPlugin, message: '');
    }

    if (!cleaned.contains('http') && cleaned.length == 11) {
      return (videoId: cleaned, message: '');
    }

    if (!cleaned.contains('http')) {
      return (
        videoId: null,
        message:
            'Invalid video id format. Use an 11-character YouTube id or a full YouTube URL.',
      );
    }

    final parsed = Uri.tryParse(cleaned);
    if (parsed == null) {
      return (
        videoId: null,
        message: 'Malformed video URL. Please verify the link format.',
      );
    }

    const supportedHosts = {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'www.youtu.be',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com',
    };

    if (!supportedHosts.contains(parsed.host.toLowerCase())) {
      return (
        videoId: null,
        message:
            'Only YouTube links are supported. Please use a youtube.com or youtu.be link.',
      );
    }

    final vParam = parsed.queryParameters['v'];
    if (vParam != null && vParam.length == 11) {
      return (videoId: vParam, message: '');
    }

    final segments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return (
        videoId: null,
        message: 'The YouTube link does not include a video id.',
      );
    }

    final last = segments.last;
    if (last.length == 11) {
      return (videoId: last, message: '');
    }

    return (
      videoId: null,
      message: 'Could not extract a valid YouTube video id from this link.',
    );
  }

  Future<void> _openVideoExternally() async {
    final parsedSource = _parseVideoSource(widget.url);
    final videoId = _resolvedVideoId ?? parsedSource.videoId;
    final watchUrl = videoId == null
        ? widget.url.trim()
        : 'https://www.youtube.com/watch?v=$videoId';

    final uri = Uri.tryParse(watchUrl);
    if (uri == null) {
      _showMessage('Cannot open video: the link is malformed.');
      return;
    }

    if (!await canLaunchUrl(uri)) {
      _showMessage('No app is available to open this video link.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;

    if (launched) {
      _showMessage('Opening video in YouTube...');
      return;
    }

    if (videoId == null) {
      _showMessage(parsedSource.message);
      return;
    }

    _showMessage('Could not open YouTube. Please try again.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildUnsupportedPlatform() {
    return Container(
      color: AppColors.scoutEliteNavy,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_display_outlined,
                size: 44,
                color: AppColors.goldAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'YouTube playback is supported on Android and iOS only.',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This device or platform cannot render the mobile player.',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _openVideoExternally,
              child: const Text(
                'Open in YouTube',
                style: TextStyle(color: AppColors.goldAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: AppColors.scoutEliteNavy,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.goldAccent),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Loading video...',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: AppColors.scoutEliteNavy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'Failed to load video',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _isDisposed ? null : _initializeVideo,
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: AppColors.goldAccent),
                ),
              ),
              TextButton(
                onPressed: _openVideoExternally,
                child: const Text(
                  'Open in YouTube',
                  style: TextStyle(color: AppColors.goldAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
