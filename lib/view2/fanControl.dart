import 'package:flutter/material.dart';
import 'package:practise/view2/communication.dart';
import 'package:practise/widgets/mucontainer.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FanPage extends StatefulWidget {
  final BluetoothDevice device; // Add device parameter
  const FanPage({super.key, required this.device});

  @override
  _FanPageState createState() => _FanPageState();
}

class _FanPageState extends State<FanPage> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _swingController;
  late Animation<double> _swingAnimation;
  bool isFanOn = false;
  double _fanSpeed = 1.0; // Default speed
  late FanCommunication _fanComm; // Communication instance

  @override
  void initState() {
    super.initState();
    _fanComm = FanCommunication(widget.device); // Initialize with device
    _fanComm.initialize(); // Connect to ESP32

    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _swingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    _swingAnimation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _swingController, curve: Curves.easeInOut),
    );
  }

  void _toggleFan() {
    setState(() {
      isFanOn = !isFanOn;
      if (isFanOn) {
        _rotationController.repeat();
        _swingController.repeat(reverse: true);
      } else {
        _rotationController.stop();
        _swingController.stop();
      }
    });
    _fanComm.setFanState(isFanOn); // Call communication method
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _swingController.dispose();
    _fanComm.disconnect(); // Disconnect from ESP32
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Fan Animation"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: buildSensorBox('Temp', '21', Icons.thermostat)),
              SizedBox(width: 8.0),
              Expanded(
                  child: buildSensorBox('Humidity', '60%', Icons.water_drop)),
              SizedBox(width: 8.0),
              Expanded(child: buildSensorBox('RPM', '1031', Icons.speed)),
            ],
          ),
          AnimatedBuilder(
            animation: _swingAnimation,
            builder: (context, child) {
              return Align(
                alignment: Alignment(_swingAnimation.value, -0.2),
                child: RotationTransition(
                  turns: _rotationController,
                  child: Image.asset(
                    'assets/images/fanlogo.png',
                    width: 200,
                    height: 200,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 60,
                  color: Colors.white,
                  onPressed: _toggleFan,
                  icon: Icon(Icons.power_settings_new_sharp),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 50,
            width: 500,
            child: Slider(
              value: _fanSpeed,
              min: 0,
              max: 5,
              divisions: 5,
              label: _fanSpeed.toStringAsFixed(1),
              activeColor: Theme.of(context).primaryColor,
              inactiveColor: Colors.grey,
              thumbColor: Colors.white,
              onChanged: (value) {
                setState(() {
                  _fanSpeed = value;
                  _rotationController.duration =
                      Duration(milliseconds: (1000 ~/ _fanSpeed));
                  if (isFanOn) {
                    _rotationController.repeat();
                  }
                });
                _fanComm.setFanSpeed(_fanSpeed); // Call communication method
              },
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Set Timer",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
