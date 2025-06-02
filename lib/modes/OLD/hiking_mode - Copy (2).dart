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
import '../screens/setup_screen.dart'; // Importa per accedere a GlobalSettings
import '../screens/menu_screen.dart'; // Importa per la navigazione verso MenuScreen

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
  StreamSubscription<StepCount>? _stepCountSubscription; // Aggiunto per gestire la cancellazione
  StreamSubscription<CompassEvent>? _compassSubscription; // Aggiunto per gestire la cancellazione
  StreamSubscription<Position>? _positionSubscription; // Aggiunto per gestire la cancellazione
  int _initialSteps = 0;
  int _steps = 0;

  String? _temperature;
  String? _weatherTrend;

  late HeartMonitorController _heartController;

  // Variabile per controllare la visibilità della mappa
  bool _isMapVisible = true; // Inizialmente visibile (ON)

  // MethodChannel per i tasti del telecomando
  static const platform = MethodChannel('com.example.app/keyevents');

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
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() => _magneticDirection = event.heading);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateFormat.Hm().format(DateTime.now()));
      }
    });

    // Inizializza il listener per i tasti del telecomando
    _listenForKeyEvents();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _heartController.stopMonitoring();
    _timer.cancel();
    _stepCountSubscription?.cancel(); // Cancella il listener dei passi
    _compassSubscription?.cancel(); // Cancella il listener della bussola
    _positionSubscription?.cancel(); // Cancella il listener della posizione
    super.dispose();
  }

  void _listenForKeyEvents() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "keyDown") {
        int keyCode = call.arguments;
        _handleKeyDown(keyCode);
      }
    });
  }

  void _handleKeyDown(int keyCode) {
    if (!mounted) return; // Evita chiamate se il widget non è montato
    setState(() {
      switch (keyCode) {
        case 25: // KEYCODE_VOLUME_DOWN
          _isMapVisible = !_isMapVisible; // Alterna tra ON e OFF
          break;
      }
    });
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountSubscription = _stepCountStream?.listen(_onStepCount);
    }
  }

  void _onStepCount(StepCount event) {
    if (_initialSteps == 0 && event.steps > 0) {
      _initialSteps = event.steps;
    }
    if (_initialSteps > 0 && mounted) {
      setState(() => _steps = event.steps - _initialSteps);
    }
  }

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
          // Centra la mappa sulla nuova posizione con zoom corrente
          if (_currentPosition != null && _isMapVisible) {
            _mapController.move(_currentPosition!, 17.0); // Usa uno zoom fisso (17) per semplicità
          }
        });
      }

      _fetchWeather(position.latitude, position.longitude);
    });
  }

  String _getDirectionLabel(double? bearing) {
    if (bearing == null) return '--';
    final directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    final index = ((bearing + 22.5) % 360 ~/ 45).toInt();
    return directions[index];
  }

  // Funzione per mappare il nome del colore a un oggetto Color
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

  Widget _buildDirectionIndicator() {
    final double? direction =
    (_bearing != null && _currentPosition != null) ? _bearing : _magneticDirection;
    if (direction == null) {
      return Text(
        '--',
        style: TextStyle(color: _getOverlayColor(), fontSize: 14),
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
          style: TextStyle(color: _getOverlayColor(), fontSize: 14),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DIST',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '${_totalDistance.toStringAsFixed(1)} m',
              style: TextStyle(color: _getOverlayColor(), fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPEED',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              _speed != null ? '${_speed!.toStringAsFixed(1)} km/h' : '--',
              style: TextStyle(color: _getOverlayColor(), fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STEPS',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '$_steps',
              style: TextStyle(color: _getOverlayColor(), fontSize: 24),
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
            Text(
              'ALT',
              style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              _altitude != null ? '${_altitude!.toStringAsFixed(1)} m' : '--',
              style: TextStyle(color: _getOverlayColor(), fontSize: 24),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo nero per uniformità
      body: Row(
        children: [
          Expanded(
            flex: _isMapVisible ? 2 : 1, // Se la mappa è nascosta, riduci lo spazio a sinistra
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildLeftInfo(),
                ),
                if (_isMapVisible) // Mostra _buildRightInfo a destra della sezione sinistra solo se la mappa è visibile
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
                        : null, // Nessuna azione se tapIconsToExit è false
                    child: Image.asset('assets/icons/hiking.png', height: 50),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _isMapVisible ? 1 : 2, // Se la mappa è nascosta, espandi lo spazio a destra
            child: _isMapVisible
                ? ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.0, 30.0 / 200.0], // Sfumatura nei primi 30px
                ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
              },
              blendMode: BlendMode.dstIn,
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
            )
                : Stack(
              children: [
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildRightInfo(), // Sposta a destra quando la mappa è nascosta
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}