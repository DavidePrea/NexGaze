import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:em_st_artifacts/em_st_artifacts.dart' as em;

import '../widgets/heart_monitor/heart_monitor_controller.dart';
import '../widgets/heart_monitor/heart_monitor_widget.dart';
import '../widgets/brain_bit/brain_bit_controller.dart';
import '../widgets/brain_bit/brain_bit_widget.dart';

/// Schermata Yoga Mode (Mode5) con selezione device -> calibrazione -> video
class Mode5Screen extends StatefulWidget {
  const Mode5Screen({super.key});

  @override
  _Mode5ScreenState createState() => _Mode5ScreenState();
}

class _Mode5ScreenState extends State<Mode5Screen> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;

  late final HeartMonitorController _heartController;
  late final BrainBitController _brainBitController;

  late final Timer _clockTimer;
  String _currentTime = DateFormat.Hm().format(DateTime.now());

  bool _calibrationConfirmed = false;

  // Variabile di supporto per mostrare “Sto connettendo…”
  bool _isAttemptingConnection = false;

  @override
  void initState() {
    super.initState();

    // Forziamo l’orientamento a landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Avviamo il monitor cardiaco
    _heartController = HeartMonitorController()..startMonitoring();

    // Avviamo BrainBitController con autoConnect=false e context
    _brainBitController = BrainBitController(autoConnect: false, context: context)
      ..startMonitoring();

    // Prepariamo il video (non parte ancora)
    _controller = VideoPlayerController.asset('assets/videos/yoga.mp4')
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
      });

    // Timer per aggiornare l’orologio ogni secondo
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateFormat.Hm().format(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartController.stopMonitoring();
    _brainBitController.stopMonitoring();
    _clockTimer.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Stack(
        children: [
          // Se non ho ancora confermato la calibrazione,
          // controllo due casi: selezione device o calibrazione
          if (!_calibrationConfirmed)
            _buildDeviceSelectionOrCalibration()
          else
          // Altrimenti riproduco il video
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

          // Orologio in alto a sinistra
          Positioned(
            top: 16,
            left: 16,
            child: Text(
              _currentTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Battito cardiaco in alto a destra
          Positioned(
            top: 16,
            right: 16,
            child: HeartMonitorWidget(controller: _heartController),
          ),

          // BrainBitWidget in basso a sinistra
          Positioned(
            bottom: 16,
            left: 16,
            child: BrainBitWidget(controller: _brainBitController),
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  /// Costruisce sia la lista dei dispositivi (se non connesso),
  /// sia il dialog di calibrazione (se connesso ma non calibrato),
  /// sia il pulsante "Inizia la sessione" (se calibrato).
  Widget _buildDeviceSelectionOrCalibration() {
    return Center(
      child: ValueListenableBuilder<BrainBitController>(
        valueListenable: _brainBitController,
        builder: (context, ctrl, _) {
          // 1️⃣ Se NON sono connesso, mostro solo la selezione device
          if (!ctrl.isConnected) {
            // Se sto provando a connettermi (premuto il device), mostro “Sto connettendo…”
            if (_isAttemptingConnection) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sto tentando di connettermi…',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              );
            }

            // Se sto ancora scansionando e non ho devices, mostro un messaggio
            if (ctrl.isScanning && ctrl.devices.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Cerco dispositivi BrainBit…',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            // Se ho trovato uno o più dispositivi, li elenco
            if (ctrl.devices.isNotEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                width: 300,
                height: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Seleziona BrainBit da connettere:',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: ctrl.devices.length,
                        itemBuilder: (context, idx) {
                          final info = ctrl.devices[idx];
                          final label = info.name.isNotEmpty
                              ? info.name
                              : info.address;
                          return Card(
                            color: Colors.grey[900],
                            child: ListTile(
                              title: Text(
                                label,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                info.address,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              onTap: () async {
                                setState(() => _isAttemptingConnection = true);
                                try {
                                  await ctrl
                                      .connectToDevice(info)
                                      .timeout(const Duration(seconds: 10));
                                } on em.ArtifactsException catch (e) {
                                  debugPrint('ArtifactsException: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Errore segnale EEG: verifica il posizionamento del dispositivo')),
                                  );
                                } catch (e) {
                                  debugPrint('Errore: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Errore inizializzazione EEG: $e')),
                                  );
                                } finally {
                                  setState(() => _isAttemptingConnection = false);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dispositivi trovati: ${ctrl.devices.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            // Se non sto scansionando e non ho devices:
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nessun dispositivo trovato',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      ctrl.startMonitoring(); // Rilancio la scansione
                    },
                    child: const Text('Riprova ricerca'),
                  ),
                ],
              ),
            );
          }

          // 2️⃣ Sono connesso ma NON calibrato: mostro progresso di calibrazione + nome device
          if (ctrl.isConnected && !ctrl.isCalibrated) {
            final deviceName = ctrl.connectedDeviceName ?? 'BrainBit sconosciuto';
            final pct = (ctrl.calibrationProgress * 100)
                .clamp(0, 100)
                .toStringAsFixed(0);
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Connesso a: $deviceName',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Calibrazione… $pct%',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: ctrl.calibrationProgress,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Pulsante per riprovare in caso di errore
                      ctrl.stopMonitoring();
                      ctrl.startMonitoring();
                      setState(() {});
                    },
                    child: const Text('Riprova calibrazione'),
                  ),
                ],
              ),
            );
          }

          // 3️⃣ Sono calibrato, ma l’utente non ha ancora premuto “Inizia sessione”
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Calibrazione completata!',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _controller.play();
                    setState(() => _calibrationConfirmed = true);
                  },
                  child: const Text('Inizia la sessione'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}