import 'package:flutter/material.dart';
import 'package:practise/view2/communication.dart';
import 'package:practise/widget/modebox.dart';
import 'package:practise/widget/sensorbox.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

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
  bool _isDataReceived = false;

  // Timer state
  int _timerMinutes = 0;
  Timer? _timer;
  int _remainingSeconds = 0;

  // Night mode state
  bool _isNightModeSet = false;
  TimeOfDay _nightStart = TimeOfDay(hour: 22, minute: 0); // 10:00 PM
  TimeOfDay _nightEnd = TimeOfDay(hour: 6, minute: 0); // 06:00 AM
  int _nightTapCount = 0;
  Timer? _tapTimer;

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
        // Ignore motion data if in sleep mode
        _motion = _isNightModeSet ? false : motion;
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

    _loadNightModeSettings();
  }

  // Load Night Mode settings from SharedPreferences
  Future<void> _loadNightModeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nightStart = TimeOfDay(
        hour: prefs.getInt('nightStartHour') ?? 22,
        minute: prefs.getInt('nightStartMinute') ?? 0,
      );
      _nightEnd = TimeOfDay(
        hour: prefs.getInt('nightEndHour') ?? 6,
        minute: prefs.getInt('nightEndMinute') ?? 0,
      );
      _isNightModeSet = prefs.getBool('isNightModeSet') ?? false;
      // Ensure motion is disabled if sleep mode is active
      if (_isNightModeSet) {
        _motion = false;
      }
    });
    developer.log(
        'Loaded Night Mode settings: Start=${_nightStart.format(context)}, End=${_nightEnd.format(context)}, IsSet=$_isNightModeSet',
        name: 'NightMode');
  }

  // Save Night Mode settings to SharedPreferences
  Future<void> _saveNightModeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nightStartHour', _nightStart.hour);
    await prefs.setInt('nightStartMinute', _nightStart.minute);
    await prefs.setInt('nightEndHour', _nightEnd.hour);
    await prefs.setInt('nightEndMinute', _nightEnd.minute);
    await prefs.setBool('isNightModeSet', _isNightModeSet);
    developer.log(
        'Saved Night Mode settings: Start=${_nightStart.format(context)}, End=${_nightEnd.format(context)}, IsSet=$_isNightModeSet',
        name: 'NightMode');
  }

  // Show a popup message using ScaffoldMessenger
  void _showModePopup(String mode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$mode mode is on'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Show time picker for night mode start/end times
  Future<void> _showTimePicker(TimeOfDay initialTime, bool isStart) async {
    developer.log('Opening time picker for ${isStart ? "Start" : "End"} time',
        name: 'NightMode');
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.white,
                hourMinuteTextColor: Colors.black,
                dialHandColor: Colors.black,
                dialTextColor: Colors.black,
                entryModeIconColor: Colors.black,
              ),
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: Colors.black),
                bodyMedium: TextStyle(color: Colors.black),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        developer.log('Time picked: ${picked.format(context)}',
            name: 'NightMode');
        setState(() {
          if (isStart)
            _nightStart = picked;
          else
            _nightEnd = picked;
        });
      } else {
        developer.log('No time selected', name: 'NightMode');
      }
    } catch (e) {
      developer.log('Error in time picker: $e', name: 'NightMode');
    }
  }

  // Show dialog to set night mode times
  void _showNightModeDialog() {
    developer.log('Showing Night Mode dialog', name: 'NightMode');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Set Sleep Mode'),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Start: ${_nightStart.format(context)}'),
            ElevatedButton(
              onPressed: () => _showTimePicker(_nightStart, true),
              child: Text('Change Start Time'),
            ),
            Text('End: ${_nightEnd.format(context)}'),
            ElevatedButton(
              onPressed: () => _showTimePicker(_nightEnd, false),
              child: Text('Change End Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _nightStart = TimeOfDay(hour: 22, minute: 0);
                _nightEnd = TimeOfDay(hour: 6, minute: 0);
                _isNightModeSet = false;
                _motion = false; // Ensure motion remains off until new data
              });
              _saveNightModeSettings();
              Navigator.pop(context);
            },
            child: Text('Reset'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isNightModeSet = true;
                _fanSpeed = 1.0;
                _motion = false; // Disable motion detection
                _rotationController.duration = Duration(
                  milliseconds: (1000 ~/ _fanSpeed).clamp(100, 1000),
                );
                if (!isFanOn) {
                  isFanOn = true;
                  _rotationController.repeat();
                  _swingController.repeat(reverse: true);
                  _fanComm.setFanState(true);
                } else {
                  _rotationController.repeat();
                }
                _fanComm.setFanSpeed(_fanSpeed);
              });
              _saveNightModeSettings();
              Navigator.pop(context);
              _showModePopup('Sleep');
            },
            child: Text('OK'),
          ),
        ],
      ),
    ).catchError((error) {
      developer.log('Error showing dialog: $error', name: 'NightMode');
    });
  }

  // Handle taps on the Sleep button for night mode
  void _handleSleepModeTap() {
    developer.log('Sleep button tapped, current count: $_nightTapCount',
        name: 'NightMode');
    setState(() {
      _nightTapCount++;
      if (_nightTapCount == 1) {
        if (!_isNightModeSet) {
          _showNightModeDialog();
        } else {
          _fanSpeed = 1.0;
          _motion = false; // Disable motion detection
          _rotationController.duration = Duration(
            milliseconds: (1000 ~/ _fanSpeed).clamp(100, 1000),
          );
          if (!isFanOn) {
            isFanOn = true;
            _rotationController.repeat();
            _swingController.repeat(reverse: true);
            _fanComm.setFanState(true);
          } else {
            _rotationController.repeat();
          }
          _fanComm.setFanSpeed(_fanSpeed);
          _showModePopup('Sleep');
        }
      } else if (_nightTapCount == 3) {
        developer.log('Resetting Sleep Mode', name: 'NightMode');
        _nightStart = TimeOfDay(hour: 22, minute: 0);
        _nightEnd = TimeOfDay(hour: 6, minute: 0);
        _isNightModeSet = false;
        _motion = false; // Reset motion, will update with next sensor data
        _nightTapCount = 0;
        _tapTimer?.cancel();
        _saveNightModeSettings();
        _showModePopup('Sleep Mode Reset');
        return;
      }

      _tapTimer?.cancel();
      _tapTimer = Timer(Duration(seconds: 2), () {
        setState(() {
          developer.log('Tap timer expired, resetting tap count',
              name: 'NightMode');
          _nightTapCount = 0;
        });
      });
    });
  }

  // Function to set fan speed automatically based on temperature
  void _setAutoFanSpeed() {
    setState(() {
      if (_temperature < 30) {
        _fanSpeed = 1.0;
      } else if (_temperature < 32) {
        _fanSpeed = 2.0;
      } else if (_temperature < 35) {
        _fanSpeed = 3.0;
      } else if (_temperature < 37) {
        _fanSpeed = 4.0;
      } else {
        _fanSpeed = 5.0;
      }

      _rotationController.duration = Duration(
        milliseconds: (1000 ~/ _fanSpeed).clamp(100, 1000),
      );

      if (!isFanOn) {
        isFanOn = true;
        _rotationController.repeat();
        _swingController.repeat(reverse: true);
        _fanComm.setFanState(true);
      } else {
        _rotationController.repeat();
      }
    });

    _fanComm.setFanSpeed(_fanSpeed);
    print(
        "Auto mode set fan speed to: $_fanSpeed for temperature: $_temperature°C");
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

  @override
  void dispose() {
    _rotationController.dispose();
    _swingController.dispose();
    _cancelTimer();
    _tapTimer?.cancel();
    _fanComm.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building UI with: T:$_temperature, H:$_humidity, R:$_rpm, M:$_motion, DataReceived:$_isDataReceived');
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
                    child: SensorBox(
                      label: 'Temp',
                      value: '${_temperature.toStringAsFixed(1)}°C',
                      icon: Icons.thermostat,
                      isDataReceived: _isDataReceived,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: SensorBox(
                      label: 'Humidity',
                      value: '${_humidity.toStringAsFixed(1)}%',
                      icon: Icons.water_drop,
                      isDataReceived: _isDataReceived,
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: SensorBox(
                      label: 'RPM',
                      value: '$_rpm',
                      icon: Icons.speed,
                      isDataReceived: _isDataReceived,
                    ),
                  ),
                ],
              ),
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
                  onTap: _setAutoFanSpeed,
                ),
                ModeBoxCon(
                  label: "Sleep",
                  icon: Icons.person_2,
                  onTap: _handleSleepModeTap,
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Tap Sleep 3 times to reset sleep mode',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
