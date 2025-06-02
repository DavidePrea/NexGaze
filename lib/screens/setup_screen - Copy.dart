import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _voiceNotificationsEnabled = false;
  String _overlayColor = 'White';
  bool _findMyBuddyEnabled = false;
  String _buddyName = '';
  String _buddyList = '';
  final List<String> _availableColors = ['White', 'Yellow', 'Red', 'Green', 'Blue'];
  final List<String> _buddyNames = ['Alice', 'Bob', 'Charlie'];

  void _showBuddies() {
    setState(() {
      _buddyList = _buddyNames.join(', ');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Voice Notifications
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voice Notifications',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Switch(
                  value: _voiceNotificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _voiceNotificationsEnabled = value;
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Overlay Color
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overlay color',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: _overlayColor,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _availableColors.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _overlayColor = newValue!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Find my buddy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Find my buddy',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Switch(
                  value: _findMyBuddyEnabled,
                  onChanged: (value) {
                    setState(() {
                      _findMyBuddyEnabled = value;
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),

            // My buddy name (enabled only when Find my buddy is ON)
            if (_findMyBuddyEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    const Text(
                      'My buddy name',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter name',
                          hintStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _buddyName = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Show buddies button and list (enabled only when Find my buddy is ON)
            if (_findMyBuddyEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: _showBuddies,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        'Show buddies',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buddyList,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}