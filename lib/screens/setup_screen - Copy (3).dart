import 'package:flutter/material.dart';

import 'menu_screen.dart'; // Importa menu_screen.dart per la navigazione

// Classe per gestire le variabili globali
class GlobalSettings {
  static bool voiceNotificationsEnabled = false;
  static String overlayColor = 'White';
  static String language = 'English'; // Variabile globale per la lingua
  static bool tapIconsToExit = true; // Variabile globale per tap icons to exit
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late bool _voiceNotificationsEnabled;
  late String _overlayColor;
  late String _language; // Variabile locale per la lingua
  late bool _tapIconsToExit; // Variabile locale per tap icons to exit
  bool _findMyBuddyEnabled = false;
  String _buddyName = '';
  String _buddyList = '';
  final List<String> _availableColors = ['White', 'Yellow', 'Red', 'Green', 'Blue'];
  final List<String> _availableLanguages = ['Deutsch', 'Français', 'English', 'Español', 'Italiano'];
  final List<String> _buddyNames = ['Alice', 'Bob', 'Charlie'];

  @override
  void initState() {
    super.initState();
    // Inizializza le variabili locali con i valori globali
    _voiceNotificationsEnabled = GlobalSettings.voiceNotificationsEnabled;
    _overlayColor = GlobalSettings.overlayColor;
    _language = GlobalSettings.language; // Inizializza la lingua
    _tapIconsToExit = GlobalSettings.tapIconsToExit; // Inizializza tap icons to exit
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
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Titolo "SETUP"
                const Text(
                  'SETUP',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

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
                      activeColor: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Language
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Language',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    DropdownButton<String>(
                      value: _language,
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(fontSize: 16),
                      items: _availableLanguages.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _language = newValue!;
                          GlobalSettings.language = newValue; // Aggiorna lo stato globale
                        });
                      },
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

                // Tap Icons to Exit Pages
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tap Icons to Exit Pages',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Switch(
                      value: _tapIconsToExit,
                      onChanged: (value) {
                        setState(() {
                          _tapIconsToExit = value;
                          GlobalSettings.tapIconsToExit = value; // Aggiorna lo stato globale
                        });
                      },
                      activeColor: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Find my Buddy
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
                      activeColor: Colors.red,
                    ),
                  ],
                ),

                // My Buddy Name (enabled only when Find my Buddy is ON)
                if (_findMyBuddyEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        const Text(
                          'My Buddy Name',
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

                // Show Buddies Button and List (enabled only when Find my Buddy is ON)
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

                // Spazio finale per evitare che il contenuto venga coperto dal link "Back"
                const SizedBox(height: 50),
              ],
            ),

            // Link "Back" in basso a sinistra
            Positioned(
              bottom: 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MenuScreen()),
                  );
                },
                child: const Text(
                  'Back',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}