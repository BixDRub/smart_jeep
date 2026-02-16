import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();

    // REPLACE THIS WITH VIDEO===============================================================================
    _videoController = VideoPlayerController.asset('VIDEO_PATH_HERE_LOLLLLL.mp4')
      ..initialize().then((_) {
        setState(() => _videoInitialized = true);
        _videoController.play();
        _startFadeOutTimer();
      }).catchError((error) {
        debugPrint('Video error: $error');
        _navigateToHome();
      });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
  }

  void _startFadeOutTimer() {
    // Fade out when video ends or after a max duration
    final videoDuration = _videoController.value.duration.inMilliseconds;
    final fadeDelay = videoDuration - 500; // Start fade 500ms before end

    Future.delayed(Duration(milliseconds: fadeDelay.clamp(0, videoDuration)),
        () {
      if (mounted) {
        _fadeController.forward().then((_) {
          _navigateToHome();
        });
      }
    });
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
        
          if (_videoInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

         
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
