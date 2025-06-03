import 'package:flutter/material.dart';

import 'menu_screen.dart'; // Import for MenuScreen navigation

// Class to manage global application settings
class GlobalSettings {
  static bool voiceNotificationsEnabled = false; // Enable/disable voice notifications
  static String overlayColor = 'White'; // Default overlay color for UI elements
  static String language = 'English'; // Default language setting
  static bool tapIconsToExit = true; // Enable/disable tap-to-exit on icons
  static int? age; // User's age
  static String? gender; // User's gender
}

// Screen for configuring application settings
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late bool _voiceNotificationsEnabled; // Local state for voice notifications
  late String _overlayColor; // Local state for overlay color
  late String _language; // Local state for language
  late bool _tapIconsToExit; // Local state for tap-to-exit
  bool _findMyBuddyEnabled = false; // Local state for Find my Buddy feature
  String _buddyName = ''; // Input for buddy name
  String _buddyList = ''; // Displayed list of buddies
  final List<String> _availableColors = ['White', 'Yellow', 'Red', 'Green', 'Blue']; // Available color options
  final List<String> _availableLanguages = ['Deutsch', 'Français', 'English', 'Español', 'Italiano']; // Available language options
  final List<String> _buddyNames = ['Alice', 'Bob', 'Charlie']; // Predefined buddy names
  late int? _age; // Local state for age
  late String? _gender; // Local state for gender

  @override
  void initState() {
    super.initState();
    // Initialize local settings with global values
    _voiceNotificationsEnabled = GlobalSettings.voiceNotificationsEnabled;
    _overlayColor = GlobalSettings.overlayColor;
    _language = GlobalSettings.language;
    _tapIconsToExit = GlobalSettings.tapIconsToExit;
    _age = GlobalSettings.age;
    _gender = GlobalSettings.gender;
  }

  // Display the list of available buddies
  void _showBuddies() {
    setState(() {
      _buddyList = _buddyNames.join(', ');
    });
  }

  // Convert color name to Color object for UI rendering
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
      backgroundColor: Colors.black, // Set background to black
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16.0), // Padding for content
              children: [
                // Setup title
                const Text(
                  'SETUP',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Toggle for voice notifications
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
                          GlobalSettings.voiceNotificationsEnabled = value; // Update global setting
                        });
                      },
                      activeColor: Colors.red, // Switch color when active
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Language selection dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Language',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    DropdownButton<String>(
                      value: _language,
                      dropdownColor: Colors.grey[800], // Dropdown background color
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
                          GlobalSettings.language = newValue; // Update global setting
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Overlay color selection dropdown
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
                          GlobalSettings.overlayColor = newValue; // Update global setting
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toggle for tap-to-exit functionality
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
                          GlobalSettings.tapIconsToExit = value; // Update global setting
                        });
                      },
                      activeColor: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Age input field
                Row(
                  children: [
                    const Text(
                      'Age',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter age',
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
                            _age = int.tryParse(value); // Parse input to integer
                            GlobalSettings.age = _age; // Update global setting
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gender selection dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    DropdownButton<String>(
                      value: _gender,
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'F',
                          child: Text('F'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'M',
                          child: Text('M'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _gender = newValue;
                          GlobalSettings.gender = newValue; // Update global setting
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toggle for Find my Buddy feature
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

                // Buddy name input field (visible when Find my Buddy is enabled)
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

                // Show buddies button and list (visible when Find my Buddy is enabled)
                if (_findMyBuddyEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: _showBuddies,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Button color
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

                // Extra space to prevent overlap with Back link
                const SizedBox(height: 50),
              ],
            ),

            // Back link to return to MenuScreen
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