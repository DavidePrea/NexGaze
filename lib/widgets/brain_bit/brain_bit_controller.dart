import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:neurosdk2/neurosdk2.dart' as bb;
import 'package:em_st_artifacts/em_st_artifacts.dart' as em;

class BrainBitController extends ChangeNotifier {
  late bb.Scanner _scanner;
  List<bb.FSensorInfo> _devices = [];
  final bool _autoConnect;

  bb.BrainBit? _sensor;
  StreamSubscription<List<bb.BrainBitSignalData>>? _sigSub;

  em.EmotionalMath? _emo;
  bool _calibrated = false;

  bool _scannerCreated = false;
  bool _isScanning = false;
  bool _isConnected = false;

  double? _attention;
  double? _relax;

  BrainBitController({bool autoConnect = true}) : _autoConnect = autoConnect;

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isCalibrated => _calibrated;

  List<bb.FSensorInfo> get devices => List.unmodifiable(_devices);

  double? get attention => _attention;
  double? get relax => _relax;
  double? get meditation => _relax;

  Future<void> startMonitoring() async {
    await _ensureScanner();
    await _startScan();
  }

  Future<void> stopMonitoring() async {
    await _disconnect();
    await _stopScan();
  }

  Future<void> _ensureScanner() async {
    if (_scannerCreated) return;

    _scanner = await bb.Scanner.create([bb.FSensorFamily.leBrainBit]);

    _scanner.sensorsStream.listen((list) async {
      _devices = list;

      if (_autoConnect && _devices.isNotEmpty && !_isConnected) {
        try {
          await _connect(_devices.first);
        } catch (_) {}
      }

      notifyListeners();
    });

    _scannerCreated = true;
  }

  Future<bool> _checkBlePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    if (!await _checkBlePermissions()) {
      throw Exception('Permessi BLE negati');
    }
    await _scanner.start();
    _isScanning = true;
    notifyListeners();
  }

  Future<void> _stopScan() async {
    if (!_isScanning) return;
    await _scanner.stop();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> _connect(bb.FSensorInfo info) async {
    if (_isConnected) return;
    await _stopScan();

    _sensor = await _scanner.createSensor(info) as bb.BrainBit;
    await _sensor!.execute(bb.FSensorCommand.startSignal);

    _initEmotions();

    _sigSub = _sensor!.signalDataStream.listen(_onEegPacket);

    _isConnected = true;
    notifyListeners();
  }

  Future<void> _disconnect() async {
    if (!_isConnected) return;
    await _sigSub?.cancel();
    _sigSub = null;

    _sensor?.execute(bb.FSensorCommand.stopSignal);
    _sensor?.dispose();
    _sensor = null;

    _isConnected = false;
    notifyListeners();
  }

  void _initEmotions() {
    if (_emo != null) return;

    const sr = 250;

    final mathSettings = em.MathLibSettings(
      samplingRate: sr,
      fftWindow: 1000,
      processWinFreq: 25,
      nFirstSecSkipped: 4,
      bipolarMode: true,
    );

    final emo = em.EmotionalMath(
      mathSettings,
      em.ArtifactsDetectSetting(hanningWinSpectrum: true),
      em.ShortArtifactsDetectSetting(amplArtExtremumBorder: 25),
      em.MentalAndSpectralSetting(
        nSecForAveraging: 2,
        nSecForInstantEstimation: 4,
      ),
    );

    emo.setCalibrationLength(6);
    emo.setZeroSpectWaves(true, 0, 1, 1, 1, 0);
    emo.setSpectNormalizationByBandsWidth(true);
    emo.startCalibration();

    _emo = emo;
  }

  void _onEegPacket(List<bb.BrainBitSignalData> packet) {
    if (_emo == null || packet.isEmpty) return;

    final samples = packet
        .map((s) => em.RawChanel(
      leftBipolar: s.t3 - s.o1,
      rightBipolar: s.t4 - s.o2,
    ))
        .toList();

    _emo!.pushBipolars(samples);
    _emo!.processData();

    if (!_calibrated && _emo!.isCalibrationFinished()) {
      _calibrated = true;
    }

    if (!_emo!.isCalibrationFinished()) return;

    final md = _emo!.readMentalData();
    if (md.isNotEmpty) {
      final last = md.last;
      _attention = (last.relAttention * 100).clamp(0, 100);
      _relax = (last.relRelaxation * 100).clamp(0, 100);
      notifyListeners();
    }
  }

  void restartCalibration() {
    _emo?.startCalibration();
    _calibrated = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sigSub?.cancel();
    _sigSub = null;

    _sensor?.dispose();
    if (_scannerCreated) _scanner.stop();

    _emo?.dispose();
    _emo = null;

    super.dispose();
  }
}
