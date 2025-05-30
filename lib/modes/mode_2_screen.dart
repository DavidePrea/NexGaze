// modes/mode_2_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

class Mode2Screen extends StatefulWidget {
  const Mode2Screen({super.key});

  @override
  State<Mode2Screen> createState() => _Mode2ScreenState();
}

class _Mode2ScreenState extends State<Mode2Screen> {
  LatLng? _currentPosition;
  LatLng? _lastPosition;
  double _totalDistance = 0.0;
  double? _bearing;
  double? _magneticDirection;
  double? _speed;
  DateTime? _lastTime;

  late Timer _timer;
  String _currentTime = DateFormat.Hm().format(DateTime.now()); // Solo ore e minuti
  final Distance _distance = const Distance();

  Stream<StepCount>? _stepCountStream;
  int _initialSteps = 0;
  int _steps = 0;

  String? _temperature;

  late HeartMonitorController _heartController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _heartController = HeartMonitorController();
    _heartController.startMonitoring();

    _requestPermissions();
    _determinePosition();
    FlutterCompass.events?.listen((event) {
      setState(() => _magneticDirection = event.heading);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateFormat.Hm().format(DateTime.now()));
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _heartController.stopMonitoring();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen(_onStepCount);
    }
  }

  void _onStepCount(StepCount event) {
    if (_initialSteps == 0 && event.steps > 0) {
      _initialSteps = event.steps;
    }
    if (_initialSteps > 0) {
      setState(() => _steps = event.steps - _initialSteps);
    }
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.weatherapi.com/v1/forecast.json?key=000556fcf5894a2e90c93523252205&q=$lat,$lon&hours=4',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _temperature = "${data['current']['temp_c']} °C";
        });
      }
    } catch (e) {
      debugPrint('Weather error: $e');
    }
  }

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

    Geolocator.getPositionStream(
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

      setState(() {
        _currentPosition = newLatLng;
      });

      _fetchWeather(position.latitude, position.longitude);
    });
  }

  String _getDirectionLabel(double? bearing) {
    if (bearing == null) return '--';
    final directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    final index = ((bearing + 22.5) % 360 ~/ 45).toInt();
    return directions[index];
  }

  Widget _buildDirectionIndicator() {
    final double? direction =
        (_bearing != null && _currentPosition != null) ? _bearing : _magneticDirection;
    if (direction == null) {
      return const Text(
        '--',
        style: TextStyle(color: Colors.white, fontSize: 14),
      );
    }
    // Se stiamo usando _magneticDirection (bussola magnetica), inverti l'angolo
    final bool isUsingMagnetic = _bearing == null || _currentPosition == null;
    final angle = (isUsingMagnetic ? -direction : direction) * (math.pi / 180);
    final label = _getDirectionLabel(direction);
    return Column(
      children: [
        Transform.rotate(
          angle: angle,
          child: Image.asset('assets/icons/compass_arrow.png', width: 48),
        ),
        const SizedBox(height: 4),
        Text(
          '${direction.toStringAsFixed(0)}° $label',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLeftInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TIME',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              _currentTime,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIST',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '${_totalDistance.toStringAsFixed(1)} m',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SPEED',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              _speed != null ? '${_speed!.toStringAsFixed(1)} km/h' : '--',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STEPS',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '$_steps',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDirectionIndicator(),
      ],
    );
  }

  Widget _buildRightInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_temperature != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TEMP',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Text(
                "$_temperature",
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ],
          ),
        const SizedBox(height: 16),
        HeartMonitorWidget(controller: _heartController),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo nero per uniformità
      body: Stack(
        children: [
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
            child: Image.asset('assets/icons/running.png', height: 50),
          ),
        ],
      ),
    );
  }
}