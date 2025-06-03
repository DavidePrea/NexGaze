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

/// Yoga Mode Screen (Mode5) with device selection, calibration, and video playback
class Mode5Screen extends StatefulWidget {
  const Mode5Screen({super.key});

  @override
  _Mode5ScreenState createState() => _Mode5ScreenState();
}

class _Mode5ScreenState extends State<Mode5Screen> {
  late final VideoPlayerController _controller; // Controller for video playback
  bool _isInitialized = false; // Flag to track video initialization

  late final HeartMonitorController _heartController; // Controller for heart rate monitoring
  late final BrainBitController _brainBitController; // Controller for BrainBit device

  late final Timer _clockTimer; // Timer for updating clock
  String _currentTime = DateFormat.Hm().format(DateTime.now()); // Current time (hours and minutes)

  bool _calibrationConfirmed = false; // Flag to track calibration confirmation

  bool _isAttemptingConnection = false; // Flag to show "Connecting..." message

  @override
  void initState() {
    super.initState();

    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize heart rate monitoring
    _heartController = HeartMonitorController()..startMonitoring();

    // Initialize BrainBit controller with autoConnect disabled
    _brainBitController = BrainBitController(autoConnect: false, context: context)
      ..startMonitoring();

    // Initialize yoga video
    _controller = VideoPlayerController.asset('assets/videos/yoga.mp4')
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
      });

    // Update clock every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateFormat.Hm().format(DateTime.now()));
    });
  }

  @override
  void dispose() {
    // Clean up resources
    _controller.dispose();
    _heartController.stopMonitoring();
    _brainBitController.stopMonitoring();
    _clockTimer.cancel();
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // Build the main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Stack(
              children: [
                // Show device selection or calibration if not confirmed
                if (!_calibrationConfirmed)
                  _buildDeviceSelectionOrCalibration()
                else
                  // Play video if calibration is confirmed
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),

                // Clock at top-left
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

                // Heart rate monitor at top-right
                Positioned(
                  top: 16,
                  right: 16,
                  child: HeartMonitorWidget(controller: _heartController),
                ),

                // BrainBit widget at bottom-left
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: BrainBitWidget(controller: _brainBitController),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()), // Show loading until video is ready
    );
  }

  /// Builds device selection list, calibration progress, or start session button
  Widget _buildDeviceSelectionOrCalibration() {
    return Center(
      child: ValueListenableBuilder<BrainBitController>(
        valueListenable: _brainBitController,
        builder: (context, ctrl, _) {
          // Case 1: Not connected, show device selection
          if (!ctrl.isConnected) {
            // Show "Connecting..." during connection attempt
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

            // Show scanning message if no devices found
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

            // Show list of found devices
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

            // Show retry option if no devices found
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
                      ctrl.startMonitoring(); // Restart scanning
                    },
                    child: const Text('Riprova ricerca'),
                  ),
                ],
              ),
            );
          }

          // Case 2: Connected but not calibrated, show calibration progress
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

          // Case 3: Calibrated, show start session button
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