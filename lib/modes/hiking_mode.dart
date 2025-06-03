import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../widgets/heart_monitor/heart_monitor_controller.dart';
import '../widgets/heart_monitor/heart_monitor_widget.dart';
import '../screens/setup_screen.dart'; // Import for accessing GlobalSettings
import '../screens/menu_screen.dart'; // Import for navigation to MenuScreen

// Widget for Mode1Screen, handling hiking mode with map and fitness tracking
class Mode1Screen extends StatefulWidget {
  const Mode1Screen({super.key});

  @override
  State<Mode1Screen> createState() => _Mode1ScreenState();
}

class _Mode1ScreenState extends State<Mode1Screen> {
  LatLng? _currentPosition; // Current GPS position
  LatLng? _lastPosition; // Last recorded GPS position
  double? _altitude; // Current altitude
  double _totalDistance = 0.0; // Total distance traveled
  double? _bearing; // Current bearing
  double? _magneticDirection; // Compass heading
  double? _speed; // Current speed in km/h
  DateTime? _lastTime; // Last position update time

  late Timer _timer; // Timer for periodic updates
  String _currentTime = DateFormat.Hm().format(DateTime.now()); // Current time (hours and minutes)
  final MapController _mapController = MapController(); // Controller for FlutterMap
  final Distance _distance = const Distance(); // Distance calculation utility

  Stream<StepCount>? _stepCountStream; // Stream for step count
  StreamSubscription<StepCount>? _stepCountSubscription; // Subscription for step count stream
  StreamSubscription<CompassEvent>? _compassSubscription; // Subscription for compass stream
  StreamSubscription<Position>? _positionSubscription; // Subscription for position stream
  int _initialSteps = 0; // Initial step count
  int _steps = 0; // Current step count

  String? _temperature; // Current temperature
  String? _weatherTrend; // Weather trend for next 6 hours

  late HeartMonitorController _heartController; // Controller for heart rate monitoring

  bool _isMapVisible = true; // Map visibility flag (default: ON)
  Timer? _autoCenterTimer; // Timer for auto-centering map
  double _currentZoom = 17.0; // Current map zoom level

  // MethodChannel for remote control key events
  static const platform = MethodChannel('com.example.app/keyevents');

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
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateFormat.Hm().format(DateTime.now()));
      }
    });

    // Initialize remote control key listener
    _listenForKeyEvents();

    // Auto-center map after initial position is available
    Future.delayed(const Duration(seconds: 1), () {
      if (_currentPosition != null && mounted) {
        _mapController.move(_currentPosition!, _currentZoom);
      }
    });
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
    _stepCountSubscription?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _autoCenterTimer?.cancel();
    super.dispose();
  }

  // Set up listener for remote control key events
  void _listenForKeyEvents() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "keyDown") {
        int keyCode = call.arguments;
        _handleKeyDown(keyCode);
      }
    });
  }

  // Handle key down events
  void _handleKeyDown(int keyCode) {
    if (!mounted) return;
    setState(() {
      switch (keyCode) {
        case 25: // Volume Down key
          _isMapVisible = !_isMapVisible; // Toggle map visibility
          break;
        case 24: // DPad Up key
          _totalDistance = 0.0; // Reset distance
          _steps = 0; // Reset steps
          break;
      }
    });
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
      setState(() => _steps = event.steps - _initialSteps);
    }
  }

  // Fetch weather data and trend
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
          final codes = (data['forecast']['forecastday'][0]['hour'] as List)
              .take(4)
              .map((h) => h['condition']['code'] as int)
              .toList();
          int severity(int c) => c == 1000
              ? 1
              : c >= 1003 && c <= 1006
              ? 2
              : c >= 1063 && c <= 1195
              ? 3
              : c >= 1210 && c <= 1225
              ? 4
              : 5;
          final severities = codes.map(severity).toList();
          _weatherTrend = severities[0] > severities.last
              ? 'improving'
              : severities[0] < severities.last
              ? 'worsening'
              : 'stable';
        });
      }
    } catch (e) {
      debugPrint('Weather error: $e');
    }
  }

  // Track device position and update metrics
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
          _bearing = Geolocator.bearingBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            newLatLng.latitude,
            newLatLng.longitude,
          );
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
          _altitude = position.altitude;
          _currentZoom = _mapController.camera.zoom;
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/icons/compass_arrow.png', width: 48),
          Text(
            '--',
            style: TextStyle(color: _getOverlayColor(), fontSize: 14),
          ),
        ],
      );
    }
    final angle = -direction * (math.pi / 180);
    final label = _getDirectionLabel(direction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.rotate(
          angle: angle,
          child: Image.asset('assets/icons/compass_arrow.png', width: 48),
        ),
        Text(
          '${direction.toStringAsFixed(0)}° $label',
          style: TextStyle(color: _getOverlayColor(), fontSize: 14),
        ),
      ],
    );
  }

  // Build weather trend icon
  Widget? _buildWeatherIcon() {
    switch (_weatherTrend) {
      case 'improving':
        return Image.asset('assets/icons/sun.png', width: 32, height: 32);
      case 'worsening':
        return Image.asset('assets/icons/rain.png', width: 32, height: 32);
      case 'stable':
        return Image.asset('assets/icons/cloud.png', width: 32, height: 32);
      default:
        return null;
    }
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
            Text(
              'DIST',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
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
            Text(
              'SPEED',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
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
            Text(
              'STEPS',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALT',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _altitude != null ? '${_altitude!.toStringAsFixed(1)}' : '--',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 24),
                ),
                Text(
                  'm',
                  style: TextStyle(color: _getOverlayColor(), fontSize: 14),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        if (_weatherTrend != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'NEXT 6H',
                style: TextStyle(color: _getOverlayColor(), fontSize: 14),
              ),
              const SizedBox(width: 8),
              _buildWeatherIcon() ?? Container(),
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
      backgroundColor: Colors.black, // Black background
      body: Row(
        children: [
          // Left area, adjusts size based on map visibility
          Expanded(
            flex: _isMapVisible ? 2 : 1,
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildLeftInfo(),
                ),
                if (_isMapVisible)
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
                    child: Image.asset('assets/icons/hiking.png', height: 50),
                  ),
                ),
              ],
            ),
          ),
          // Right area, contains map or right info when map is hidden
          Expanded(
            flex: _isMapVisible ? 1 : 2,
            child: GestureDetector(
              onTap: () {
                _autoCenterTimer?.cancel();
                _autoCenterTimer = Timer(const Duration(seconds: 5), () {
                  if (_currentPosition != null && mounted) {
                    _mapController.move(_currentPosition!, _currentZoom);
                  }
                });
              },
              onScaleStart: (_) => _autoCenterTimer?.cancel(),
              child: _isMapVisible
                  ? ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Colors.transparent, Colors.black],
                          stops: [0.0, 30.0 / 200.0], // Fade effect in first 30px
                        ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                      },
                      blendMode: BlendMode.dstIn,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentPosition ?? const LatLng(46.0121, 8.9608),
                          initialZoom: _currentZoom,
                          onPositionChanged: (position, hasGesture) {
                            if (hasGesture) {
                              _autoCenterTimer?.cancel();
                              _autoCenterTimer = Timer(const Duration(seconds: 5), () {
                                if (_currentPosition != null && mounted) {
                                  _mapController.move(_currentPosition!, _currentZoom);
                                }
                              });
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://wmts10.geo.admin.ch/1.0.0/ch.swisstopo.swisstlm3d-karte-farbe/default/current/3857/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.gps_app',
                          ),
                          if (_currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentPosition!,
                                  width: 30,
                                  height: 30,
                                  child: const Icon(Icons.location_pin, color: Colors.red, size: 30),
                                ),
                              ],
                            ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _buildRightInfo(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}