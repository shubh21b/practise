import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

import 'package:practise/view2/fan_Page_Ui.dart';


class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> _devices = [];
  bool _isScanning = false;
  BluetoothDevice? connectedDevice;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  void _checkBluetoothState() {
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) async {
      if (state == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      } else if (state == BluetoothAdapterState.on) {
        _scanForDevices();
      }
    });
  }

  void _scanForDevices() {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      var subscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _devices = results;
        });
      });

      Future.delayed(const Duration(seconds: 10)).then((_) async {
        await FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
        });
        subscription.cancel();
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showMessage('Error scanning for devices: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
  try {
    await device.connect();
    setState(() {
      connectedDevice = device;
    });
    _showMessage(
        'Connected to ${device.name.isNotEmpty ? device.name : device.id}');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FanPage(device: device)), // Pass device
    );
  } catch (e) {
    _showMessage('Error connecting to device: $e');
  }
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        Expanded(
          flex: 1,
          child: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Please don't turn off your phone's Bluetooth while connecting to the device",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  "Connecting.. To ShubhFan",
                  style: Theme.of(context).textTheme.titleMedium,
                )
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                    top: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 25,
                )),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(90),
                  topRight: Radius.circular(90),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(100),
                  topRight: Radius.circular(100),
                ),
                child: _isScanning
                    ? const Center(child: CircularProgressIndicator())
                    : _devices.isEmpty
                        ? Center(
                            child: Text(
                            'No devices found. Tap refresh',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ))
                        : ListView.builder(
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index].device;
                              return Padding(
                                padding: EdgeInsets.all(10),
                                child: ListTile(
                                  onTap: () => _connectToDevice(device),
                                  contentPadding: EdgeInsets.all(5),
                                  leading: Icon(Icons.bluetooth,
                                      color: Theme.of(context).iconTheme.color),
                                  title: Text(
                                      device.name.isNotEmpty
                                          ? device.name
                                          : 'Unknown Device',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                  subtitle: Text("Not Connected"),
                                ),
                              );
                            }),
              )),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: _scanForDevices,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
