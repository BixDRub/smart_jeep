import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'routes.dart';
import 'dart:async';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

//CHANGE IP ON LINE 81

class TestMap extends StatefulWidget {
  const TestMap({super.key});

  @override
  State<TestMap> createState() => _TestMapState();
}

class _TestMapState extends State<TestMap> with SingleTickerProviderStateMixin { //the beginning
  final MapController _mapController = MapController();
  final Map<String, LatLng> vehicles = {};
  final Map<String, String> vehicleRoles = {}; // stores role for each vehicle
  String vehicleId = ''; // persistent per-install UUID 
  String userRole = 'driver'; // 'driver' or 'commuter'
  LatLng? vehiclePosition;
  late RouteData selectedRoute;

  // Haylayt route
  String? highlightedRouteName;

  // Animasyon darku daa
  late AnimationController _overlayController;
  late Animation<double> _overlayAlpha;

  StreamSubscription<Position>? positionStream; ///this is to listen for the updates

  // TRANSMITTER
  IOWebSocketChannel? channel; //this is to send the coordinates to the server
  String lastSent = "No coordinates sent yet";
  bool transmit = true;
  bool _hasCenteredOnce = false; //this is to make sure the map ONLY centers on the first update
  DateTime _lastSentTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() { //this is the first thing that runs when the widget is created
    super.initState();
    vehiclePosition = LatLng(13.9, 121.2); //this is a placeholder position (somewhere in the Philippines hehe)

    if (allRouteData.isNotEmpty) { //if we have route data, select the first one by default
      selectedRoute = allRouteData.first; 
    } else {
      selectedRoute = RouteData( //if no route data, create a dummy one 
        name: "Default",
        coordinates: [LatLng(13.9, 121.2)],
        laneColors: [Colors.blue, Colors.orange],
      );
    }

    _overlayController = AnimationController( //this is for the dark overlay when u select a route
      vsync: this,
      duration: const Duration(milliseconds: 300), //smooth transition
    );

    _overlayAlpha = Tween<double>(begin: 0.0, end: 0.25).animate( //this is the animation for the overlay's opacity
      CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut), //SMOOOOOOOTH
    );

    // Initialize persistent ID, then start GPS and websocket so sends use the correct ID
    _initVehicleId().then((_) {
      _startGpsUpdates();
      if (transmit) _connectWebSocket();
    });
  }

  Future<void> _initVehicleId() async { //even more persisstent ID
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('vehicle_id');
    bool isFirstTime = false;
    if (id == null || id.isEmpty) { //if no ID stored, generate a new one 
      id = const Uuid().v4();
      await prefs.setString('vehicle_id', id);
      isFirstTime = true;
    }
    
    // Load user role
    var role = prefs.getString('user_role');
    if (role == null || role.isEmpty) {
      role = 'driver'; // default to driver
      await prefs.setString('user_role', role);
    }
    
    setState(() {
      vehicleId = id!;
      userRole = role!;
      vehicles[vehicleId] = vehiclePosition ?? LatLng(13.9, 121.2);
      vehicleRoles[vehicleId] = userRole;
    });
    
    // Show role selection dialog on first launch
    if (isFirstTime && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Select Your Role"),
          content: const Text("Are you a driver or a commuter?"),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_role', 'driver');
                setState(() {
                  userRole = 'driver';
                  vehicleRoles[vehicleId] = 'driver';
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Driver"),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_role', 'commuter');
                setState(() {
                  userRole = 'commuter';
                  vehicleRoles[vehicleId] = 'commuter';
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Commuter"),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() { //clean up resources when the widget is removed
    _overlayController.dispose(); //remove der animation controller
    positionStream?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  // Websocket SERVERRR
  void _connectWebSocket() {
    const serverUrl =
        'wss://transitlink.onrender.com'; //HEREEEEEEEEEEEEEEEEEEEEEEEEEE
    channel = IOWebSocketChannel.connect(serverUrl);

    channel?.stream.listen( //listen for messages from ze server
      (message) {
        final parts = message.toString().split(",");

        if (parts.length >= 3) { //expecting "id,lat,lng" or "id,lat,lng,role"
          final id = parts[0];
          final lat = double.tryParse(parts[1]); //parsing 
          final lng = double.tryParse(parts[2]);
          final role = parts.length >= 4 ? parts[3] : 'driver'; // default to driver if not provided

          if (lat != null && lng != null) { //successful parsibg = update ze location
            setState(() {
              vehicles[id] = LatLng(lat, lng);
              vehicleRoles[id] = role;
            });
          }
        }
      },
      onError: (error) { //if websocket got an error. Debugging onle
        debugPrint("WebSocket error: $error");
      },
      onDone: () {
        debugPrint("WebSocket closed");
      },
    );
  }

  // START GPS UPDATES
  void _startGpsUpdates() //This second listening thingy is for the device only. The othe rone is for the server
  async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS is disabled.");
      return;
      
    }

    LocationPermission permission = await Geolocator.checkPermission(); // GET DA PERMISSION (NEED PRECISE)
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // CONTINUE TO UPDATE
    positionStream = //this part is to avoid overloading older phones
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((Position pos) {
          final newPos = LatLng(pos.latitude, pos.longitude);
          setState(() {
            vehiclePosition = newPos;
            vehicles[vehicleId] = newPos;
          });
          if (!_hasCenteredOnce) {
            _mapController.move(newPos, 16);
            _hasCenteredOnce = true;
          }

          // SEND COORDS BLYAD SUKA
          final now = DateTime.now(); // throttle the sending to once every 3 seconds to avoid spamming the server 
          if (transmit &&
              channel != null &&
              now.difference(_lastSentTime).inSeconds >= 3) {
            final coords = "$vehicleId,${pos.latitude},${pos.longitude},$userRole";
            channel?.sink.add(coords);
            setState(() => lastSent = coords);
            _lastSentTime = now;
            debugPrint("Sent: $coords");
          }
        });
  }

  void switchRoute(RouteData route) { //this is for when u select a route from the dropdown
    setState(() {
      selectedRoute = route;
      highlightedRouteName = null;
      _overlayController.reverse();
      if (vehiclePosition != null) _mapController.move(vehiclePosition!, 13);
    });
  }

  bool _isNearPolyline( //tap detection
    LatLng tap,
    List<LatLng> polyline, {
    double threshold = 0.0000006,
  }) {
    for (int i = 0; i < polyline.length - 1; i++) { //polyline stuff. Just checks if the tap is close. I almost died tryna make this work
      final p1 = polyline[i];
      final p2 = polyline[i + 1];
      final dx = p2.longitude - p1.longitude;
      final dy = p2.latitude - p1.latitude;
      if (dx == 0 && dy == 0) continue;
      final t =
          ((tap.longitude - p1.longitude) * dx +
              (tap.latitude - p1.latitude) * dy) /
          (dx * dx + dy * dy);
      final closest = LatLng(
        p1.latitude + (dy * t).clamp(0, 1),
        p1.longitude + (dx * t).clamp(0, 1),
      );
      final dist = Distance().as(LengthUnit.Kilometer, tap, closest);
      if (dist < threshold) return true;
    }
    return false;
  }

  void _handleTap(LatLng tap) {
    if (allRouteData.isEmpty) return;

    final nearbyRoutes = allRouteData.where((route) {
      for (final lane in route.lanes) {
        if (_isNearPolyline(tap, lane, threshold: 0.00000015)) return true;
      }
      return false;
    }).toList();

    if (nearbyRoutes.isEmpty) {
      setState(() {
        highlightedRouteName = null;
        _overlayController.reverse();
      });
      return;
    }

    if (nearbyRoutes.length == 1) {
      setState(() {
        highlightedRouteName = nearbyRoutes.first.name;
        _overlayController.forward();
      });
    } else {
      showModalBottomSheet(
        context: context,
        builder: (_) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: nearbyRoutes.map((route) {
              return ListTile(
                title: Text(route.name),
                onTap: () {
                  setState(() {
                    highlightedRouteName = route.name;
                    _overlayController.forward();
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          );
        },
      );
    }
  }

  void _unselectRoute() {
    setState(() {
      highlightedRouteName = null;
      _overlayController.reverse();
    });
  }

  void _toggleRole() async {
    final newRole = userRole == 'driver' ? 'commuter' : 'driver';
  
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole);
    setState(() {
      userRole = newRole;
      vehicleRoles[vehicleId] = newRole;
    });
    
    // new update based on role
    if (transmit && channel != null && vehiclePosition != null) {
      final coords = "$vehicleId,${vehiclePosition!.latitude},${vehiclePosition!.longitude},$userRole";
      channel?.sink.add(coords);
      setState(() => lastSent = coords);
      _lastSentTime = DateTime.now();
      debugPrint("Sent role update: $coords");
    }
  }

  bool _shouldShowVehicle(String vehicleId) {
    if (vehicleId == this.vehicleId) return true; // always show yourself
    
    final otherVehicleRole = vehicleRoles[vehicleId];
    
    if (userRole == 'driver') {
      // Drivers see all drivers and all commuters
      return true;
    } else {
      // Commuters only see drivers
      return otherVehicleRole == 'driver';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TransitLink"),
        actions: [
          // Role toggle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: GestureDetector(
                onTap: _toggleRole,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        userRole == 'driver' ? Icons.directions_bus : Icons.person,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        userRole == 'driver' ? 'Driver' : 'Commuter',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (allRouteData.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<RouteData>(
                value: selectedRoute,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                dropdownColor: Colors.blueAccent,
                items: allRouteData.map((route) {
                  return DropdownMenuItem<RouteData>(
                    value: route,
                    child: Text(
                      route.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) switchRoute(value);
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(13.9, 121.2),
              initialZoom: 13,
              maxZoom: 19,
              onTap: (_, latlng) => _handleTap(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.smart_jeep.capstone',
              ),

              // Haylayt routes
              if (allRouteData.isNotEmpty) // if function is to help the thing not break when we got no route data. Idk why I added this because we always have route data 
                PolylineLayer(
                  polylines: allRouteData.expand((route) {
                    final isHighlighted = route.name == highlightedRouteName;

                    return List.generate(route.lanes.length, (i) { 
                      return Polyline(
                        points: route.lanes[i],
                        color: isHighlighted
                            ? route.laneColors[i]
                            : route.laneColors[i].withAlpha(
                                (0.25 * 255).toInt(),
                              ),
                        strokeWidth: isHighlighted ? 6 : 4,
                        borderColor: Colors.black,
                        borderStrokeWidth: 2,
                      );
                    });
                  }).toList(),
                ),

              // Vehicle marker (Si Mark... TAHIMIK LANG~)
              MarkerLayer( //this is the thing that marks the vehicle position)
                markers: vehicles.entries
                    .where((entry) => _shouldShowVehicle(entry.key))
                    .map((entry) {
                  final id = entry.key;
                  final pos = entry.value;
                  final role = vehicleRoles[id] ?? 'driver';

                  return Marker(
                    point: pos,
                    width: 50,
                    height: 50,
                    child: Icon(
                      role == 'driver'
                          ? Icons.directions_bus
                          : Icons.person,
                      color: id == vehicleId ? Colors.green : Colors.blue,
                      size: 40,
                    ),
                  );
                }).toList(),
              ),

              // Last sent coords
              if (transmit) //just for the bottom info box
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white70,
                    child: Text(
                      "Last sent: $lastSent",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),

          // Darku oberlayu
          AnimatedBuilder( //this is the dark overlay when u select a route
            animation: _overlayController,
            builder: (_, _) {
              return IgnorePointer(
                ignoring: true,
                child: Container(
                  color: highlightedRouteName == null
                      ? Colors.transparent
                      : Colors.black.withAlpha(
                          (_overlayAlpha.value * 255).toInt(),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: highlightedRouteName != null //show unselect button
          ? FloatingActionButton(
              backgroundColor: Colors.redAccent,
              onPressed: _unselectRoute,
              tooltip: "Unselect Route",
              child: const Icon(Icons.close),
            )
          : null,
    );
  }
}
