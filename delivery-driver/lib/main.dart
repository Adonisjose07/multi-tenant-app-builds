import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'config/brand_config.dart';
import 'services/graphql_service.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  // We need to initialize Hive for GraphQL Cache if we use HiveStore (omitted for now)
  // await initHiveForFlutter(); 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = BrandConfig.primaryColor;
    return GraphQLProvider(
      client: GraphQLService.client,
      child: MaterialApp(
        title: BrandConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
            surface: BrandConfig.surfaceColor,
          ),
          scaffoldBackgroundColor: BrandConfig.surfaceColor,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
