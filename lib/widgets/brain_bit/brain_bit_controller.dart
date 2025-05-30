
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:neurosdk2/neurosdk2.dart' as bb;
import 'package:em_st_artifacts/em_st_artifacts.dart' as em;

class BrainBitController extends ChangeNotifier {
  /* -------------------------------------------------- */
  /* Campi privati                                      */
  /* -------------------------------------------------- */
  late bb.Scanner _scanner;                   // scanner BLE BrainBit
  List<bb.FSensorInfo> _devices = [];        // dispositivi trovati
  final bool _autoConnect;                    // autoconnessione opzionale

  bb.BrainBit? _sensor;                       // sensore attivo
  StreamSubscription<List<bb.BrainBitSignalData>>? _sigSub;

  em.EmotionalMath? _emo;                    // motore Emotions
  bool _calibrated = false;                  // calibrazione completata?

  bool _scannerCreated = false;
  bool _isScanning   = false;
  bool _isConnected  = false;

  double? _attention; // 0‑100
  double? _relax;     // 0‑100

  /* -------------------------------------------------- */
  /* Costruttore                                        */
  /* -------------------------------------------------- */
  BrainBitController({bool autoConnect = true}) : _autoConnect = autoConnect;

  /* -------------------------------------------------- */
  /* Getters                                            */
  /* -------------------------------------------------- */
  bool get isScanning   => _isScanning;
  bool get isConnected  => _isConnected;
  bool get isCalibrated => _calibrated;

  List<bb.FSensorInfo> get devices => List.unmodifiable(_devices);

  double? get attention  => _attention;
  double? get relax      => _relax;          // sinonimo più leggibile
  double? get meditation => _relax;          // compat per vecchio widget

  /* -------------------------------------------------- */
  /* API alto livello                                   */
  /* -------------------------------------------------- */
  Future<void> startMonitoring() async {
    await _ensureScanner();
    await _startScan();
  }

  Future<void> stopMonitoring() async {
    await _disconnect();
    await _stopScan();
  }

  /* -------------------------------------------------- */
  /* Setup Scanner                                      */
  /* -------------------------------------------------- */
  Future<void> _ensureScanner() async {
    if (_scannerCreated) return;

    _scanner = await bb.Scanner.create([bb.FSensorFamily.leBrainBit]);

    _scanner.sensorsStream.listen((list) async {
      _devices = list;

      // Autoconnect (facoltativo)
      if (_autoConnect && _devices.isNotEmpty && !_isConnected) {
        try {
          await _connect(_devices.first);
        } catch (_) {
          // ignora errori di connessione, continua a scansionare
        }
      }

      notifyListeners();
    });

    _scannerCreated = true;
  }

  /* -------------------------------------------------- */
  /* Permessi                                           */
  /* -------------------------------------------------- */
  Future<bool> _checkBlePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  /* -------------------------------------------------- */
  /* Scansione                                          */
  /* -------------------------------------------------- */
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

  /* -------------------------------------------------- */
  /* Connessione & Stream EEG                           */
  /* -------------------------------------------------- */
  Future<void> _connect(bb.FSensorInfo info) async {
    if (_isConnected) return;

    // arresta scan per liberare BLE
    await _stopScan();

    // crea sensore
    _sensor = await _scanner.createSensor(info) as bb.BrainBit;
    await _sensor!.execute(bb.FSensorCommand.startSignal);

    // setup Emotions
    _initEmotions();

    // ascolta stream EEG
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

  /* -------------------------------------------------- */
  /* Emotions setup                                     */
  /* -------------------------------------------------- */
  void _initEmotions() {
    if (_emo != null) return; // già creato

    const sr = 250; // BrainBit sample‑rate Hz

    final mathSettings = em.MathLibSettings(
      samplingRate: sr,
      fftWindow: 1000,          // 1 s
      processWinFreq: 25,       // 25 Hz update
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

    emo.startCalibration();
    _emo = emo;
  }

  /* -------------------------------------------------- */
  /* Gestione pacchetti EEG                             */
  /* -------------------------------------------------- */
  void _onEegPacket(List<bb.BrainBitSignalData> packet) {
    if (_emo == null || packet.isEmpty) return;

    // Converte ogni BrainBitSignalData in RawChanel (left/right bipolare)
    final samples = packet
        .map((s) => em.RawChanel(
      leftBipolar: s.t3 - s.o1,
      rightBipolar: s.t4 - s.o2,
    ))
        .toList();

    _emo!.pushBipolars(samples);
    _emo!.processData();
    _emo!.processData();

    // calibrazione finita?
    if (!_calibrated && _emo!.isCalibrationFinished()) {
      _calibrated = true;
    }

    // leggi dati mentali
    final md = _emo!.readMentalData();
    if (md.isNotEmpty) {
      final last = md.last;
      _attention = (last.instAttention   * 100).clamp(0, 100);
      _relax     = (last.instRelaxation * 100).clamp(0, 100);
      notifyListeners();
    }
  }

  /* -------------------------------------------------- */
  /* Dispose                                           */
  /* -------------------------------------------------- */
  @override
  void dispose() {
    _sigSub?.cancel();
    _sigSub = null;

    _sensor?.dispose();
    if (_scannerCreated) _scanner.stop();

    super.dispose();
  }
}
