// lib/widgets/heart_monitor/heart_monitor_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// Controller for managing heart rate monitoring via Bluetooth
class HeartMonitorController extends ChangeNotifier {
  int _bpm = 0; // Current heart rate in beats per minute
  bool _pulse = false; // Indicates if pulse is active (for UI animation)
  BluetoothDevice? _device; // Connected Bluetooth heart rate device
  StreamSubscription<List<int>>? _subscription; // Subscription to characteristic updates

  // Getter for heart rate
  int get bpm => _bpm;
  // Getter for pulse state
  bool get pulse => _pulse;

  // Updates heart rate and pulse state, notifying listeners
  void update(int newBpm, bool newPulse) {
    _bpm = newBpm;
    _pulse = newPulse;
    notifyListeners();
  }

  // Requests necessary Bluetooth and location permissions
  Future<void> requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  // Starts monitoring heart rate by scanning for and connecting to a heart rate monitor
  Future<void> startMonitoring() async {
    await requestBluetoothPermissions();

    // Begin scanning for Bluetooth devices
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // Check for heart rate monitor by name or service UUID
        if (r.device.name.toLowerCase().contains("hrm") ||
            r.advertisementData.serviceUuids.contains("0000180d-0000-1000-8000-00805f9b34fb")) {
          FlutterBluePlus.stopScan();
          _device = r.device;
          await _device!.connect();

          // Discover services on the connected device
          List<BluetoothService> services = await _device!.discoverServices();
          for (BluetoothService service in services) {
            // Look for heart rate service (UUID 180d)
            if (service.uuid.toString().toLowerCase().contains("180d")) {
              for (BluetoothCharacteristic c in service.characteristics) {
                // Look for heart rate measurement characteristic (UUID 2a37)
                if (c.uuid.toString().toLowerCase().contains("2a37")) {
                  await c.setNotifyValue(true);
                  // Subscribe to characteristic updates
                  _subscription = c.onValueReceived.listen((value) {
                    if (value.isNotEmpty) {
                      int hr = value[1]; // Extract heart rate value

                      // Set pulse to ON and update BPM
                      update(hr, true);

                      // Turn pulse OFF after 250ms for animation effect
                      Future.delayed(const Duration(milliseconds: 250), () {
                        update(hr, false);
                      });
                    }
                  });
                  break;
                }
              }
            }
          }
          break;
        }
      }
    });
  }

  // Stops monitoring by canceling subscriptions and disconnecting the device
  Future<void> stopMonitoring() async {
    _subscription?.cancel(); // Cancel characteristic subscription
    if (_device != null) {
      await _device!.disconnect(); // Disconnect from device
    }
    _device = null; // Clear device reference
  }
}