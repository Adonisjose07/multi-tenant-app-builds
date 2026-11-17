import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../services/queries.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation; // Init as null to wait for GPS
  bool _permissionDenied = false;

  bool _isLoading = true;
  List<Marker> _markers = [];
  final Set<String> _orderIds = {};
  bool _isOnline = false; // Status tracking
  String? _lastProcessedOrderId; // To prevent duplicate subscription processing
  double _heading = 0.0; // Compass heading


  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLocate();
    
    // Listen to Compass
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading ?? 0.0;
        });
      }
    });
  }

  Future<void> _toggleOnline(bool value) async {
    final service = FlutterBackgroundService();
    if (value) {
      // Start Service
      await initializeService();
      await service.startService();
      
      // Fetch nearby branches
      _fetchNearbyBranches();
    } else {
      service.invoke("stopService");
      setState(() {
         _markers.clear();
         _orderIds.clear();
      });
    }
    
    setState(() => _isOnline = value);
  }

  List<Map<String, dynamic>> _branches = [];
  List<Polyline> _polylines = [];

  Future<void> _fetchNearbyBranches() async {
    if (_currentLocation == null) return;
    print(">>> EXECUTING _fetchNearbyBranches <<<");
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(
      QueryOptions(
        document: gql(Queries.getNearbyBranches),
        variables: {
          'lat': _currentLocation!.latitude,
          'lon': _currentLocation!.longitude,
          'radius': 10
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    
    print(">>> Query Completed. Has Exception: " + result.hasException.toString());

    if (result.hasException) {
      print("Error fetching branches: " + result.exception.toString());
      return;
    }

    final List? data = result.data?['getNearbyBranches'];
    final length = data?.length ?? "null";
    print(">>> Data received: " + length.toString() + " branches");
    
    if (data != null) {
      final first = data.isNotEmpty ? data[0].toString() : 'Empty List';
      print("Sample Branch Data: " + first);
      setState(() {
        _branches = List<Map<String, dynamic>>.from(data);
        _rebuildMarkers();
      });
    }
  }

  void _rebuildMarkers() {
    print(">>> Rebuilding Markers. Branches count: ${_branches.length}");
    _markers.clear();
    for (var branchData in _branches) {
      final branch = branchData['branch'];
      final count = branchData['activeOrdersCount'] ?? 0;
      final lat = branch['location']['lat'];
      final lon = branch['location']['lon'];

      if (lat != null && lon != null) {
         _markers.add(
            Marker(
              point: LatLng(lat.toDouble(), lon.toDouble()),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () => _showBranchOrders(branchData),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Icon(Icons.store, color: Colors.blue, size: 50),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$count",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                  ],
                ),
              ),
            )
         );
      }
    }
  }

  Future<void> _checkPermissionsAndLocate() async {
    setState(() => _permissionDenied = false);
    
    // Check Service Enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() { 
         _isLoading = false; 
         _permissionDenied = true; 
      });
      return;
    }

    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    
    if (status.isPermanentlyDenied) {
      // Open settings
      await openAppSettings();
      if (mounted) setState(() { 
         _isLoading = false; 
         _permissionDenied = true; 
      });
      return;
    }

    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });

      }
    } else {
      if (mounted) setState(() { 
         _isLoading = false; 
         _permissionDenied = true; 
      });
    }
  }

  void _recenter() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _onOrderDispatch(Map<String, dynamic>? data) {
      // When a new order arrives via Subscription
      // We should ideally re-fetch branches or manually find the branch and update it.
      // For MVP V2, let's just re-fetch to keep sync simple.
      print("New Order Event! Refreshing map...");
      _fetchNearbyBranches();
      
      // Optional: Show snackbar
      final order = data?['orderDispatch'];
      if (order != null) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("New Order at ${order['branchId']}")) // In future resolve Branch Name
         );
      }
  }

  void _showBranchOrders(Map<String, dynamic> branchData) {
    final branch = branchData['branch'];
    final List activeOrders = branchData['activeOrders'] ?? [];

    showModalBottomSheet(context: context, builder: (_) {
       return Container(
         padding: const EdgeInsets.all(20),
         height: 400,
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text("${branchData['restaurant']?['name'] ?? 'Restaurant'} - ${branch['name']}", 
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${activeOrders.length} Active Orders", style: const TextStyle(color: Colors.grey)),
              const Divider(),
              Expanded(
                child: activeOrders.isEmpty 
                  ? const Center(child: Text("No active orders")) 
                  : ListView.builder(
                      itemCount: activeOrders.length,
                      itemBuilder: (ctx, i) {
                        final order = activeOrders[i];
                        final orderId = order['id'] as String;
                        final shortId = orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
                        final items = order['items'] as List?;
                        
                        return Card(
                          child: ExpansionTile(
                            leading: const Icon(Icons.fastfood, color: Colors.orange),
                            title: Text("Order #$shortId"),
                            subtitle: Text("Fee: \$" + order['deliveryFee'].toString()),
                            children: [
                               if (items != null && items.isNotEmpty)
                                 ...items.map((item) => ListTile(
                                    dense: true,
                                    title: Text("${item['quantity']}x ${item['name']}"),
                                 )).toList()
                               else
                                 const Padding(padding: EdgeInsets.all(8.0), child: Text("No items details")),
                               
                               Padding(
                                 padding: const EdgeInsets.all(8.0),
                                 child: ElevatedButton.icon(
                                   onPressed: () {
                                     Navigator.pop(context); // Close sheet
                                     _showRoute(order, branch);
                                   },
                                   icon: const Icon(Icons.map),
                                   label: const Text("View Route"),
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.blue, 
                                     foregroundColor: Colors.white,
                                     minimumSize: const Size(double.infinity, 40)
                                   ),
                                 ),
                               )
                            ],
                          ),
                        );
                      }
                    )
              )
           ],
         ),
       );
    });
  }

  Future<List<LatLng>> _getRoutePoints(LatLng start, LatLng end) async {
    print(">>> Fetching Route: " + start.latitude.toString() + "," + start.longitude.toString() + " -> " + end.latitude.toString() + "," + end.longitude.toString());
    
    final urlString = "https://router.project-osrm.org/route/v1/driving/" + 
                      start.longitude.toString() + "," + start.latitude.toString() + ";" + 
                      end.longitude.toString() + "," + end.latitude.toString() + 
                      "?overview=full&geometries=geojson";
    final url = Uri.parse(urlString);
    
    try {
      final response = await http.get(url);
      print(">>> OSRM Response Code: " + response.statusCode.toString());
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        print(">>> Route Points Found: " + coordinates.length.toString());
        return coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      } else {
        print(">>> OSRM Error Body: " + response.body);
      }
    } catch (e) {
      print(">>> Error fetching route: " + e.toString());
    }
    return [start, end]; // Fallback to straight line
  }

  String? _selectedOrderId;

  void _clearSelection() {
     setState(() {
       _polylines = [];
       _selectedOrderId = null;
       // Remove customer marker (last one added) logic could be better but for MVP:
       // We'll just rebuild markers from branches to wipe temporary ones.
       _rebuildMarkers(); 
     });
     // Reset camera to driver?
     if (_currentLocation != null) {
       _mapController.move(_currentLocation!, 15.0);
     }
  }

  bool _isComputingRoute = false;

  Future<void> _showRoute(Map<String, dynamic> order, Map<String, dynamic> branch) async {
     print(">>> _showRoute CALLED for order ${order['id']}");
     setState(() => _isComputingRoute = true); // Start Loading
     
     _selectedOrderId = order['id']; // Track ID

     final branchLoc = LatLng(branch['location']['lat'].toDouble(), branch['location']['lon'].toDouble());
     final deliveryLoc = LatLng(order['deliveryAddress']['lat'].toDouble(), order['deliveryAddress']['lon'].toDouble());
     
     
     if (_currentLocation == null) return;

     // Fetch routes
     final routeToBranch = await _getRoutePoints(_currentLocation!, branchLoc);
     final routeToCustomer = await _getRoutePoints(branchLoc, deliveryLoc);

     setState(() {
       _isComputingRoute = false; // Stop Loading
       _polylines = [
         Polyline(
           points: routeToBranch,
           strokeWidth: 4.0,
           color: Colors.blue,
         ),
         Polyline(
           points: routeToCustomer,
           strokeWidth: 4.0,
           color: Colors.green, // Different color for delivery leg
         ),
       ];
       
       // Add markers for Delivery destination
       _markers.add(
         Marker(
            point: deliveryLoc,
            width: 80, 
            height: 80,
            child: const Column(
              children: [
                 Icon(Icons.person, color: Colors.green, size: 40),
                 Text("Cliente", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
              ],
            ),
         )
       );
     });
     
     // Fit bounds
     final bounds = LatLngBounds.fromPoints([...routeToBranch, ...routeToCustomer]);
     _mapController.fitCamera(
       CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50))
     );
  }

  void _acceptOrder(String orderId) async {
     print("Accepting order $orderId");
     final client = GraphQLProvider.of(context).value;
     
     // Show loading
     showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
     
     final result = await client.mutate(
        MutationOptions(
          document: gql(Queries.acceptOrder),
          variables: {'orderId': orderId}
        )
     );
     
     Navigator.pop(context); // Close loading
     
     if (result.hasException) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result.exception}")));
     } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Accepted! 🚀")));
       _clearSelection();
       // Navigate to Active Order Screen?
       // For now just clear map
       _fetchNearbyBranches(); // Refresh map
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
       return Scaffold(
         body: Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.location_disabled, size: 60, color: Colors.grey),
               const SizedBox(height: 10),
               const Text("Location Permission Required", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 5),
               const Text("To use the radar, please enable location access."),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: _checkPermissionsAndLocate, 
                 child: const Text("Retry / Open Settings")
               )
             ],
           ),
         ),
       );
    }

    if (_isLoading || _currentLocation == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               CircularProgressIndicator(),
               SizedBox(height: 10),
               Text("Locating..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Radar"),
        actions: [
          Switch(
            value: _isOnline, 
            onChanged: (v) => _toggleOnline(v)
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenter,
        child: const Icon(Icons.my_location),
      ),
      body: Subscription(
        options: SubscriptionOptions(
          document: gql(Queries.orderDispatch),
          variables: {
            'lat': _currentLocation!.latitude,
            'lon': _currentLocation!.longitude,
            'radius': 10 // km
          },
        ),
        builder: (QueryResult result) {
           if (result.hasException) {
             print("Subscription Error: ${result.exception}");
           }
           
           if (result.isLoading) {
             // Subscription is active but waiting for data
           }

           if (result.data != null) {
              final newOrder = result.data!['orderDispatch'];
              final newOrderId = newOrder?['id'];
              
              if (newOrderId != null && newOrderId != _lastProcessedOrderId) {
                 _lastProcessedOrderId = newOrderId;
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onOrderDispatch(result.data);
                 });
              }
           }

           return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', // Grey/Light tiles
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.platform.driver',
                ),
                PolylineLayer(
                  polylines: _polylines, 
                ),
                MarkerLayer(
                  markers: [
                    // Driver Location
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: Transform.rotate(
                         angle: (_heading * (math.pi / 180) * -1), // Maps rotate opposite to compass heading needs
                         child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
                      ),
                    ),
                    ..._markers
                  ],
                ),
                
                // Action Buttons (Only visible when a route is active)
                if (_polylines.isNotEmpty)
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             const Text("Order Selected", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             const SizedBox(height: 10),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                               children: [
                                 ElevatedButton.icon(
                                   onPressed: _clearSelection,
                                   icon: const Icon(Icons.close),
                                   label: const Text("Cancel"),
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                 ),
                                 ElevatedButton.icon(
                                   onPressed: () {
                                     // Assuming we have the order orderId stored or passed. 
                                     // For now we need to track the selected order ID in state.
                                     if (_selectedOrderId != null) {
                                       _acceptOrder(_selectedOrderId!);
                                     }
                                   },
                                   icon: const Icon(Icons.check),
                                   label: const Text("Accept"),
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                 ),
                               ],
                             )
                          ],
                        ),
                      ),
                    ),
                  ),

                // Loading Indicator for Route Calculation
                if (_isComputingRoute)
                  Container(
                    color: Colors.black38,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           CircularProgressIndicator(color: Colors.white),
                           SizedBox(height: 10),
                           Text("Calculating Route...", style: TextStyle(color: Colors.white))
                        ],
                      ),
                    ),
                  )
              ],
            );
        }
      ),
    );
  }
}
