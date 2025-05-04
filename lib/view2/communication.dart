import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FanCommunication {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"; // Example UUID
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // Example UUID

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
    } catch (e) {
      print("Error initializing Bluetooth: $e");
      rethrow;
    }
  }

  // Send command to turn fan on or off
  Future<void> setFanState(bool isOn) async {
    if (_characteristic == null) throw Exception("Not initialized");
    try {
      final command = isOn ? [0x01] : [0x00]; // 0x01 for ON, 0x00 for OFF
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
      int pwmValue = (speed * 51).toInt(); // Map 0-5 to 0-255 (PWM range)
      await _characteristic!.write([0x02, pwmValue]); // 0x02 indicates speed command
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