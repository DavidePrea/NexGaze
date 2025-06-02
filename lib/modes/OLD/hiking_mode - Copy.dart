// hiking_mode.dart completo con aggiunta calcolo e visualizzazione velocità
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

class Mode1Screen extends StatefulWidget {
  const Mode1Screen({super.key});

  @override
  State<Mode1Screen> createState() => _Mode1ScreenState();
}

class _Mode1ScreenState extends State<Mode1Screen> {
  LatLng? _currentPosition;
  LatLng? _lastPosition;
  double? _altitude;
  double _totalDistance = 0.0;
  double? _bearing;
  double? _magneticDirection;
  double? _speed;
  DateTime? _lastTime;

  late Timer _timer;
  String _currentTime = DateFormat.Hm().format(DateTime.now()); // Solo ore e minuti
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  Stream<StepCount>? _stepCountStream;
  int _initialSteps = 0;
  int _steps = 0;

  String? _temperature;
  String? _weatherTrend;

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
        _altitude = position.altitude;
        // Centra la mappa sulla nuova posizione con zoom corrente
        if (_currentPosition != null) {
          _mapController.move(_currentPosition!, 17.0); // Usa uno zoom fisso (17) per semplicità
        }
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALT',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              _altitude != null ? '${_altitude!.toStringAsFixed(1)} m' : '--',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        if (_weatherTrend != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'NEXT 6H',
                style: TextStyle(color: Colors.white, fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo nero per uniformità
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
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
                  child: Image.asset('assets/icons/hiking.png', height: 50),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition ?? const LatLng(46.0121, 8.9608),
                initialZoom: 17,
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
          ),
        ],
      ),
    );
  }
}