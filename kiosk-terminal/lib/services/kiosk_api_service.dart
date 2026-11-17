import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/brand_config.dart';
import '../models/store_category.dart';
import '../models/store_modifier.dart';
import '../models/store_product.dart';

class CatalogData {
  final List<StoreCategory> categories;
  final List<StoreProduct> products;
  final bool isOfflineDemo;

  const CatalogData({
    required this.categories,
    required this.products,
    this.isOfflineDemo = false,
  });
}

class KioskApiService {
  static const String defaultApiUrl = BrandConfig.apiUrl;
  final String graphqlEndpoint;
  final http.Client _client;

  KioskApiService({
    String? endpoint,
    http.Client? client,
  })  : graphqlEndpoint = endpoint ?? BrandConfig.apiUrl,
        _client = client ?? http.Client();

  /// Fetches the complete catalog (categories and products)
  /// Falls back smoothly to offline demo catalog on error or timeout
  Future<CatalogData> getCatalog({String? branchId}) async {
    try {
      const query = '''
        query GetKioskCatalog(\$branchId: ID!) {
          getKioskCatalog(branchId: \$branchId) {
            categories {
              id
              name
              segment
              imagePath
              active
            }
            products {
              id
              categoryId
              name
              description
              price
              imagePath
              active
              modifierGroups {
                name
                minSelection
                maxSelection
                options {
                  name
                  price
                }
              }
            }
          }
        }
      ''';

      final response = await _client
          .post(
            Uri.parse(graphqlEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'variables': {'branchId': branchId},
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final catalog = data['data']?['getKioskCatalog'];
        if (catalog != null) {
          final rawCategories =
              catalog['categories'] as List<dynamic>? ?? [];
          final rawProducts =
              catalog['products'] as List<dynamic>? ?? [];

          final categories = rawCategories
              .map((c) => StoreCategory.fromJson(c as Map<String, dynamic>))
              .where((c) => c.active)
              .toList();

          final products = rawProducts
              .map((p) => StoreProduct.fromJson(p as Map<String, dynamic>))
              .where((p) => p.isAvailable)
              .toList();

          if (categories.isNotEmpty && products.isNotEmpty) {
            return CatalogData(
              categories: categories,
              products: products,
              isOfflineDemo: false,
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('KioskApiService: Backend offline or unreachable ($e). Using demo catalog.');
      }
    }

    // Fallback to rich offline demo catalog
    return CatalogData(
      categories: _demoCategories,
      products: _demoProducts,
      isOfflineDemo: true,
    );
  }

  /// Fetches a Stripe Terminal ConnectionToken for Tap to Pay
  Future<Map<String, dynamic>> createConnectionToken(String branchId) async {
    const query = '''
      mutation KioskCreateConnectionToken(\$branchId: ID!) {
        kioskCreateConnectionToken(branchId: \$branchId) {
          secret
          publishableKey
        }
      }
    ''';

    try {
      final response = await _client
          .post(
            Uri.parse(graphqlEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'variables': {'branchId': branchId},
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tokenData = data['data']?['kioskCreateConnectionToken'];
        if (tokenData != null) {
          return {
            'secret': tokenData['secret'] as String? ?? '',
            'publishableKey': tokenData['publishableKey'] as String? ?? '',
            'isMock': false,
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('KioskApiService: createConnectionToken fallback: $e');
      }
    }

    // Fallback token for offline / simulation testing
    return {
      'secret': 'pst_test_conn_token_${DateTime.now().millisecondsSinceEpoch}',
      'publishableKey': 'pk_test_sample_key',
      'isMock': true,
    };
  }

  /// Creates a PaymentIntent on the backend for card_present (Terminal Tap to Pay)
  Future<Map<String, dynamic>> createPaymentIntent({
    required String branchId,
    required double amount,
    String currency = 'USD',
  }) async {
    const query = '''
      mutation KioskCreatePaymentIntent(\$branchId: ID!, \$amount: Float!, \$currency: String) {
        kioskCreatePaymentIntent(branchId: \$branchId, amount: \$amount, currency: \$currency) {
          id
          clientSecret
          publishableKey
        }
      }
    ''';

    try {
      final response = await _client
          .post(
            Uri.parse(graphqlEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'variables': {
                'branchId': branchId,
                'amount': amount,
                'currency': currency,
              },
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final piData = data['data']?['kioskCreatePaymentIntent'];
        if (piData != null) {
          return {
            'id': piData['id'] as String? ?? '',
            'clientSecret': piData['clientSecret'] as String? ?? '',
            'publishableKey': piData['publishableKey'] as String? ?? '',
            'isMock': false,
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('KioskApiService: createPaymentIntent fallback: $e');
      }
    }

    // Fallback payment intent for offline / simulation testing
    final mockId = 'pi_kiosk_test_${DateTime.now().millisecondsSinceEpoch}';
    return {
      'id': mockId,
      'clientSecret': '${mockId}_secret_test',
      'publishableKey': 'pk_test_sample_key',
      'isMock': true,
    };
  }

  /// Submits the final paid / counter order to the backend and triggers KDS & Kitchen Auto-print
  Future<Map<String, dynamic>> createKioskOrder(Map<String, dynamic> input) async {
    const query = '''
      mutation CreateKioskOrder(\$input: CreateKioskOrderInput!) {
        createKioskOrder(input: \$input) {
          id
          status
          paymentStatus
          paymentMethod
          paymentAmount
          deliveryMethod
          tableNumber
          pagerNumber
          kioskDeviceId
          createdAt
        }
      }
    ''';

    try {
      final response = await _client
          .post(
            Uri.parse(graphqlEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'variables': {'input': input},
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawOrder = data['data']?['createKioskOrder'];
        if (rawOrder != null) {
          final order = Map<String, dynamic>.from(rawOrder as Map);
          order['totalPrice'] ??= order['paymentAmount'];
          final id = (order['id'] ?? '').toString();
          order['orderCode'] ??= id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id;
          order['orderNumber'] ??= order['orderCode'];
          return {
            'success': true,
            'order': order,
          };
        }
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return {
            'success': false,
            'message': errors.first['message'] ?? 'Error al registrar orden',
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('KioskApiService: createKioskOrder error: $e');
      }
    }

    // Offline demo fallback order
    final mockCode = (100 + (DateTime.now().millisecond % 900)).toString();
    return {
      'success': true,
      'order': {
        'id': 'ord_${DateTime.now().millisecondsSinceEpoch}',
        'orderNumber': int.tryParse(mockCode) ?? 42,
        'orderCode': '#$mockCode',
        'status': 'PENDING',
        'paymentStatus': input['paymentMethod'] == 'COUNTER' ? 'PENDING' : 'PAID',
        'paymentMethod': input['paymentMethod'] ?? 'CARD',
        'totalPrice': 0.0,
        'deliveryType': input['deliveryType'] ?? 'dine_in',
        'tableNumber': input['tableNumber'],
        'createdAt': DateTime.now().toIso8601String(),
      },
    };
  }

  /// Diagnostics: checks connectivity with backend API
  Future<Map<String, dynamic>> testConnection([String? testUrl]) async {
    final stopwatch = Stopwatch()..start();
    final url = testUrl ?? graphqlEndpoint;
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': '{ __typename }',
            }),
          )
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();
      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'latencyMs': stopwatch.elapsedMilliseconds,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'error': e.toString(),
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Rich Offline Demo Catalog (Immediate browsing and testing)
  // ---------------------------------------------------------------------------

  static final List<StoreCategory> _demoCategories = [
    const StoreCategory(
      id: 'cat_burgers',
      name: 'Hamburguesas',
      segment: 'RETAIL',
      order: 1,
      icon: Icons.lunch_dining_rounded,
    ),
    const StoreCategory(
      id: 'cat_pizzas',
      name: 'Pizzas Artesanales',
      segment: 'RETAIL',
      order: 2,
      icon: Icons.local_pizza_rounded,
    ),
    const StoreCategory(
      id: 'cat_drinks',
      name: 'Bebidas & Refrescos',
      segment: 'RETAIL',
      order: 3,
      icon: Icons.local_drink_rounded,
    ),
    const StoreCategory(
      id: 'cat_desserts',
      name: 'Postres & Helados',
      segment: 'RETAIL',
      order: 4,
      icon: Icons.icecream_rounded,
    ),
    const StoreCategory(
      id: 'cat_snacks',
      name: 'Snacks & Entradas',
      segment: 'RETAIL',
      order: 5,
      icon: Icons.tapas_rounded,
    ),
  ];

  static final List<StoreProduct> _demoProducts = [
    // Burgers
    const StoreProduct(
      id: 'prod_burger_classic',
      name: 'Hamburguesa Clásica Artesanal',
      description:
          'Carne 100% de res a la parrilla (200g), lechuga fresca, tomate de huerto y aderezo especial en pan brioche tostado.',
      price: 9.99,
      categoryId: 'cat_burgers',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Término de la Carne',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'meat_med',
              name: 'Término Medio (Jugosa)',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'meat_three_q',
              name: 'Tres Cuartos',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'meat_well_done',
              name: 'Bien Cocida',
              price: 0.0,
            ),
          ],
        ),
        StoreModifierGroup(
          name: 'Tipo de Queso',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'cheese_cheddar',
              name: 'Cheddar Añejo Fundido',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'cheese_swiss',
              name: 'Queso Suizo Ahumado',
              price: 1.00,
            ),
            StoreModifierOption(
              id: 'cheese_none',
              name: 'Sin Queso',
              price: 0.0,
            ),
          ],
        ),
        StoreModifierGroup(
          name: 'Toppings & Extras',
          minSelection: 0,
          maxSelection: 4,
          options: [
            StoreModifierOption(
              id: 'top_bacon',
              name: 'Tocino Crujiente Premium',
              price: 1.50,
            ),
            StoreModifierOption(
              id: 'top_egg',
              name: 'Huevo Frito a la Plancha',
              price: 1.25,
            ),
            StoreModifierOption(
              id: 'top_onion',
              name: 'Cebolla Caramelizada al Vino',
              price: 0.75,
            ),
            StoreModifierOption(
              id: 'top_jalapenos',
              name: 'Jalapeños Encurtidos',
              price: 0.50,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_burger_bacon',
      name: 'Doble Bacon Cheddar Deluxe',
      description:
          'Dos medallones de carne Angus (360g), doble porción de tocino ahumado en manzano y queso cheddar fundido.',
      price: 13.50,
      categoryId: 'cat_burgers',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Término de la Carne',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'bacon_med',
              name: 'Término Medio',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'bacon_well',
              name: 'Bien Cocida',
              price: 0.0,
            ),
          ],
        ),
        StoreModifierGroup(
          name: 'Extras Opcionales',
          minSelection: 0,
          maxSelection: 3,
          options: [
            StoreModifierOption(
              id: 'top_guac',
              name: 'Guacamole Rústico',
              price: 1.75,
            ),
            StoreModifierOption(
              id: 'top_bbq',
              name: 'Salsa BBQ Ahumada Extra',
              price: 0.50,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_chicken_crispy',
      name: 'Crispy Chicken Sandwich',
      description:
          'Pechuga de pollo crujiente marinada con especias secretas, pepinillos dulces y mayonesa de sriracha suave.',
      price: 10.75,
      categoryId: 'cat_burgers',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Nivel de Picante',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'spicy_mild',
              name: 'Suave / Cero Picante',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'spicy_medium',
              name: 'Picante Moderado',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'spicy_fire',
              name: 'Extra Picante Habanero',
              price: 0.50,
            ),
          ],
        ),
      ],
    ),

    // Pizzas
    const StoreProduct(
      id: 'prod_pizza_pepperoni',
      name: 'Pizza Pepperoni Suprema',
      description:
          'Masa fermentada 48 horas, salsa pomodoro casera, queso mozzarella fior di latte y generoso pepperoni crocante.',
      price: 14.99,
      categoryId: 'cat_pizzas',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Tamaño de Pizza',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'size_ind',
              name: 'Personal (4 Rebanadas)',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'size_med',
              name: 'Mediana (8 Rebanadas)',
              price: 4.50,
            ),
            StoreModifierOption(
              id: 'size_fam',
              name: 'Familiar (12 Rebanadas)',
              price: 8.00,
            ),
          ],
        ),
        StoreModifierGroup(
          name: 'Tipo de Masa',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'crust_trad',
              name: 'Tradicional Italiana',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'crust_thin',
              name: 'Fina & Crocante',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'crust_cheese',
              name: 'Borde Relleno de Mozzarella',
              price: 2.50,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_pizza_four_cheese',
      name: 'Pizza Cuatro Quesos Gourmet',
      description:
          'Mozzarella, Gorgonzola dulce, Parmigiano Reggiano y Ricotta fresca aromatizada con albahaca.',
      price: 15.50,
      categoryId: 'cat_pizzas',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Tamaño de Pizza',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'size_ind_4q',
              name: 'Personal (4 Rebanadas)',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'size_med_4q',
              name: 'Mediana (8 Rebanadas)',
              price: 4.50,
            ),
            StoreModifierOption(
              id: 'size_fam_4q',
              name: 'Familiar (12 Rebanadas)',
              price: 8.00,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_pizza_margarita',
      name: 'Pizza Margarita Clásica',
      description:
          'Pomodoro di San Marzano, mozzarella fresca, aceite de oliva virgen extra y hojas de albahaca fresca.',
      price: 12.00,
      categoryId: 'cat_pizzas',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Tamaño de Pizza',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'size_ind_mar',
              name: 'Personal (4 Rebanadas)',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'size_med_mar',
              name: 'Mediana (8 Rebanadas)',
              price: 4.00,
            ),
          ],
        ),
      ],
    ),

    // Drinks
    const StoreProduct(
      id: 'prod_soda_craft',
      name: 'Refresco Artesanal (Lata 355ml)',
      description:
          'Bebida carbonatada refrescante endulzada con azúcar de caña 100% natural.',
      price: 2.50,
      categoryId: 'cat_drinks',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Sabor de Refresco',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'flavor_cola',
              name: 'Cola Clásica',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'flavor_lemon',
              name: 'Lima Limón Chispeante',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'flavor_orange',
              name: 'Naranja Cítrica',
              price: 0.0,
            ),
          ],
        ),
        StoreModifierGroup(
          name: 'Nivel de Hielo',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'ice_normal',
              name: 'Hielo Normal',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'ice_little',
              name: 'Poco Hielo',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'ice_none',
              name: 'Sin Hielo',
              price: 0.0,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_lemonade_mint',
      name: 'Limonada Natural con Hierbabuena',
      description:
          'Limones recién exprimidos, hojas frescas de hierbabuena y agua purificada.',
      price: 3.50,
      categoryId: 'cat_drinks',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Endulzante',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'sweet_reg',
              name: 'Azúcar Regular',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'sweet_splenda',
              name: 'Stevia / Sin Calorías',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'sweet_none',
              name: 'Sin Azúcar (100% Natural)',
              price: 0.0,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_mineral_water',
      name: 'Agua Mineral de Manantial (500ml)',
      description: 'Agua mineral gasificada pura embotellada de origen.',
      price: 2.00,
      categoryId: 'cat_drinks',
      modifierGroups: [],
    ),

    // Desserts
    const StoreProduct(
      id: 'prod_brownie_icecream',
      name: 'Brownie Caliente con Helado',
      description:
          'Pastel tibio de chocolate amargo 70%, nueces tostadas y una bola de helado cremoso.',
      price: 5.50,
      categoryId: 'cat_desserts',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Sabor de Helado',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'ice_vanilla',
              name: 'Vainilla Bourbon de Papantla',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'ice_choco',
              name: 'Chocolate Oscuro Suizo',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'ice_dulce',
              name: 'Dulce de Leche Artesanal',
              price: 0.50,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_cheesecake_berries',
      name: 'Cheesecake de Frutos Rojos',
      description:
          'Tarta cremosa estilo New York sobre base de galleta con compota de frambuesas y moras silvestres.',
      price: 6.00,
      categoryId: 'cat_desserts',
      modifierGroups: [],
    ),

    // Snacks
    const StoreProduct(
      id: 'prod_rustic_fries',
      name: 'Papas Rústicas en Gajos',
      description:
          'Papas con piel cortadas a mano, sazonadas con sal marina, romero y pimienta negra.',
      price: 4.50,
      categoryId: 'cat_snacks',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Salsas para Acompañar',
          minSelection: 1,
          maxSelection: 2,
          options: [
            StoreModifierOption(
              id: 'dip_ketchup',
              name: 'Ketchup Artesanal',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'dip_bbq',
              name: 'BBQ Ahumada',
              price: 0.0,
            ),
            StoreModifierOption(
              id: 'dip_alioli',
              name: 'Alioli de Ajo Rostizado',
              price: 0.75,
            ),
            StoreModifierOption(
              id: 'dip_cheddar',
              name: 'Queso Cheddar Caliente',
              price: 1.00,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_onion_rings',
      name: 'Aros de Cebolla Rebozados',
      description:
          'Aros de cebolla dulce fritos al momento con rebozado de cerveza crujiente.',
      price: 5.00,
      categoryId: 'cat_snacks',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Aderezo',
          minSelection: 1,
          maxSelection: 1,
          options: [
            StoreModifierOption(
              id: 'dip_ranch',
              name: 'Ranch de Hierbas',
              price: 0.0,
              isDefault: true,
            ),
            StoreModifierOption(
              id: 'dip_mustard',
              name: 'Mostaza Miel',
              price: 0.0,
            ),
          ],
        ),
      ],
    ),
    const StoreProduct(
      id: 'prod_nachos_supreme',
      name: 'Nachos Supremos con Queso',
      description:
          'Totopos de maíz crujientes bañados en queso fundido, frijoles refritos, pico de gallo y jalapeños.',
      price: 7.50,
      categoryId: 'cat_snacks',
      modifierGroups: [
        StoreModifierGroup(
          name: 'Adiciones Opcionales',
          minSelection: 0,
          maxSelection: 2,
          options: [
            StoreModifierOption(
              id: 'nacho_guac',
              name: 'Guacamole Fresco',
              price: 1.50,
            ),
            StoreModifierOption(
              id: 'nacho_meat',
              name: 'Carne Molida Especiada',
              price: 2.00,
            ),
          ],
        ),
      ],
    ),
  ];
}
