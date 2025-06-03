import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Added for text-to-speech
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../widgets/heart_monitor/heart_monitor_controller.dart';
import '../widgets/heart_monitor/heart_monitor_widget.dart';
import '../screens/setup_screen.dart'; // Updated path for GlobalSettings
import '../screens/menu_screen.dart'; // Import for navigation to MenuScreen

// Widget for Mode2Screen, handling fitness tracking functionality
class Mode2Screen extends StatefulWidget {
  const Mode2Screen({super.key});

  @override
  State<Mode2Screen> createState() => _Mode2ScreenState();
}

class _Mode2ScreenState extends State<Mode2Screen> {
  LatLng? _currentPosition; // Current GPS position
  LatLng? _lastPosition; // Last recorded GPS position
  double _totalDistance = 2542.0; // Initialized total distance in meters
  double? _magneticDirection; // Compass heading
  double? _speed; // Current speed in km/h
  DateTime? _lastTime; // Last position update time

  late Timer _timer; // Timer for periodic updates
  String _currentTime = "14:50"; // Fixed time display
  final Distance _distance = const Distance(); // Distance calculation utility

  Stream<StepCount>? _stepCountStream; // Stream for step count
  StreamSubscription<StepCount>? _stepCountSubscription; // Subscription for step count stream
  StreamSubscription<CompassEvent>? _compassSubscription; // Subscription for compass stream
  StreamSubscription<Position>? _positionSubscription; // Subscription for position stream
  int _initialSteps = 0; // Initial step count
  int _steps = 0; // Current step count

  String? _temperature; // Current temperature

  late HeartMonitorController _heartController; // Controller for heart rate monitoring

  // Stopwatch variables
  Timer? _chronoTimer; // Timer for stopwatch
  Duration _chronoDuration = const Duration(hours: 0, minutes: 14, seconds: 3); // Initialized stopwatch time
  bool _isChronoRunning = false; // Stopwatch running state
  bool _hasSpokenOneMinute = false; // Flag to prevent repeating one-minute announcement

  // MethodChannel for remote control key events
  static const platform = MethodChannel('com.example.app/keyevents');

  // Text-to-speech synthesizer
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();

    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize heart rate monitoring
    _heartController = HeartMonitorController();
    _heartController.startMonitoring();

    // Request permissions and initialize sensors
    _requestPermissions();
    _determinePosition();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() => _magneticDirection = event.heading);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Timer for periodic updates (time not updated to keep 14:50)
    });

    // Initialize remote control key listener
    _listenForKeyEvents();

    // Initialize text-to-speech
    _initTts();
  }

  // Initialize text-to-speech settings
  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Clean up resources
    _heartController.stopMonitoring();
    _timer.cancel();
    _chronoTimer?.cancel();
    _stepCountSubscription?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _tts.stop();
    super.dispose();
  }

  // Set up listener for remote control key events
  void _listenForKeyEvents() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "keyDown") {
        int keyCode = call.arguments;
        _handleKeyDown(keyCode);
      } else if (call.method == "keyUp") {
        int keyCode = call.arguments;
        _handleKeyUp(keyCode);
      }
    });
  }

  // Handle key down events
  void _handleKeyDown(int keyCode) {
    if (!mounted) return;
    setState(() {
      switch (keyCode) {
        case 24: // Volume Up key
          if (_isChronoRunning) {
            // Stop stopwatch
            _chronoTimer?.cancel();
            _isChronoRunning = false;
          } else {
            // Start stopwatch
            _chronoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (mounted) {
                setState(() {
                  _chronoDuration = _chronoDuration + const Duration(seconds: 1);
                  // Announce one minute if enabled
                  if (_chronoDuration.inSeconds == 60 && !_hasSpokenOneMinute) {
                    if (GlobalSettings.voiceNotificationsEnabled) {
                      _tts.speak("One minute");
                    }
                    _hasSpokenOneMinute = true;
                  }
                });
              }
            });
            _isChronoRunning = true;
          }
          break;
      }
    });
  }

  // Handle key up events
  void _handleKeyUp(int keyCode) {
    if (!mounted) return;
    setState(() {
      switch (keyCode) {
        case 66: // Enter key
          // Reset stopwatch
          _chronoTimer?.cancel();
          _isChronoRunning = false;
          _chronoDuration = const Duration(hours: 0, minutes: 14, seconds: 3);
          _hasSpokenOneMinute = false;
          break;
      }
    });
  }

  // Format duration for stopwatch display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // Request activity recognition permission for step counting
  Future<void> _requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountSubscription = _stepCountStream?.listen(_onStepCount);
    }
  }

  // Handle step count updates
  void _onStepCount(StepCount event) {
    if (_initialSteps == 0 && event.steps > 0) {
      _initialSteps = event.steps;
    }
    if (_initialSteps > 0 && mounted) {
      setState(() => _steps = (event.steps - _initialSteps) + 2802);
    }
  }

  // Fetch weather data for current location
  Future<void> _fetchWeather(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.weatherapi.com/v1/forecast.json?key=000556fcf5894a2e90c93523252205&q=$lat,$lon&hours=4',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _temperature = "${data['current']['temp_c']} °C";
        });
      }
    } catch (e) {
      debugPrint('Weather error: $e');
    }
  }

  // Determine and track device position
  Future<void> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((position) {
      final newLatLng = LatLng(position.latitude, position.longitude);
      final now = DateTime.now();
      if (_lastPosition != null && _lastTime != null) {
        final segment = _distance(newLatLng, _lastPosition!);
        final duration = now.difference(_lastTime!).inSeconds;
        if (segment >= 3.0 && duration > 0) {
          _totalDistance += segment;
          _speed = (segment / duration) * 3.6;
          _lastPosition = newLatLng;
          _lastTime = now;
        }
      } else {
        _lastPosition = newLatLng;
        _lastTime = now;
      }

      if (mounted) {
        setState(() {
          _currentPosition = newLatLng;
        });
      }

      _fetchWeather(position.latitude, position.longitude);
    });
  }

  // Convert compass heading to direction label
  String _getDirectionLabel(double? direction) {
    if (direction == null) return '--';
    final directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    final index = ((direction + 22.5) % 360 ~/ 45).toInt();
    return directions[index];
  }

  // Map color name to Color object
  Color _getOverlayColor() {
    switch (GlobalSettings.overlayColor.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.white;
    }
  }

  // Build compass direction indicator
  Widget _buildDirectionIndicator() {
    final double? direction = _magneticDirection;
    if (direction == null) {
      return Text(
        '--',
        style: TextStyle(color: _getOverlayColor(), fontSize: 14),
      );
    }
    final angle = -direction * (math.pi / 180);
    final label = _getDirectionLabel(direction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Align(
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: angle,
              child: Image.asset('assets/icons/compass_arrow.png', width: 48),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            '${direction.toStringAsFixed(0)}° $label',
            style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Build left-side information panel
  Widget _buildLeftInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIME',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              _currentTime,
              style: TextStyle(color: _getOverlayColor(), fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIST',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _totalDistance.toStringAsFixed(1),
                  style: TextStyle(color: _getOverlayColor(), fontSize: 24),
                ),
                const SizedBox(width: 4),
                Text(
                  'm',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPEED',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _speed != null ? _speed!.toStringAsFixed(1) : '--',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 24),
                ),
                const SizedBox(width: 4),
                Text(
                  'km/h',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEPS',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_steps',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 24),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDirectionIndicator(),
      ],
    );
  }

  // Build right-side information panel
  Widget _buildRightInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_temperature != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEMP',
                style: TextStyle(color: _getOverlayColor(), fontSize: 14),
              ),
              const SizedBox(width: 8),
              Text(
                "$_temperature",
                style: TextStyle(color: _getOverlayColor(), fontSize: 24),
              ),
            ],
          ),
        const SizedBox(height: 16),
        HeartMonitorWidget(controller: _heartController),
      ],
    );
  }

  // Build the main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF00FF00), // Bright green background
      body: Stack(
        children: [
          // Stopwatch at top center
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CRONO',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                ),
                Text(
                  _formatDuration(_chronoDuration),
                  style: TextStyle(color: _getOverlayColor(), fontSize: 24),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _buildLeftInfo(),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _buildRightInfo(),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: GestureDetector(
              onTap: GlobalSettings.tapIconsToExit
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const MenuScreen()),
                      );
                    }
                  : null,
              child: Image.asset('assets/icons/running.png', height: 50),
            ),
          ),
        ],
      ),
    );
  }
}