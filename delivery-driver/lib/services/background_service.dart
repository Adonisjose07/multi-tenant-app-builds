import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'graphql_service.dart';
import 'queries.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: false,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Driver',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('auth_token');

  StreamSubscription<Position>? positionSubscription;

  service.on('stopService').listen((event) {
    positionSubscription?.cancel();
    service.stopSelf();
  });
  
  // Setup GraphQL Client for Background using dynamic API endpoint
  final HttpLink httpLink = HttpLink(GraphQLService.httpEndpoint);
  final AuthLink authLink = AuthLink(getToken: () => token != null ? 'Bearer $token' : null);
  final Link link = authLink.concat(httpLink);
  final GraphQLClient client = GraphQLClient(
    link: link,
    cache: GraphQLCache(),
  );

  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      service.setForegroundNotificationInfo(
        title: "Driver",
        content: "Active and broadcasting location",
      );
    }
  }

  // Stream for Location Updates (optimizado: emite según desplazamiento sin timer fijo innecesario)
  positionSubscription = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    ),
  ).listen((Position position) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Driver",
          content: "Active and broadcasting location",
        );
      }
    }

    try {
      // Send Location to Server
      final MutationOptions options = MutationOptions(
        document: gql(Queries.updateDriverLocation),
        variables: {
          'lat': position.latitude,
          'lon': position.longitude,
        },
      );
      
      await client.mutate(options);
      print("Background: Location updated ${position.latitude}, ${position.longitude}");

    } catch (e) {
      print("Background Error: $e");
    }
  });

  // Note: Subscription in background isolate is tricky with just GraphQLClient
  // Usually we use a separate WebSocket connection or just HTTP polling for 'nearby orders' 
  // if we don't want to maintain a full WS in background isolate.
  // For now, let's stick to Location Broadcasting. 
  // Receiving orders via FCM is cleaner for background.
  // BUT if we want *local* immediate notification from WS: 
  // We can try to open a Subscription here. 
}
