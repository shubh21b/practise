import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'dart:async';

class FanCommunication {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Callback for sensor data
  Function(double temp, double humidity, int rpm, bool motion)? onSensorData;

  FanCommunication(this._device);

  // Initialize Bluetooth connection and discover services
  Future<void> initialize() async {
    if (_device == null) throw Exception("No device connected");

    try {
      await _device!.connect();
      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothService? targetService = services.firstWhere(
        (service) => service.uuid.toString() == SERVICE_UUID,
        orElse: () => throw Exception("Service not found"),
      );

      _characteristic = targetService.characteristics.firstWhere(
        (char) => char.uuid.toString() == CHARACTERISTIC_UUID,
        orElse: () => throw Exception("Characteristic not found"),
      );

      // Enable notifications to receive sensor data
      if (_characteristic != null) {
        await _characteristic!.setNotifyValue(true);
        _characteristic!.value.listen((value) {
          // Log raw data for debugging
          print("Received BLE data: $value");
          _parseSensorData(value);
        });
      }
    } catch (e) {
      print("Error initializing Bluetooth: $e");
      rethrow;
    }
  }

  // Parse sensor data from characteristic value
  void _parseSensorData(List<int> value) {
    try {
      if (value.isEmpty) {
        print("Invalid data length: 0");
        return;
      }

      // Parse as ASCII string (e.g., "T:35.6,H:35.7,R:0,M 0")
      String dataString = String.fromCharCodes(value).trim();
      print("Parsed as string: $dataString");

      if (dataString.contains('T:') &&
          dataString.contains('H:') &&
          dataString.contains('R:') &&
          dataString.contains('M ')) {
        var parts = dataString.split(',');
        double temp = double.parse(parts[0].split(':')[1]);
        double humidity = double.parse(parts[1].split(':')[1]);
        int rpm = int.parse(parts[2].split(':')[1]);
        bool motion = parts[3].split(' ')[1] == '1';

        print("Calling onSensorData with: T:$temp, H:$humidity, R:$rpm, M:$motion");
        onSensorData?.call(temp, humidity, rpm, motion);
      } else {
        print("Invalid string format: $dataString");
      }
    } catch (e) {
      print("Error parsing sensor data: $e");
    }
  }

  // Send command to turn fan on or off
  Future<void> setFanState(bool isOn) async {
    if (_characteristic == null) throw Exception("Not initialized");
    try {
      final command = isOn ? [0x01] : [0x00];
      await _characteristic!.write(command);
      print("Fan state set to: ${isOn ? 'ON' : 'OFF'}");
    } catch (e) {
      print("Error setting fan state: $e");
      rethrow;
    }
  }

  // Send command to set fan speed (0-5 scale mapped to 0-255 for PWM)
  Future<void> setFanSpeed(double speed) async {
    if (_characteristic == null) throw Exception("Not initialized");
    try {
      int pwmValue = (speed * 51).toInt();
      await _characteristic!.write([0x02, pwmValue]);
      print("Fan speed set to: $pwmValue");
    } catch (e) {
      print("Error setting fan speed: $e");
      rethrow;
    }
  }

  // Disconnect from the device
  Future<void> disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
      _characteristic = null;
      print("Disconnected from device");
    }
  }
}