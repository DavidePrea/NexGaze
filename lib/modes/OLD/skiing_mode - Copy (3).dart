import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../screens/setup_screen.dart'; // Importa per accedere a GlobalSettings
import '../screens/menu_screen.dart'; // Importa per la navigazione verso MenuScreen

class Mode4Screen extends StatefulWidget {
  const Mode4Screen({super.key});

  @override
  State<Mode4Screen> createState() => _Mode4ScreenState();
}

class _Mode4ScreenState extends State<Mode4Screen> {
  LatLng? _currentPosition;
  LatLng? _lastPosition;
  double? _altitude;
  double _totalDistance = 0.0;
  double? _speed;
  double? _maxSpeed = 0.0; // Variabile per la velocità massima
  DateTime? _lastTime;
  String _currentTime = DateFormat.Hm().format(DateTime.now()); // Solo ore e minuti
  StreamSubscription<Position>? _positionStream;
  late Timer _clockTimer;

  // Variabili per il ciclo della mappa
  bool _isMapVisible = true; // Controlla se la mappa è visibile
  bool _isMapInverted = true; // Controlla se la mappa ha i colori invertiti
  int _cycleStep = 0; // Traccia il passo del ciclo (0: invertito, 1: nascosto, 2: normale, 3: nascosto, 4: invertito)

  // Variabili per i dati meteo
  String? _temperature;
  String? _weatherTrend;

  // MethodChannel per i tasti del telecomando
  static const platform = MethodChannel('com.example.app/keyevents');

  final LatLng center = LatLng(46.83688531474294, 9.214954371888968);

  @override
  void initState() {
    super.initState();
    // Forza la modalità landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    _startLocationUpdates();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat.Hm().format(DateTime.now());
        });
      }
    });

    // Inizializza il listener per i tasti del telecomando
    _listenForKeyEvents();
  }

  @override
  void dispose() {
    // Ripristina le orientazioni consentite
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _positionStream?.cancel();
    _clockTimer.cancel();
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
          _cycleStep = (_cycleStep + 1) % 5; // Ciclo: 0 -> 1 -> 2 -> 3 -> 4 -> 0
          switch (_cycleStep) {
            case 0: // Mappa visibile, colori invertiti
              _isMapVisible = true;
              _isMapInverted = true;
              break;
            case 1: // Mappa nascosta
              _isMapVisible = false;
              _isMapInverted = true; // Stato precedente non rilevante
              break;
            case 2: // Mappa visibile, colori normali
              _isMapVisible = true;
              _isMapInverted = false;
              break;
            case 3: // Mappa nascosta
              _isMapVisible = false;
              _isMapInverted = false; // Stato precedente non rilevante
              break;
            case 4: // Mappa visibile, colori invertiti (riparte il ciclo)
              _isMapVisible = true;
              _isMapInverted = true;
              break;
          }
          break;
        case 66: // Tasto centrale (KeyUp, code=66)
        // Resetta DIST e MAX
          _totalDistance = 0.0;
          _maxSpeed = 0.0;
          break;
      }
    });
  }

  void _startLocationUpdates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((position) {
      final newLatLng = LatLng(position.latitude, position.longitude);
      final now = DateTime.now();
      final distanceMoved = _lastPosition != null
          ? Geolocator.distanceBetween(
        newLatLng.latitude,
        newLatLng.longitude,
        _lastPosition!.latitude,
        _lastPosition!.longitude,
      )
          : 0.0;

      final duration = _lastTime != null ? now.difference(_lastTime!).inSeconds : 0;

      if (distanceMoved >= 3.0 && duration > 0) {
        _totalDistance += distanceMoved;
        _speed = (distanceMoved / duration) * 3.6; // Converti in km/h
        // Aggiorna la velocità massima
        if (_speed != null && (_maxSpeed == null || _speed! > _maxSpeed!)) {
          _maxSpeed = _speed;
        }
        _lastPosition = newLatLng;
        _lastTime = now;
      } else if (_lastPosition == null || _lastTime == null) {
        _lastPosition = newLatLng;
        _lastTime = now;
      }

      if (mounted) {
        setState(() {
          _currentPosition = newLatLng;
          _altitude = position.altitude;
        });
      }

      // Aggiorna i dati meteo
      _fetchWeather(position.latitude, position.longitude);
    });
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

  Widget _buildInfoColumn() {
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
                  'ALT',
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
                  _altitude != null ? _altitude!.toStringAsFixed(1) : '--',
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
                  'MAX',
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
                  _maxSpeed != null ? _maxSpeed!.toStringAsFixed(1) : '--',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo nero per uniformità
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: _isMapVisible ? 2 : 1, // Se la mappa è nascosta, riduci lo spazio a sinistra
                child: Stack(
                  children: [
                    Positioned(
                      top: 16,
                      left: 16,
                      child: _buildInfoColumn(),
                    ),
                    if (_isMapVisible) // Mostra _buildRightInfo a destra della sezione sinistra solo se la mappa è visibile
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _buildRightInfo(),
                      ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: GlobalSettings.tapIconsToExit
                            ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const MenuScreen()),
                          );
                        }
                            : null, // Nessuna azione se tapIconsToExit è false
                        child: Image.asset(
                          'assets/icons/skiing.png',
                          height: 40,
                        ),
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
                      stops: [0.0, 30.0 / 200.0], // Sfumatura a 30px
                    ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: _isMapInverted
                      ? ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -1, 0, 0, 0, 255, // R
                      0, -1, 0, 0, 255, // G
                      0, 0, -1, 0, 255, // B
                      0, 0, 0, 1, 0, // A
                    ]),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          'https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.miaapp',
                        ),
                      ],
                    ),
                  )
                      : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                        'https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.miaapp',
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
        ],
      ),
    );
  }
}