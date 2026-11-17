import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'graphql_service.dart';
import 'queries.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // 2. Get Token
    String? token = await _messaging.getToken();
    print("FCM Token: \$token");
    
    if (token != null) {
      await _sendTokenToBackend(token);
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen(_sendTokenToBackend);

    // 3. Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showNotification(message);
      }
    });
    
    // 4. Background/Terminated Messages are handled by system tray usually, 
    // or setBackgroundMessageHandler in main.dart
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
            
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await _localNotifications.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        platformChannelSpecifics,
        payload: message.data.toString());
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? authToken = prefs.getString('auth_token');
      if (authToken == null) return; // Not logged in

      final HttpLink httpLink = HttpLink(GraphQLService.httpEndpoint);
      final AuthLink authLink = AuthLink(getToken: () => authToken != null ? 'Bearer $authToken' : null);
      final Link link = authLink.concat(httpLink);
      final GraphQLClient client = GraphQLClient(
        link: link,
        cache: GraphQLCache(),
      );

      await client.mutate(
        MutationOptions(
          document: gql(Queries.updateDriverPushToken),
          variables: {'token': fcmToken},
        )
      );
      print("FCM Token updated on backend");
    } catch (e) {
      print("Failed to update FCM token: \$e");
    }
  }
}
