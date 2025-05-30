//46.0121, 8.9608

// mode_3_screen.dart: aggiunto supporto TTS "Go my friend..."
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/heart_monitor/heart_monitor_controller.dart';
import '../widgets/heart_monitor/heart_monitor_widget.dart';

class Mode3Screen extends StatefulWidget {
  const Mode3Screen({super.key});

  @override
  State<Mode3Screen> createState() => _Mode3ScreenState();
}

class _Mode3ScreenState extends State<Mode3Screen> {
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  LatLng? _lastPosition;
  DateTime? _lastTime;
  double _totalDistance = 0.0;
  double? _speed;
  double? _bearing;
  String _currentTime = DateFormat.Hms().format(DateTime.now());

  LatLng? _destination;
  double? _distanceToDestination;
  final List<double> _recentSpeeds = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _positionStream;
  late Timer _clockTimer;
  final latlong.Distance _distance = const latlong.Distance();
  bool _mapVisible = false;
  bool _followUser = true;
  Timer? _mapInteractionTimer;
  final FlutterTts _tts = FlutterTts();

  // Dichiarazione del controller per il battito cardiaco
  late HeartMonitorController _heartController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _heartController = HeartMonitorController();
    _heartController.startMonitoring(); // Avvia il monitoraggio
    _retryGoogleMap();
    _startLocationUpdates();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = DateFormat.Hms().format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _clockTimer.cancel();
    _mapInteractionTimer?.cancel();
    _heartController.stopMonitoring(); // Ferma il monitoraggio
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future.delayed(const Duration(milliseconds: 500), _retryGoogleMap);
  }

  void _retryGoogleMap() async {
    setState(() => _mapVisible = false);
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _mapVisible = true);
  }

  void _startLocationUpdates() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((position) {
      final newLatLng = LatLng(position.latitude, position.longitude);
      final now = DateTime.now();
      final distanceMoved = _lastPosition != null
          ? _distance(
          latlong.LatLng(newLatLng.latitude, newLatLng.longitude),
          latlong.LatLng(_lastPosition!.latitude, _lastPosition!.longitude))
          : 0.0;

      final duration = _lastTime != null ? now.difference(_lastTime!).inSeconds : 0;

      if (distanceMoved >= 3.0 && duration > 0) {
        _totalDistance += distanceMoved;
        _speed = (distanceMoved / duration) * 3.6;
        _recentSpeeds.add(_speed!);
        if (_recentSpeeds.length > 10) {
          _recentSpeeds.removeAt(0);
        }
        _bearing = Geolocator.bearingBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          newLatLng.latitude,
          newLatLng.longitude,
        );
        _lastPosition = newLatLng;
        _lastTime = now;
        if (_destination != null) {
          _getRoute();
        }
      } else if (_lastPosition == null || _lastTime == null) {
        _lastPosition = newLatLng;
        _lastTime = now;
      }

      setState(() {
        _currentPosition = newLatLng;
      });

      if (_followUser && _mapController != null) {
        _mapController.getZoomLevel().then((currentZoom) {
          _mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newLatLng,
                zoom: currentZoom,
                bearing: _bearing ?? 0,
              ),
            ),
          );
        });
      }
    });
  }

  Future<void> _getRoute() async {
    if (_currentPosition == null || _destination == null) return;
    const String apiKey = 'AIzaSyAZShF7hqY0Gc5iW5Ce4giT6HBBPAJAnZo';
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&destination=${_destination!.latitude},${_destination!.longitude}'
            '&mode=bicycling'
            '&key=$apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isEmpty) {
          debugPrint('Nessun percorso trovato.');
          setState(() {
            _distanceToDestination = null;
          });
          return;
        }

        final points = PolylinePoints().decodePolyline(
          data['routes'][0]['overview_polyline']['points'],
        );
        final List<LatLng> polylineCoordinates =
        points.map((e) => LatLng(e.latitude, e.longitude)).toList();

        double totalDistance = 0.0;
        for (int i = 0; i < polylineCoordinates.length - 1; i++) {
          totalDistance += Geolocator.distanceBetween(
            polylineCoordinates[i].latitude,
            polylineCoordinates[i].longitude,
            polylineCoordinates[i + 1].latitude,
            polylineCoordinates[i + 1].longitude,
          );
        }

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));
          _distanceToDestination = totalDistance;
        });
      } else {
        debugPrint('Errore nella richiesta API: ${response.statusCode}');
        setState(() {
          _distanceToDestination = null;
        });
      }
    } catch (e) {
      debugPrint('Errore durante la chiamata API: $e');
      setState(() {
        _distanceToDestination = null;
      });
    }
  }

  double _calculateAverageSpeed() {
    if (_recentSpeeds.isEmpty) return 0.0;
    return _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
  }

  String _calculateETA() {
    if (_distanceToDestination == null || _recentSpeeds.isEmpty) return '--';
    final averageSpeed = _calculateAverageSpeed();
    if (averageSpeed == 0) return '--';
    final etaMinutes = (_distanceToDestination! / (averageSpeed * 1000 / 60));
    return etaMinutes.toStringAsFixed(0);
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
              'SPEED',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '${_speed != null ? _speed!.toStringAsFixed(1) : '--'} km/h',
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
              'DEST',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '${_distanceToDestination != null ? _distanceToDestination!.toStringAsFixed(1) : '--'} m',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ETA',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '${_calculateETA()} min',
              style: const TextStyle(color: Colors.white, fontSize: 24),
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
        // Aggiungi qui eventuali altri dati, se necessario
        const SizedBox(height: 12),
        HeartMonitorWidget(controller: _heartController),
      ],
    );
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentPosition ?? const LatLng(46.0121, 8.9608),
        zoom: 14,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onCameraMoveStarted: () {
        _followUser = false;
        _mapInteractionTimer?.cancel();
        _mapInteractionTimer = Timer(const Duration(seconds: 5), () {
          _followUser = true;
        });
      },
      onTap: (LatLng latLng) async {
        setState(() {
          _destination = latLng;
          _markers.removeWhere((m) => m.markerId.value == 'dest');
          _markers.add(Marker(markerId: const MarkerId('dest'), position: latLng));
        });
        _getRoute();
        await _tts.setLanguage('en-US');
        await _tts.setPitch(1.0);
        await _tts.speak("Go my friend, your destination is waiting for you!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination set.')),
        );
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Area nera a sinistra (2/3 dello schermo)
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
                  child: Image.asset('assets/icons/cycling.png', height: 50),
                ),
              ],
            ),
          ),
          // Mappa a destra (1/3 dello schermo)
          Expanded(
            flex: 1,
            child: _mapVisible ? _buildGoogleMap() : const SizedBox(),
          ),
        ],
      ),
    );
  }
}