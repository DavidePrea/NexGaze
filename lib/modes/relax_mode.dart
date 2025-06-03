import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

// Widget for Mode6Screen, handling video playback for relaxation mode
class Mode6Screen extends StatefulWidget {
  @override
  _Mode6ScreenState createState() => _Mode6ScreenState();
}

class _Mode6ScreenState extends State<Mode6Screen> {
  late VideoPlayerController _controller; // Controller for video playback
  bool _isInitialized = false; // Flag to track video initialization

  @override
  void initState() {
    super.initState();

    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize video player with forest video asset
    _controller = VideoPlayerController.asset('assets/videos/forest.mp4')
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play(); // Start video playback
      });
  }

  @override
  void dispose() {
    // Clean up video controller
    _controller.dispose();

    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  // Build the main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isInitialized
          ? Stack(
              children: [
                // Center video player with correct aspect ratio
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                // Relaxation icon at bottom-left
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Image.asset(
                    'assets/icons/relax.png',
                    height: 50,
                  ),
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()), // Show loading indicator until video is ready
    );
  }
}