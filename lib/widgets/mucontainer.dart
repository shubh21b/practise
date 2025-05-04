import 'package:flutter/material.dart';

Widget buildSensorBox(String label, String value, IconData icon) {
  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            icon,
          ),
          SizedBox(height: 8.0),
          Text(label,
              style: TextStyle(
                fontSize: 18,
              )),
          SizedBox(height: 4.0),
          Text(value,
              style: TextStyle(
                fontSize: 16,
              )),
        ],
      ),
    ),
  );
}
