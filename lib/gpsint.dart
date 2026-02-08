import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:async';

// zis is lowk redundant lol 
// but it's a good reference for the driver transmitter part of the app, so imma keep it here for now
// plus I plan on doing upgrades in the future, so might as well keep it separate for now
// this is probably gonna be used for the driver + passenger app, since the driver will be sending coordinates and the passenger will be receiving them

class DriverTransmitter extends StatefulWidget {
  final String serverUrl; // ADD WEBSOCKET SERVER HEREEEEE
  const DriverTransmitter({super.key, required this.serverUrl});

  @override
  State<DriverTransmitter> createState() => _DriverTransmitterState();
}

class _DriverTransmitterState extends State<DriverTransmitter> {
  IOWebSocketChannel? channel;
  StreamSubscription<Position>? positionStream;
  String lastSent = "No coordinates sent yet";

  @override
  void initState() {
    super.initState();
    connectWebSocket();
    startSendingLocation();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  void connectWebSocket() {
    channel = IOWebSocketChannel.connect(widget.serverUrl);
    channel?.stream.listen((message) {
      debugPrint("Server: $message");
    }, onError: (error) {
      debugPrint("WebSocket error: $error");
    }, onDone: () {
      debugPrint("WebSocket closed");
    });
  }

  Future<void> startSendingLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    //checker
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      return;
    }

    //get za permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permissions are permanently denied.");
      return;
    }

    //updates
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final coords = "${position.latitude}/${position.longitude}";
      channel?.sink.add(coords);
      setState(() => lastSent = coords);
      debugPrint("Sent: $coords");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Transmitter")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.drive_eta, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text("Sending coordinates to server..."),
            const SizedBox(height: 10),
            Text(lastSent, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
