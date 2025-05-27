import 'screens/splash_screen.dart';
import 'screens/menu_screen.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  //runApp(const GpsApp());
  runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
    theme: ThemeData(
      scaffoldBackgroundColor: Colors.black, // Global background color
      fontFamily: 'Downlink', // Global Font
    ),
  home: SplashScreen(), // 👈 Parte da qui
  ));
}

class GpsApp extends StatelessWidget {
  const GpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexGaze',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Downlink'),
      ),
      home: const GpsMapPage(),
    );
  }
}

class GpsMapPage extends StatefulWidget {
  const GpsMapPage({super.key});

  @override
  State<GpsMapPage> createState() => _GpsMapPageState();
}

class _GpsMapPageState extends State<GpsMapPage> {
  LatLng? _currentPosition;
  LatLng? _lastPosition;
  double? _altitude;
  double _totalDistance = 0.0;
  double? _bearing;
  double? _magneticDirection;

  late Timer _timer;
  String _currentTime = DateFormat.Hms().format(DateTime.now());
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  Stream<StepCount>? _stepCountStream;
  int _initialSteps = 0;
  int _steps = 0;

  String? _temperature;
  String? _weatherTrend;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _determinePosition();
    FlutterCompass.events?.listen((event) {
      setState(() => _magneticDirection = event.heading);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateFormat.Hms().format(DateTime.now()));
    });
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
        'https://api.weatherapi.com/v1/forecast.json?key=000556fcf5894a2e90c93523252205&q=$lat,$lon&hours=4');
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
          int severity(int c) =>
              c == 1000 ? 1 : c >= 1003 && c <= 1006 ? 2 : c >= 1063 && c <= 1195 ? 3 : c >= 1210 && c <= 1225 ? 4 : 5;
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
      final speed = position.speed;

      if (_lastPosition != null) {
        final segment = _distance(newLatLng, _lastPosition!);
        if (segment >= 3.0) {
          _totalDistance += segment;
          _bearing = Geolocator.bearingBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              newLatLng.latitude,
              newLatLng.longitude);
          _lastPosition = newLatLng;
        }
      } else {
        _lastPosition = newLatLng;
      }

      if (_mapController.camera != null) {
        _mapController.move(newLatLng, _mapController.camera.zoom);
      }

      setState(() {
        _currentPosition = newLatLng;
        _altitude = position.altitude;
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
    final double? direction = (_bearing != null && _currentPosition != null)
        ? _bearing
        : _magneticDirection;
    final angle = (direction ?? 0) * (math.pi / 180);
    final label = _getDirectionLabel(direction);

    return Column(
      children: [
        Transform.rotate(
          angle: angle,
          child: Image.asset('assets/icons/compass_arrow.png', width: 48),
        ),
        const SizedBox(height: 4),
        Text(
          direction != null ? '${direction.toStringAsFixed(0)}° $label' : '--',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        )
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation != Orientation.landscape) {
            return const Center(child: Text('Please rotate the device to landscape mode'));
          }
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentPosition != null
                                ? 'POS: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'
                                : 'POS: ...',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(_currentTime, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('DIST: ${_totalDistance.toStringAsFixed(1)} m',
                              style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('STEPS: $_steps',
                              style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 8),
                          _buildDirectionIndicator(),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _altitude != null
                                ? 'ALT: ${_altitude!.toStringAsFixed(1)} m'
                                : 'ALT: ...',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 12),
                          if (_temperature != null)
                            Text("TEMP: $_temperature",
                                style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 6),
                          if (_weatherTrend != null)
                            _buildWeatherIcon() ?? Container(),
                        ],
                      ),
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
          );
        },
      ),
    );
  }
}
