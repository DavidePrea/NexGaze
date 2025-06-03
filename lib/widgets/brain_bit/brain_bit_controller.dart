import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:neurosdk2/neurosdk2.dart' as bb;
import 'package:em_st_artifacts/em_st_artifacts.dart' as em;

/// Controller for BrainBit device with console debug output for each step (scanning, device discovery, connection, calibration, data processing).
class BrainBitController extends ChangeNotifier
    implements ValueListenable<BrainBitController> {
  /// Returns the controller instance as the listenable value.
  @override
  BrainBitController get value => this;

  // ----- Public States -----
  /// Indicates whether the controller is currently scanning for devices.
  bool get isScanning => _isScanning;
  /// Indicates whether the controller is connected to a BrainBit device.
  bool get isConnected => _isConnected;
  /// Indicates whether the device is fully calibrated.
  bool get isCalibrated => _calibrated;

  /// Returns the current calibration progress (0.0 to 1.0).
  double get calibrationProgress => _calibPercent;
  /// Checks if the EEG signal has been lost (no packets for over 2 seconds).
  bool get signalLost =>
      DateTime.now().difference(_lastPacket) > const Duration(seconds: 2);

  /// Returns the current attention level, if available.
  double? get attention => _attention;
  /// Returns the current relaxation level, if available.
  double? get relax => _relax;
  /// Alias for relaxation level, representing meditation state.
  double? get meditation => _relax;

  /// Returns an unmodifiable list of discovered BrainBit devices.
  List<bb.FSensorInfo> get devices => List.unmodifiable(_devices);

  /// Returns the name or address of the connected device, if any.
  String? get connectedDeviceName =>
      _connectedDevice?.name.isNotEmpty == true
          ? _connectedDevice!.name
          : _connectedDevice?.address;

  // ----- Private Fields -----
  /// Flag to enable automatic connection to the first discovered device.
  final bool _autoConnect;
  /// Scanner instance for discovering BrainBit devices.
  late bb.Scanner _scanner;
  /// Tracks whether the scanner has been created.
  bool _scannerCreated = false;
  /// Tracks whether scanning is active.
  bool _isScanning = false;
  /// Tracks whether a device is connected.
  bool _isConnected = false;

  /// BrainBit sensor instance for EEG data acquisition.
  bb.BrainBit? _sensor;
  /// Subscription to the EEG signal data stream.
  StreamSubscription<List<bb.BrainBitSignalData>>? _sigSub;

  /// EmotionalMath instance for processing EEG data (renamed from _calibration).
  em.EmotionalMath? _emo;
  /// Tracks calibration completion status.
  bool _calibrated = false;
  /// Current calibration progress percentage.
  double _calibPercent = 0.0;

  /// Timestamp of the last received EEG packet.
  DateTime _lastPacket = DateTime.fromMillisecondsSinceEpoch(0);

  /// Buffer for storing attention values for averaging.
  final List<double> _attBuf = [];
  /// Buffer for storing relaxation values for averaging.
  final List<double> _relBuf = [];
  /// Size of the averaging buffer.
  final int _bufSize = 3;
  /// Current averaged attention value.
  double? _attention;
  /// Current averaged relaxation value.
  double? _relax;

  /// List of discovered BrainBit devices.
  final List<bb.FSensorInfo> _devices = [];
  /// Information about the currently connected device.
  bb.FSensorInfo? _connectedDevice;

  /// BuildContext for displaying SnackBar notifications.
  final BuildContext? _context;

  /// Constructor with optional autoConnect and context; autoConnect = false allows manual device selection.
  BrainBitController({bool autoConnect = false, BuildContext? context})
      : _autoConnect = autoConnect,
        _context = context;

  /// Starts the scanner and optionally auto-connects to a device.
  Future<void> startMonitoring() async {
    debugPrint('[BrainBit] Initiating device monitoring');
    await _ensureScanner();
    await _startScan();
  }

  /// Stops the EEG stream and scanner.
  Future<void> stopMonitoring() async {
    debugPrint('[BrainBit] Terminating device monitoring');
    await _disconnect();
    await _stopScan();
  }

  /// Restarts the calibration process.
  void restartCalibration() {
    debugPrint('[BrainBit] Restarting calibration process');
    if (_emo != null) {
      _emo!.startCalibration();
      _calibrated = false;
      _calibPercent = 0.0;
      _attBuf.clear();
      _relBuf.clear();
      notifyListeners();
    }
  }

  /// Connects to a user-selected device, called by the UI.
  Future<void> connectToDevice(bb.FSensorInfo info) async {
    debugPrint('[BrainBit] Attempting connection to: ${info.name} (${info.address})');
    if (_isConnected) {
      debugPrint('[BrainBit] Already connected to: $connectedDeviceName');
      return;
    }
    _connectedDevice = info;
    try {
      await _connect(info).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[BrainBit] Connection timeout for ${info.name}');
        throw Exception('Connection timeout');
      });
    } on em.ArtifactsException catch (e, stackTrace) {
      debugPrint('[BrainBit] ArtifactsException: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
              content: Text('EEG signal error: verify device positioning')),
        );
      }
      _isConnected = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), _startScan);
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[BrainBit] Connection error: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
              content: Text('EEG initialization error: check device and retry')),
        );
      }
      _isConnected = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), _startScan);
      rethrow;
    }
  }

  /// Cleans up resources when the controller is disposed.
  @override
  void dispose() {
    debugPrint('[BrainBit] Disposing controller');
    _sigSub?.cancel();
    _sensor?.dispose();
    if (_scannerCreated) {
      debugPrint('[BrainBit] Stopping scanner during disposal');
      _scanner.stop();
    }
    _emo?.dispose();
    super.dispose();
  }

  /// Initializes the scanner if not already created.
  Future<void> _ensureScanner() async {
    if (_scannerCreated) return;
    debugPrint('[Scanner] Initializing BrainBit scanner');
    _scanner = await bb.Scanner.create([bb.FSensorFamily.leBrainBit]);
    _scanner.sensorsStream.listen((list) {
      debugPrint(
          '[Scanner] Discovered ${list.length} device(s): ${list.map((d) => "${d.name} (${d.address})").join(", ")}');
      _devices.clear();
      _devices.addAll(list);
      if (_autoConnect && list.isNotEmpty && !_isConnected) {
        debugPrint('[Scanner] Auto-connecting to first device: ${list.first.name}');
        _connect(list.first);
      }
      notifyListeners();
    });
    _scannerCreated = true;
  }

  /// Requests Bluetooth and location permissions.
  Future<bool> _ensurePermissions() async {
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final granted = res.values.every((s) => s.isGranted);
    debugPrint('[Scanner] Permissions granted: $granted');
    if (!granted && _context != null) {
      ScaffoldMessenger.of(_context).showSnackBar(
        const SnackBar(content: Text('Bluetooth or location permissions denied')),
      );
    }
    return granted;
  }

  /// Starts scanning for BrainBit devices.
  Future<void> _startScan() async {
    if (_isScanning) return;
    if (!await _ensurePermissions()) {
      debugPrint('[Scanner] Permissions denied, scanning aborted');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
              content: Text('Bluetooth or location permissions required')),
        );
      }
      throw Exception('Bluetooth permissions denied');
    }
    debugPrint('[Scanner] Starting device scan');
    await _scanner.start();
    _isScanning = true;
    notifyListeners();
  }

  /// Stops scanning for devices.
  Future<void> _stopScan() async {
    if (!_isScanning) return;
    debugPrint('[Scanner] Stopping device scan');
    await _scanner.stop();
    _isScanning = false;
    notifyListeners();
  }


  /// Establishes a connection to a specified device.
  Future<void> _connect(bb.FSensorInfo info) async {
    if (_isConnected) return;
    debugPrint('[Scanner] Stopping scan to initiate connection');
    await _stopScan();

    try {
      debugPrint('[Scanner] Creating sensor for ${info.name}');
      _sensor = await _scanner.createSensor(info) as bb.BrainBit;
      debugPrint('[Scanner] Starting EEG signal acquisition');
      await _sensor!.execute(bb.FSensorCommand.startSignal);
      debugPrint('[Scanner] Signal acquisition started successfully');
      _isConnected = true;
      debugPrint('[Scanner] Connected to device: ${info.name}');

      // Delays EmotionalMath initialization to stabilize connection.
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('[Scanner] Initializing EmotionalMath after delay');
      _initEmotions();

      _sigSub = _sensor!.signalDataStream.listen(
        _onEegPacket,
        onDone: () {
          debugPrint('[EEG] EEG stream closed');
          _handleDisconnect();
        },
        onError: (err) {
          debugPrint('[EEG] EEG stream error: $err');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e, stackTrace) {
      debugPrint('[Scanner] Connection error: $e\nStackTrace: $stackTrace');
      _isConnected = false;
      _sensor?.dispose();
      _sensor = null;
      Future.delayed(const Duration(seconds: 3), _startScan);
      rethrow;
    }
    notifyListeners();
  }

  /// Disconnects from the current device.
  Future<void> _disconnect() async {
    if (!_isConnected) return;
    debugPrint('[Scanner] Disconnecting from device');
    await _sigSub?.cancel();
    _sensor?.execute(bb.FSensorCommand.stopSignal);
    _sensor?.dispose();
    _sensor = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Handles unexpected disconnection and restarts scanning.
  void _handleDisconnect() {
    debugPrint('[Disconnect] Handling disconnection, restarting scan after 2s');
    _disconnect();
    Future.delayed(const Duration(seconds: 2), _startScan);
  }

 
  /// Initializes EmotionalMath for EEG data processing.
  void _initEmotions() {
    if (_emo != null) return;
    debugPrint('[MathLib] Initializing EmotionalMath');
    try {
      debugPrint('[MathLib] Creating MathLibSettings');
      const sr = 250;
      final mathSettings = em.MathLibSettings(
        samplingRate: sr,
        fftWindow: 1000, // 4-second window for FFT
        processWinFreq: 25,
        nFirstSecSkipped: 6, // Skips initial 6 seconds for stability
        bipolarMode: true,
      );
      debugPrint('[MathLib] MathLibSettings created: $mathSettings');

      debugPrint('[MathLib] Creating EmotionalMath instance');
      final emo = em.EmotionalMath(
        mathSettings,
        em.ArtifactsDetectSetting(hanningWinSpectrum: true),
        em.ShortArtifactsDetectSetting(
            amplArtExtremumBorder: 50), // Increased artifact tolerance
        em.MentalAndSpectralSetting(
          nSecForAveraging: 4,
          nSecForInstantEstimation: 6,
        ),
      );
      debugPrint('[MathLib] EmotionalMath instance created');

      debugPrint('[MathLib] Configuring EmotionalMath');
      emo
        ..setCalibrationLength(6)
        ..setZeroSpectWaves(true, 0, 1, 1, 1, 0)
        ..setSpectNormalizationByBandsWidth(true)
        ..startCalibration();
      debugPrint('[Calibrazione] Started EmotionalMath calibration');
      _emo = emo;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[MathLib] Error initializing EmotionalMath: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
              content: Text('EEG initialization error: check device and retry')),
        );
      }
      rethrow;
    }
  }

  /// Processes received EEG packets.
  void _onEegPacket(List<bb.BrainBitSignalData> packet) {
    debugPrint('[EEG] Received ${packet.length} EEG packets');
    if (_emo == null || packet.isEmpty) {
      debugPrint('[EEG] EmotionalMath null or empty packets');
      return;
    }

    // Skips packets received within 2 seconds of connection to stabilize.
    if (DateTime.now().difference(_lastPacket).inSeconds < 2 &&
        _lastPacket != DateTime.fromMillisecondsSinceEpoch(0)) {
      debugPrint('[EEG] Ignoring initial packets');
      return;
    }

    try {
      _lastPacket = DateTime.now();
      debugPrint('[EEG] Creating EEG samples');

      final samples = packet
          .map((s) => em.RawChanel(
        leftBipolar: s.t3 - s.o1,
        rightBipolar: s.t4 - s.o2,
      ))
          .toList();
      debugPrint('[EEG] Created ${samples.length} samples');

      debugPrint('[EEG] Sending samples to EmotionalMath');
      _emo!.pushBipolars(samples);
      _emo!.processData();
      _emo!.processData();
      debugPrint('[EEG] Samples processed');

      // Updates calibration progress.
      final rawPercent = _emo!.getCalibrationPercents();
      _calibPercent = (rawPercent.clamp(0, 100)) / 100.0;
      debugPrint(
          '[EEG] Calibration progress: ${(_calibPercent * 100).toStringAsFixed(0)}%');

      if (!_calibrated && _emo!.isCalibrationFinished()) {
        _calibrated = true;
        _attBuf.clear();
        _relBuf.clear();
        debugPrint('[Calibrazione] Calibration completed at 100%');
      }
      if (!_calibrated) {
        notifyListeners();
        return;
      }

      // Handles detected artifacts.
      if (_emo!.isArtifactedSequence()) {
        debugPrint('[EEG] Artifact detected (signal lost)');
        _attention = null;
        _relax = null;
        notifyListeners();
        return;
      }

      final md = _emo!.readMentalData();
      if (md.isEmpty) {
        debugPrint('[EEG] No mental data available');
        return;
      }
      final last = md.last;

      _attBuf.add((last.relAttention * 100).clamp(0, 100));
      _relBuf.add((last.relRelaxation * 100).clamp(0, 100));
      if (_attBuf.length > _bufSize) _attBuf.removeAt(0);
      if (_relBuf.length > _bufSize) _relBuf.removeAt(0);

      _attention = _attBuf.reduce((a, b) => a + b) / _attBuf.length;
      _relax = _relBuf.reduce((a, b) => a + b) / _relBuf.length;

      debugPrint(
          '[EEG] Attention: ${_attention!.toStringAsFixed(1)}, Relax: ${_relax!.toStringAsFixed(1)}');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[EEG] Error processing EEG packet: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
              content: Text('EEG processing error: check device and retry')),
        );
      }
      _attention = null;
      _relax = null;
      notifyListeners();
      _handleDisconnect();
    }
  }
}