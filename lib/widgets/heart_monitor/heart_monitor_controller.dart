// lib/widgets/heart_monitor/heart_monitor_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class HeartMonitorController extends ChangeNotifier {
  int _bpm = 0;
  bool _pulse = false;
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _subscription;

  int get bpm => _bpm;
  bool get pulse => _pulse;

  void update(int newBpm, bool newPulse) {
    _bpm = newBpm;
    _pulse = newPulse;
    notifyListeners();
  }

  Future<void> requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> startMonitoring() async {
    await requestBluetoothPermissions();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name.toLowerCase().contains("hrm") ||
            r.advertisementData.serviceUuids.contains("0000180d-0000-1000-8000-00805f9b34fb")) {
          FlutterBluePlus.stopScan();
          _device = r.device;
          await _device!.connect();

          List<BluetoothService> services = await _device!.discoverServices();
          for (BluetoothService service in services) {
            if (service.uuid.toString().toLowerCase().contains("180d")) {
              for (BluetoothCharacteristic c in service.characteristics) {
                if (c.uuid.toString().toLowerCase().contains("2a37")) {
                  await c.setNotifyValue(true);
                  _subscription = c.onValueReceived.listen((value) {
                    if (value.isNotEmpty) {
                      int hr = value[1];

                      // Impulso ON
                      update(hr, true);

                      // Impulso OFF dopo 250 ms
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

  Future<void> stopMonitoring() async {
    _subscription?.cancel();
    if (_device != null) {
      await _device!.disconnect();
    }
    _device = null;
  }
}
