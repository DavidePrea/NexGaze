// setup_screen.dart
import 'package:flutter/material.dart';

// Classe per gestire le variabili globali
class GlobalSettings {
  static bool voiceNotificationsEnabled = false;
  static String overlayColor = 'White';
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late bool _voiceNotificationsEnabled;
  late String _overlayColor;
  bool _findMyBuddyEnabled = false;
  String _buddyName = '';
  String _buddyList = '';
  final List<String> _availableColors = ['White', 'Yellow', 'Red', 'Green', 'Blue'];
  final List<String> _buddyNames = ['Alice', 'Bob', 'Charlie'];

  @override
  void initState() {
    super.initState();
    // Inizializza le variabili locali con i valori globali
    _voiceNotificationsEnabled = GlobalSettings.voiceNotificationsEnabled;
    _overlayColor = GlobalSettings.overlayColor;
  }

  void _showBuddies() {
    setState(() {
      _buddyList = _buddyNames.join(', ');
    });
  }

  // Funzione per mappare i nomi dei colori ai valori Color
  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.white;
    }
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
                      GlobalSettings.voiceNotificationsEnabled = value; // Aggiorna lo stato globale
                    });
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Parameter Overlay Color
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Parameter Overlay Color',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: _overlayColor,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(fontSize: 16),
                  items: _availableColors.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(color: _getColorFromName(value)),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _overlayColor = newValue!;
                      GlobalSettings.overlayColor = newValue; // Aggiorna lo stato globale
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
                  'Find my Buddy™',
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
                      'My Buddy name',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: ' Enter name',
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
                        'Show Buddies',
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