import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Aggiunto per TTS
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../widgets/heart_monitor/heart_monitor_controller.dart';
import '../widgets/heart_monitor/heart_monitor_widget.dart';
import '../screens/setup_screen.dart'; // Aggiornato il percorso per accedere a GlobalSettings
import '../screens/menu_screen.dart'; // Importa per la navigazione verso MenuScreen

class Mode2Screen extends StatefulWidget {
  const Mode2Screen({super.key});

  @override
  State<Mode2Screen> createState() => _Mode2ScreenState();
}

class _Mode2ScreenState extends State<Mode2Screen> {
  LatLng? _currentPosition;
  LatLng? _lastPosition;
  double _totalDistance = 2542.0; // Inizializzato a 2542.0 metri
  double? _magneticDirection;
  double? _speed;
  DateTime? _lastTime;

  late Timer _timer;
  String _currentTime = "14:50"; // Orario fisso a 14:50
  final Distance _distance = const Distance();

  Stream<StepCount>? _stepCountStream;
  StreamSubscription<StepCount>? _stepCountSubscription; // Aggiunto per gestire la cancellazione
  StreamSubscription<CompassEvent>? _compassSubscription; // Aggiunto per gestire la cancellazione
  StreamSubscription<Position>? _positionSubscription; // Aggiunto per gestire la cancellazione
  int _initialSteps = 0;
  int _steps = 0;

  String? _temperature;

  late HeartMonitorController _heartController;

  // Variabili per il cronometro
  Timer? _chronoTimer;
  Duration _chronoDuration = const Duration(hours: 0, minutes: 14, seconds: 3); // Inizializzato a 00:14:03
  bool _isChronoRunning = false;
  bool _hasSpokenOneMinute = false; // Per evitare di ripetere il messaggio

  // MethodChannel per i tasti del telecomando
  static const platform = MethodChannel('com.example.app/keyevents');

  // Sintetizzatore vocale
  final FlutterTts _tts = FlutterTts();

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
      // Non aggiorniamo più _currentTime perché deve rimanere fisso a 14:50
    });

    // Inizializza il listener per i tasti del telecomando
    _listenForKeyEvents();

    // Inizializza il TTS
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _heartController.stopMonitoring();
    _timer.cancel();
    _chronoTimer?.cancel();
    _stepCountSubscription?.cancel(); // Cancella il listener dei passi
    _compassSubscription?.cancel(); // Cancella il listener della bussola
    _positionSubscription?.cancel(); // Cancella il listener della posizione
    _tts.stop();
    super.dispose();
  }

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

  void _handleKeyDown(int keyCode) {
    if (!mounted) return; // Evita chiamate se il widget non è montato
    setState(() {
      switch (keyCode) {
        case 24: // KEYCODE_VOLUME_UP (Tasto Su)
          if (_isChronoRunning) {
            // Ferma il cronometro
            _chronoTimer?.cancel();
            _isChronoRunning = false;
          } else {
            // Avvia il cronometro
            _chronoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (mounted) {
                setState(() {
                  _chronoDuration = _chronoDuration + const Duration(seconds: 1);
                  // Controlla se il cronometro raggiunge 60 secondi
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

  void _handleKeyUp(int keyCode) {
    if (!mounted) return; // Evita chiamate se il widget non è montato
    setState(() {
      switch (keyCode) {
        case 66: // KEYCODE_ENTER (Tasto Centrale)
        // Resetta il cronometro
          _chronoTimer?.cancel();
          _isChronoRunning = false;
          _chronoDuration = const Duration(hours: 0, minutes: 14, seconds: 3); // Ripristina a 00:14:03
          _hasSpokenOneMinute = false; // Resetta il flag per il messaggio vocale
          break;
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
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
      setState(() => _steps = (event.steps - _initialSteps) + 2802); // Aggiunge l'offset di 2802
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

  String _getDirectionLabel(double? direction) {
    if (direction == null) return '--';
    final directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    final index = ((direction + 22.5) % 360 ~/ 45).toInt();
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
    final double? direction = _magneticDirection;
    if (direction == null) {
      return Text(
        '--',
        style: TextStyle(color: _getOverlayColor(), fontSize: 14),
      );
    }
    // Usa sempre la direzione magnetica, quindi inverti l'angolo
    final angle = -direction * (math.pi / 180);
    final label = _getDirectionLabel(direction);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48, // Larghezza fissa per l'immagine
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
          width: 80, // Larghezza fissa per il testo
          child: Text(
            '${direction.toStringAsFixed(0)}° $label',
            style: TextStyle(color: _getOverlayColor(), fontSize: 14),
            textAlign: TextAlign.center,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Colors.black, // Sfondo nero per uniformità
      backgroundColor: Color(0xFF00FF00), // Sfondo verde massimo (#00FF00)
      body: Stack(
        children: [
          // Cronometro in alto al centro
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
                  : null, // Nessuna azione se tapIconsToExit è false
              child: Image.asset('assets/icons/running.png', height: 50),
            ),
          ),
        ],
      ),
    );
  }
}