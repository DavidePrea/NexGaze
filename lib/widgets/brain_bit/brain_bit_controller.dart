import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:neurosdk2/neurosdk2.dart' as bb;
import 'package:em_st_artifacts/em_st_artifacts.dart' as em;

/// BrainBitController con debug: mostra in console
/// ogni passaggio (scan, devices trovati, connect, calibrazione, dati).
class BrainBitController extends ChangeNotifier
    implements ValueListenable<BrainBitController> {
  @override
  BrainBitController get value => this;

  // ----- Stati pubblici -----
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isCalibrated => _calibrated;

  double get calibrationProgress => _calibPercent;
  bool get signalLost =>
      DateTime.now().difference(_lastPacket) > const Duration(seconds: 2);

  double? get attention => _attention;
  double? get relax => _relax;
  double? get meditation => _relax;

  List<bb.FSensorInfo> get devices => List.unmodifiable(_devices);

  String? get connectedDeviceName =>
      _connectedDevice?.name.isNotEmpty == true
          ? _connectedDevice!.name
          : _connectedDevice?.address;

  // ----- Campi privati -----
  final bool _autoConnect;
  late bb.Scanner _scanner;
  bool _scannerCreated = false;
  bool _isScanning = false;
  bool _isConnected = false;

  bb.BrainBit? _sensor;
  StreamSubscription<List<bb.BrainBitSignalData>>? _sigSub;

  em.EmotionalMath? _emo; // Standardizzato il nome da _calibration a _emo
  bool _calibrated = false;
  double _calibPercent = 0.0;

  DateTime _lastPacket = DateTime.fromMillisecondsSinceEpoch(0);

  final List<double> _attBuf = [];
  final List<double> _relBuf = [];
  final int _bufSize = 3;
  double? _attention;
  double? _relax;

  final List<bb.FSensorInfo> _devices = [];
  bb.FSensorInfo? _connectedDevice;

  // BuildContext per mostrare SnackBar
  final BuildContext? _context;

  /// autoConnect = false per selezionare manualmente
  BrainBitController({bool autoConnect = false, BuildContext? context})
      : _autoConnect = autoConnect,
        _context = context;

  /// Avvia scanner + (eventuale) connessione automatica
  Future<void> startMonitoring() async {
    debugPrint('[BrainBit] startMonitoring()');
    await _ensureScanner();
    await _startScan();
  }

  /// Ferma stream e scanner
  Future<void> stopMonitoring() async {
    debugPrint('[BrainBit] stopMonitoring()');
    await _disconnect();
    await _stopScan();
  }

  /// Rilancia calibrazione
  void restartCalibration() {
    debugPrint('[BrainBit] restartCalibration()');
    if (_emo != null) {
      _emo!.startCalibration();
      _calibrated = false;
      _calibPercent = 0.0;
      _attBuf.clear();
      _relBuf.clear();
      notifyListeners();
    }
  }

  /// UI chiama questo per connettere il dispositivo selezionato
  Future<void> connectToDevice(bb.FSensorInfo info) async {
    debugPrint('[BrainBit] connectToDevice: ${info.name} (${info.address})');
    if (_isConnected) {
      debugPrint('[BrainBit] già connesso a: $connectedDeviceName');
      return;
    }
    _connectedDevice = info;
    try {
      await _connect(info).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[BrainBit] Timeout connessione a ${info.name}');
        throw Exception('Timeout connessione');
      });
    } on em.ArtifactsException catch (e, stackTrace) {
      debugPrint('[BrainBit] ArtifactsException: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Errore segnale EEG: verifica il posizionamento del dispositivo')),
        );
      }
      _isConnected = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), _startScan);
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[BrainBit] Errore connessione: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
              content: Text(
                  'Errore inizializzazione EEG: verifica il dispositivo e riprova')),
        );
      }
      _isConnected = false;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), _startScan);
      rethrow;
    }
  }

  @override
  void dispose() {
    debugPrint('[BrainBit] dispose()');
    _sigSub?.cancel();
    _sensor?.dispose();
    if (_scannerCreated) {
      debugPrint('[BrainBit] stopScanner in dispose');
      _scanner.stop();
    }
    _emo?.dispose();
    super.dispose();
  }

  //──────────────────────────────────────────────────────
  // Scanner + Permessi
  //──────────────────────────────────────────────────────

  Future<void> _ensureScanner() async {
    if (_scannerCreated) return;
    debugPrint('[Scanner] _ensureScanner()');
    _scanner = await bb.Scanner.create([bb.FSensorFamily.leBrainBit]);
    _scanner.sensorsStream.listen((list) {
      debugPrint(
          '[Scanner] Scanner found ${list.length} device(s): ${list.map((d) => "${d.name} (${d.address})").join(", ")}');
      _devices.clear();
      _devices.addAll(list);
      if (_autoConnect && list.isNotEmpty && !_isConnected) {
        debugPrint('[Scanner] autoConnect to first device: ${list.first.name}');
        _connect(list.first);
      }
      notifyListeners();
    });
    _scannerCreated = true;
  }

  Future<bool> _ensurePermissions() async {
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final granted = res.values.every((s) => s.isGranted);
    debugPrint('[Scanner] Permissions granted? $granted');
    if (!granted && _context != null) {
      ScaffoldMessenger.of(_context).showSnackBar(
        const SnackBar(content: Text('Permessi Bluetooth o posizione negati')),
      );
    }
    return granted;
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    if (!await _ensurePermissions()) {
      debugPrint('[Scanner] Permessi negati, non posso scansionare');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
              content: Text('Permessi Bluetooth o posizione necessari')),
        );
      }
      throw Exception('Permessi Bluetooth negati');
    }
    debugPrint('[Scanner] Avvio scanner...');
    await _scanner.start();
    _isScanning = true;
    notifyListeners();
  }

  Future<void> _stopScan() async {
    if (!_isScanning) return;
    debugPrint('[Scanner] Stop scanner');
    await _scanner.stop();
    _isScanning = false;
    notifyListeners();
  }

  //──────────────────────────────────────────────────────
  // Connessione / Disconnessione
  //──────────────────────────────────────────────────────

  Future<void> _connect(bb.FSensorInfo info) async {
    if (_isConnected) return;
    debugPrint('[Scanner] _connect(): stopScan()');
    await _stopScan();

    try {
      debugPrint('[Scanner] Creating sensor for ${info.name}');
      _sensor = await _scanner.createSensor(info) as bb.BrainBit;
      debugPrint('[Scanner] Executing startSignal');
      await _sensor!.execute(bb.FSensorCommand.startSignal);
      debugPrint('[Scanner] startSignal eseguito con successo');
      _isConnected = true;
      debugPrint('[Scanner] Connessione avvenuta a: ${info.name}');

      // Ritarda l'inizializzazione di EmotionalMath
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('[Scanner] Inizializzazione EmotionalMath dopo ritardo');
      _initEmotions();

      _sigSub = _sensor!.signalDataStream.listen(
        _onEegPacket,
        onDone: () {
          debugPrint('[EEG] stream EEG chiuso');
          _handleDisconnect();
        },
        onError: (err) {
          debugPrint('[EEG] stream EEG error: $err');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e, stackTrace) {
      debugPrint('[Scanner] Errore in _connect(): $e\nStackTrace: $stackTrace');
      _isConnected = false;
      _sensor?.dispose();
      _sensor = null;
      Future.delayed(const Duration(seconds: 3), _startScan);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _disconnect() async {
    if (!_isConnected) return;
    debugPrint('[Scanner] _disconnect()');
    await _sigSub?.cancel();
    _sensor?.execute(bb.FSensorCommand.stopSignal);
    _sensor?.dispose();
    _sensor = null;
    _isConnected = false;
    notifyListeners();
  }

  void _handleDisconnect() {
    debugPrint('[Disconnect] handleDisconnect: riprovo a scan dopo 2s');
    _disconnect();
    Future.delayed(const Duration(seconds: 2), _startScan);
  }

  //──────────────────────────────────────────────────────
  // EmotionalMath
  //──────────────────────────────────────────────────────

  void _initEmotions() {
    if (_emo != null) return;
    debugPrint('[MathLib] _initEmotions()');
    try {
      debugPrint('[MathLib] Creazione MathLibSettings');
      const sr = 250;
      final mathSettings = em.MathLibSettings(
        samplingRate: sr,
        fftWindow: 1000, // 4 s
        processWinFreq: 25,
        nFirstSecSkipped: 6, // Aumenta il tempo di scarto iniziale
        bipolarMode: true,
      );
      debugPrint('[MathLib] MathLibSettings creato: $mathSettings');

      debugPrint('[MathLib] Creazione EmotionalMath');
      final emo = em.EmotionalMath(
        mathSettings,
        em.ArtifactsDetectSetting(hanningWinSpectrum: true),
        em.ShortArtifactsDetectSetting(
            amplArtExtremumBorder: 50), // Aumenta la tolleranza agli artefatti
        em.MentalAndSpectralSetting(
          nSecForAveraging: 4,
          nSecForInstantEstimation: 6,
        ),
      );
      debugPrint('[MathLib] EmotionalMath creato');

      debugPrint('[MathLib] Configurazione EmotionalMath');
      emo
        ..setCalibrationLength(6)
        ..setZeroSpectWaves(true, 0, 1, 1, 1, 0)
        ..setSpectNormalizationByBandsWidth(true)
        ..startCalibration();
      debugPrint('[Calibrazione] EmotionalMath calibrazione avviata');
      _emo = emo;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[MathLib] Errore in _initEmotions: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
              content: Text(
                  'Errore inizializzazione EEG: verifica il dispositivo e riprova')),
        );
      }
      rethrow;
    }
  }

  //──────────────────────────────────────────────────────
  // Ricezione pacchetti EEG
  //──────────────────────────────────────────────────────

  void _onEegPacket(List<bb.BrainBitSignalData> packet) {
    debugPrint('[EEG] Ricevuti ${packet.length} pacchetti EEG');
    if (_emo == null || packet.isEmpty) {
      debugPrint('[EEG] _emo nullo o pacchetti vuoti');
      return;
    }

    // Ignora i pacchetti per i primi 2 secondi dopo la connessione
    if (DateTime.now().difference(_lastPacket).inSeconds < 2 &&
        _lastPacket != DateTime.fromMillisecondsSinceEpoch(0)) {
      debugPrint('[EEG] Ignoro pacchetti iniziali');
      return;
    }

    try {
      _lastPacket = DateTime.now();
      debugPrint('[EEG] Creazione campioni EEG');

      final samples = packet
          .map((s) => em.RawChanel(
        leftBipolar: s.t3 - s.o1,
        rightBipolar: s.t4 - s.o2,
      ))
          .toList();
      debugPrint('[EEG] Campioni creati: ${samples.length}');

      debugPrint('[EEG] Invio dati a EmotionalMath');
      _emo!.pushBipolars(samples);
      _emo!.processData();
      _emo!.processData();
      debugPrint('[EEG] Dati elaborati');

      // Progresso calibrazione
      final rawPercent = _emo!.getCalibrationPercents();
      _calibPercent = (rawPercent.clamp(0, 100)) / 100.0;
      debugPrint(
          '[EEG] Progresso calibrazione: ${(_calibPercent * 100).toStringAsFixed(0)}%');

      if (!_calibrated && _emo!.isCalibrationFinished()) {
        _calibrated = true;
        _attBuf.clear();
        _relBuf.clear();
        debugPrint('[Calibrazione] Calibrazione completata al 100%');
      }
      if (!_calibrated) {
        notifyListeners();
        return;
      }

      // Se artefatti
      if (_emo!.isArtifactedSequence()) {
        debugPrint('[EEG] Artefatto rilevato (signalLost)');
        _attention = null;
        _relax = null;
        notifyListeners();
        return;
      }

      final md = _emo!.readMentalData();
      if (md.isEmpty) {
        debugPrint('[EEG] Nessun dato mentale disponibile');
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
      debugPrint('[EEG] Errore in _onEegPacket: $e\nStackTrace: $stackTrace');
      if (_context != null) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
              content: Text(
                  'Errore elaborazione EEG: verifica il dispositivo e riprova')),
        );
      }
      _attention = null;
      _relax = null;
      notifyListeners();
      _handleDisconnect();
    }
  }
}