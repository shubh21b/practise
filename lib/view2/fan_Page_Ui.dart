import 'package:flutter/material.dart';
import 'package:practise/view2/communication.dart';
//import 'package:practise/widgets/mode_container.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class FanPage extends StatefulWidget {
  final BluetoothDevice device;
  const FanPage({super.key, required this.device});

  @override
  _FanPageState createState() => _FanPageState();
}

class _FanPageState extends State<FanPage> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _swingController;
  late Animation<double> _swingAnimation;
  bool isFanOn = false;
  double _fanSpeed = 1.0;
  late FanCommunication _fanComm;

  // Sensor data state
  double _temperature = 0.0;
  double _humidity = 0.0;
  int _rpm = 0;
  bool _motion = false;
  bool _isDataReceived = false; // Track if data is received

  // Timer state
  int _timerMinutes = 0;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _fanComm = FanCommunication(widget.device);
    _fanComm.onSensorData = (temp, humidity, rpm, motion) {
      print('Updating sensor data: T:$temp, H:$humidity, R:$rpm, M:$motion');
      setState(() {
        _temperature = temp;
        _humidity = humidity;
        _rpm = rpm;
        _motion = motion;
        _isDataReceived = true;
      });
    };
    _fanComm.initialize().catchError((e) {
      print("Initialization error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to connect to device")),
      );
    });

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
        _cancelTimer();
      }
    });
    _fanComm.setFanState(isFanOn);
  }

  void _startTimer(int minutes) {
    setState(() {
      _timerMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });
    _cancelTimer();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _cancelTimer();
          if (isFanOn) {
            _toggleFan();
          }
        }
      });
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    setState(() {
      _timerMinutes = 0;
      _remainingSeconds = 0;
    });
  }

  String _formatTimer() {
    if (_remainingSeconds <= 0) return "Off";
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return "${minutes}m ${seconds}s";
  }

  // Build sensor display box
  Widget buildSensorBox(
      BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: Theme.of(context).primaryColor),
          SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: 4),
          Text(
            _isDataReceived ? value : "Waiting...",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _swingController.dispose();
    _cancelTimer();
    _fanComm.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building UI with: T:$_temperature, H:$_humidity, R:$_rpm, M:$_motion, DataReceived:$_isDataReceived');
    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Fan Animation"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: buildSensorBox(
                      context,
                      'Temp',
                      _isDataReceived
                          ? '${_temperature.toStringAsFixed(1)}°C'
                          : 'Waiting...',
                      Icons.thermostat,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: buildSensorBox(
                      context,
                      'Humidity',
                      _isDataReceived
                          ? '${_humidity.toStringAsFixed(1)}%'
                          : 'Waiting...',
                      Icons.water_drop,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: buildSensorBox(
                      context,
                      'RPM',
                      _isDataReceived ? '$_rpm' : 'Waiting...',
                      Icons.speed,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
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
            SizedBox(height: 20),
            Text(
              _isDataReceived && _motion ? 'Motion Detected' : 'No Motion',
              style: TextStyle(
                fontSize: 16,
                color: _isDataReceived && _motion ? Colors.red : Colors.grey,
              ),
            ),
            SizedBox(height: 20),
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
                    _rotationController.duration = Duration(
                        milliseconds: (1000 ~/ _fanSpeed).clamp(100, 1000));
                    if (isFanOn) {
                      _rotationController.repeat();
                    }
                  });
                  _fanComm.setFanSpeed(_fanSpeed);
                },
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ModeBoxCon(
                  label: "Auto",
                  icon: Icons.auto_awesome,
                  onTap: () {},
                ),
                ModeBoxCon(
                  label: "Sleep",
                  icon: Icons.person_2,
                  onTap: () {},
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Timer: ${_formatTimer()}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => _startTimer(5),
                  child: Text("Set 5m Timer"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}