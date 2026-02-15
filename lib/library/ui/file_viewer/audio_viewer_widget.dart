import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

/// Audio File Viewer Widget
/// 
/// Displays and plays audio files from both network URLs and local file paths
/// Supports displaying an optional image from iconUrl above the audio player
class AudioViewerWidget extends StatefulWidget {
  final String url;
  final String? iconUrl;

  const AudioViewerWidget({
    super.key,
    required this.url,
    this.iconUrl,
  });

  @override
  State<AudioViewerWidget> createState() => _AudioViewerWidgetState();
}

class _AudioViewerWidgetState extends State<AudioViewerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  String? _errorMessage;

  // Store subscriptions to cancel them properly
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  @override
  void didUpdateWidget(AudioViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if URL changes
    if (oldWidget.url != widget.url) {
      _initializeAudio();
    }
  }

  /// Check if the URL is a local file path
  bool _isLocalFile(String url) {
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  Future<void> _initializeAudio() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      // Cancel existing subscriptions
      await _cancelSubscriptions();

      // Stop any existing playback
      await _audioPlayer.stop();

      final isLocal = _isLocalFile(widget.url);
      debugPrint('🎵 Initializing audio from ${isLocal ? "local file" : "network URL"}: ${widget.url}');

      // Listen to player state changes
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      // Listen to duration changes
      _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      // Listen to position changes
      _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      // Listen to completion
      _completeSubscription = _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      // Set the audio source based on type
      if (isLocal) {
        await _audioPlayer.setSource(DeviceFileSource(widget.url));
      } else {
        await _audioPlayer.setSource(UrlSource(widget.url));
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      debugPrint('✅ Audio initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load audio: $e';
        });
      }
    }
  }

  /// Cancel all stream subscriptions
  Future<void> _cancelSubscriptions() async {
    await _playerStateSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _completeSubscription?.cancel();
    
    _playerStateSubscription = null;
    _durationSubscription = null;
    _positionSubscription = null;
    _completeSubscription = null;
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint('❌ Error toggling play/pause: $e');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('❌ Error seeking: $e');
    }
  }

  Future<void> _skipForward() async {
    final newPosition = _position + const Duration(seconds: 10);
    if (newPosition < _duration) {
      await _seekTo(newPosition);
    } else {
      await _seekTo(_duration);
    }
  }

  Future<void> _skipBackward() async {
    final newPosition = _position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      await _seekTo(newPosition);
    } else {
      await _seekTo(Duration.zero);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    // Cancel all subscriptions before disposing player
    _cancelSubscriptions();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = widget.iconUrl != null && widget.iconUrl!.isNotEmpty;

    if (_isLoading) {
      return _buildLoading();
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            
            // Display image if iconUrl is provided
            if (hasImage) ...[
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  constraints: const BoxConstraints(
                    maxWidth: 300,
                    maxHeight: 300,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.iconUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],

            // Audio player controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // Progress slider
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16.0,
                          ),
                          activeTrackColor: AppColors.primaryBlue,
                          inactiveTrackColor: theme.brightness == Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          thumbColor: AppColors.primaryBlue,
                          overlayColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble(),
                          min: 0.0,
                          max: _duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            _seekTo(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Skip backward button
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        iconSize: 36,
                        onPressed: _skipBackward,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                      ),
                      const SizedBox(width: 24),

                      // Play/Pause button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          iconSize: 48,
                          color: Colors.white,
                          onPressed: _togglePlayPause,
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Skip forward button
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        iconSize: 36,
                        onPressed: _skipForward,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
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
          Text('Loading audio...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Failed to load audio',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeAudio,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

