import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../config/brand_config.dart';

class GraphQLService {
  static const String apiUrl = BrandConfig.apiUrl;

  static const String wsUrl = BrandConfig.wsUrl;

  static String get httpEndpoint =>
      apiUrl.endsWith('/graphql') ? apiUrl : '$apiUrl/graphql';

  static String get wsEndpoint => wsUrl;

  static HttpLink httpLink = HttpLink(
    httpEndpoint,
    httpClient: TimeoutClient(http.Client(), const Duration(seconds: 15)),
  );

  static WebSocketLink websocketLink = WebSocketLink(
    wsEndpoint,
    config: SocketClientConfig(
      autoReconnect: true,
      inactivityTimeout: const Duration(seconds: 30),
      initialPayload: () async {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('auth_token');
        return {
          'authorization': token != null ? 'Bearer $token' : '',
        };
      },
    ),
  );

  static AuthLink authLink = AuthLink(
    getToken: () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      return token != null ? 'Bearer $token' : null;
    },
  );

  static Link link = Link.split(
    (request) => request.isSubscription,
    websocketLink,
    authLink.concat(httpLink),
  );

  static ValueNotifier<GraphQLClient> client = ValueNotifier(
    GraphQLClient(
      link: link,
      // The default store is the InMemoryStore, which does NOT persist to disk
      cache: GraphQLCache(store: InMemoryStore()),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.networkOnly),
      ),
    ),
  );

  static void resetClient() {
    client.value = GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.networkOnly),
      ),
    );
  }
}

class TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration _timeout;

  TimeoutClient(this._inner, this._timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }
}
