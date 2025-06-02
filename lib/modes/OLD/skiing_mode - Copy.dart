import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  DateTime? _lastTime;
  String _currentTime = DateFormat.Hm().format(DateTime.now()); // Solo ore e minuti
  StreamSubscription<Position>? _positionStream;
  late Timer _clockTimer;

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
      setState(() {
        _currentTime = DateFormat.Hm().format(DateTime.now());
      });
    });
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
        _lastPosition = newLatLng;
        _lastTime = now;
      } else if (_lastPosition == null || _lastTime == null) {
        _lastPosition = newLatLng;
        _lastTime = now;
      }

      setState(() {
        _currentPosition = newLatLng;
        _altitude = position.altitude;
      });
    });
  }

  Widget _buildInfoColumn() {
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
      ],
    );
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
                flex: 2,
                child: Stack(
                  children: [
                    Positioned(
                      top: 16,
                      left: 16,
                      child: _buildInfoColumn(),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Image.asset(
                        'assets/icons/skiing.png',
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.miaapp', // personalizza
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