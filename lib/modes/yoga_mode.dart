// yoga_mode.dart aggiornato: orologio in alto a sinistra, battiti + cuore in alto a destra
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../widgets/heart_monitor/heart_monitor_controller.dart';
import '../widgets/heart_monitor/heart_monitor_widget.dart';

class Mode5Screen extends StatefulWidget {
  @override
  _Mode5ScreenState createState() => _Mode5ScreenState();
}

class _Mode5ScreenState extends State<Mode5Screen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  late HeartMonitorController _heartController;
  late Timer _clockTimer;
  String _currentTime = DateFormat.Hm().format(DateTime.now());

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _heartController = HeartMonitorController();
    _heartController.startMonitoring();

    _controller = VideoPlayerController.asset('assets/videos/yoga.mp4')
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = DateFormat.Hm().format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartController.stopMonitoring();
    _clockTimer.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              _currentTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: HeartMonitorWidget(controller: _heartController),
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
