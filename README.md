# NexGaze

## Overview
NexGaze is an innovative Internet of Things (IoT) project developed for the 2024/2025 academic year as part of the Master of Science in Engineering at SUPSI. Built as a Flutter application, NexGaze delivers a wearable smart-glasses solution for endurance athletes, integrating real-time biometric and environmental data into a heads-up display (HUD). By leveraging off-the-shelf hardware like Xreal One glasses, Garmin HRM-Dual, and BrainBit EEG, NexGaze provides glance-free performance metrics for activities such as hiking, running, cycling, skiing, yoga, and relaxation, enhancing safety and focus.

## Features

*   **Activity-Specific Modes:** Tailored interfaces for Hiking, Running, Cycling, Skiing, Yoga, and Relax, displaying only relevant metrics (e.g., heart rate, pace, altitude, cognitive states).
*   **Real-Time Biometric Feedback:** Integrates with Garmin HRM-Dual for heart rate and BrainBit for EEG-based stress/focus monitoring.
*   **GPS and Mapping:** Supports flutter_map, google_maps_flutter, Swisstopo, and OpenSnowMap for precise navigation and route visualization.
*   **Text-to-Speech:** Provides audio feedback via flutter_tts to minimize visual distractions during activities.
*   **Hands-Free Interaction:** Uses a Bluetooth ring controller for seamless mode switching and map control.
*   **Intuitive UI:** Clean, minimalist design with custom icons, fonts, and high-contrast HUD layouts optimized for glanceability.
*   **Secure Data Handling:** Local-first architecture with encrypted Bluetooth communication, ensuring user privacy.

## System Architecture
NexGaze leverages a smartphone-centric architecture:

*   **Smart Glasses:** Xreal One displays Full HD HUD via HDMI-over-USB-C.
*   **Smartphone:** RedMagic 9S Pro processes data and streams visuals.
*   **Sensors:** Garmin HRM-Dual (heart rate), BrainBit (EEG), and smartphone sensors (GPS, IMU).
*   **Connectivity:** Bluetooth Low Energy (BLE) for sensor communication, supported by flutter_blue_plus.


## Dependencies

### Core

*   `flutter`: Flutter SDK for cross-platform development.
*   `cupertino_icons`: `^1.0.6`: iOS-style icons.

### Mapping & Location

*   `flutter_map`: `^6.1.0`: OpenStreetMap-based mapping.
*   `latlong2`: `^0.9.0`: Coordinate handling.
*   `geolocator`: `^10.1.0`: GPS location services.
*   `google_maps_flutter`: `^2.5.0`: Google Maps integration.

### State Management & Utilities

*   `provider`: `^6.0.5`: State management.
*   `http`: `^1.1.0`: API requests (e.g., Open-Meteo weather).
*   `flutter_tts`: `^3.8.3`: Text-to-speech.
*   `permission_handler`: `^11.0.1`: Runtime permissions.
*   `flutter_blue_plus`: `^1.4.0`: Bluetooth BLE communication.

### UI & Assets

*   `flutter_launcher_icons`: `^0.13.1`: Custom app icons.
*   `custom_icons`: `^1.1.0`: Custom-designed icons for HUD and app.

## Assets

### Icons

*   `assets/icons/

### Images

*   `assets/images/

### Fonts

*   `assets/fonts/downlink.otf`: Custom font for HUD readability.

### Videos

*   `assets/videos/`:   video assets for yoga and relax.

## Installation

### Prerequisites

*   **Flutter:** Version 3.x (stable channel).
*   **Dart:** Included with Flutter.
*   **IDE:** Android Studio (with Flutter plugin) or Visual Studio Code (with Flutter/Dart extensions).
*   **Hardware:** Android device (12.0+ recommended) for testing, plus optional Xreal One glasses, Garmin HRM-Dual, and BrainBit EEG.

### Steps

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/your-repo/nexgaze.git
    cd nexgaze
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Google Maps API Key:**

    *   Obtain an API key from Google Cloud Console.
    *   **Android:** Add to `android/app/src/main/AndroidManifest.xml`:
        ```xml
        <manifest ...>
          <application ...>
            <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_API_KEY"/>
          </application>
        </manifest>
        ```

    *   **iOS:** Add to `ios/Runner/AppDelegate.swift` or `Info.plist`:
        ```xml
        <key>GoogleMapsApiKey</key>
        <string>YOUR_API_KEY</string>
        ```

4.  **Run the App:**
    ```bash
    flutter run
    ```


## Usage

*   **Launch the App:** Open NexGaze on your Android device.
*   **Grant Permissions:** Allow Bluetooth, location, and sensor access when prompted.
*   **Select Mode:** Choose from Hiking, Running, Cycling, Skiing, Yoga, or Relax on the main menu.
*   **Connect Sensors:** Pair with Garmin HRM-Dual and/or BrainBit via Bluetooth (automatic for unpaired devices).
*   **View Metrics:** Real-time data (e.g., heart rate, GPS, stress) is displayed on the smartphone or Xreal glasses HUD.
*   **Interact Hands-Free:** Use the Bluetooth ring controller to toggle maps or modes.

## Testing
NexGaze was validated through:

*   **Internal Testing:** Conducted by developers across all modes (except skiing, due to seasonal constraints).
*   **Beta Testing:** Feedback from external users (friends/family) on usability and comfort.

## Contributing
We welcome contributions! To get started:

*   Fork the repository.
*   Create a feature branch (`git checkout -b feature/your-feature`).
*   Commit changes (`git commit -m "Add your feature"`).
*   Push to the branch (`git push origin feature/your-feature`).
*   Open a pull request.

Please follow the Contributor Covenant Code of Conduct.

## Authors

*   Alain Alomia
*   Davide Preatoni
*   Mattia Zamboni


Developed as part of the Master of Science in Engineering, Internet of Things module, SUPSI, 2024/2025.
