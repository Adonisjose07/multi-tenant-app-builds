import 'package:flutter/material.dart';
import '../controllers/cart_controller.dart';
import '../controllers/kiosk_session_controller.dart';
import '../models/kiosk_session.dart';
import '../models/store_category.dart';
import '../models/store_product.dart';
import '../services/kiosk_api_service.dart';
import '../widgets/cart_bottom_bar.dart';
import '../widgets/cart_sidebar.dart';
import '../widgets/modifier_modal.dart';
import '../widgets/product_card.dart';

enum CatalogViewState {
  loading,
  loaded,
  empty,
  error,
}

class CatalogScreen extends StatefulWidget {
  final KioskSessionController sessionController;
  final CartController cartController;
  final KioskApiService? apiService;
  final VoidCallback? onProceedToCheckout;

  const CatalogScreen({
    super.key,
    required this.sessionController,
    required this.cartController,
    this.apiService,
    this.onProceedToCheckout,
  });

  static const Color primaryColor = Color(0xFFEA581E);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color darkTextColor = Color(0xFF1E293B);
  static const Color subtleTextColor = Color(0xFF64748B);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late final KioskApiService _apiService;
  late final AnimationController _shimmerController;

  CatalogViewState _viewState = CatalogViewState.loading;
  List<StoreCategory> _categories = [];
  List<StoreProduct> _allProducts = [];
  String? _selectedCategoryId;
  String? _errorMessage;
  bool _isOfflineDemo = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? KioskApiService();

    // Pulse animation controller for State 2 (Loading Shimmer Skeleton)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    widget.sessionController.resetInactivityTimer();
    _loadCatalog();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _viewState = CatalogViewState.loading;
      _errorMessage = null;
    });

    try {
      final catalog = await _apiService.getCatalog();
      if (!mounted) return;

      if (catalog.categories.isEmpty) {
        setState(() {
          _viewState = CatalogViewState.empty;
          _categories = [];
          _allProducts = [];
        });
        return;
      }

      setState(() {
        _categories = catalog.categories;
        _allProducts = catalog.products;
        _isOfflineDemo = catalog.isOfflineDemo;
        _selectedCategoryId = catalog.categories.first.id;
        _viewState = CatalogViewState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = CatalogViewState.error;
        _errorMessage =
            'No se pudo conectar con el servidor de la tienda. Verifica tu conexión.';
      });
    }
  }

  void _onProductTapped(StoreProduct product) {
    widget.sessionController.userInteracted();

    if (!product.isAvailable) return;

    if (product.hasModifiers) {
      ModifierModal.show(
        context,
        product: product,
        onAddToCart: (prod, modifiers, notes, quantity) {
          widget.sessionController.userInteracted();
          widget.cartController.addItem(
            prod,
            modifiers,
            notes: notes,
            quantity: quantity,
          );
          _showAddedSnackbar(prod.name, quantity);
        },
      );
    } else {
      widget.cartController.addItem(product, []);
      _showAddedSnackbar(product.name, 1);
    }
  }

  void _showAddedSnackbar(String productName, int quantity) {
    final msg = quantity > 1
        ? '$quantity x "$productName" agregados al pedido'
        : '"$productName" agregado al pedido';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onCategorySelected(String categoryId) {
    widget.sessionController.userInteracted();
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _handleCheckout() {
    widget.sessionController.userInteracted();
    if (widget.cartController.isEmpty) return;

    if (widget.onProceedToCheckout != null) {
      widget.onProceedToCheckout!();
    } else {
      // Try navigating to /checkout route if registered, else notify ready
      final navigator = Navigator.of(context);
      if (ModalRoute.of(context)?.settings.name != '/checkout') {
        try {
          navigator.pushNamed('/checkout');
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Procesando al módulo de pago...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _confirmCancelOrder() {
    widget.sessionController.userInteracted();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEA581E), size: 28),
            SizedBox(width: 10),
            Text('¿Cancelar y Reiniciar?'),
          ],
        ),
        content: const Text(
          'Se borrarán los productos seleccionados y la información ingresada. Volverás a la pantalla de bienvenida.',
          style: TextStyle(fontSize: 15, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continuar Pedido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.cartController.clear();
              widget.sessionController.resetSession();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sí, Cancelar Todo'),
          ),
        ],
      ),
    );
  }

  List<StoreProduct> get _filteredProducts {
    if (_selectedCategoryId == null) return _allProducts;
    return _allProducts
        .where((p) => p.categoryId == _selectedCategoryId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: CatalogScreen.surfaceColor,
      appBar: _buildAppBar(context, isTablet),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.sessionController.userInteracted(),
        child: isTablet
            ? _buildTabletLayout(screenWidth)
            : _buildMobileLayout(screenWidth),
      ),
      bottomNavigationBar: isTablet
          ? null
          : CartBottomBar(
              cartController: widget.cartController,
              session: widget.sessionController.session,
              onCheckout: _handleCheckout,
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isTablet) {
    final session = widget.sessionController.session;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 26),
        color: CatalogScreen.darkTextColor,
        tooltip: 'Volver a modalidad',
        onPressed: () {
          widget.sessionController.userInteracted();
          Navigator.of(context).pop();
        },
      ),
      title: Row(
        children: [
          const Text(
            'Menú Digital',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: CatalogScreen.darkTextColor,
            ),
          ),
          const SizedBox(width: 12),
          // Dining Mode Badge
          if (session.diningMode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    session.isDineIn
                        ? Icons.restaurant_rounded
                        : Icons.shopping_bag_rounded,
                    size: 15,
                    color: CatalogScreen.primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    session.diningMode!.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CatalogScreen.primaryColor,
                    ),
                  ),
                  if (session.tableOrPagerNumber != null &&
                      session.tableOrPagerNumber!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '#${session.tableOrPagerNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: CatalogScreen.darkTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_isOfflineDemo) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Modo Demo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CatalogScreen.subtleTextColor,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _confirmCancelOrder,
          icon: const Icon(
            Icons.restart_alt_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          label: const Text(
            'Reiniciar',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Responsive Layouts (Mobile vs Tablet)
  // ---------------------------------------------------------------------------

  Widget _buildMobileLayout(double screenWidth) {
    return Column(
      children: [
        // Horizontal category selector
        _buildCategoryHorizontalChips(),
        // Main Content Area with 5 UI States
        Expanded(child: _buildStateContent(screenWidth, isTablet: false)),
      ],
    );
  }

  Widget _buildTabletLayout(double screenWidth) {
    return Row(
      children: [
        // Main Catalog Section (Categories + Grid)
        Expanded(
          child: Column(
            children: [
              _buildCategoryHorizontalChips(),
              Expanded(child: _buildStateContent(screenWidth, isTablet: true)),
            ],
          ),
        ),
        // Persistent Right Cart Sidebar
        CartSidebar(
          cartController: widget.cartController,
          session: widget.sessionController.session,
          onCheckout: _handleCheckout,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Category Navigation Chips
  // ---------------------------------------------------------------------------

  Widget _buildCategoryHorizontalChips() {
    if (_viewState == CatalogViewState.loading) {
      return _buildCategorySkeletonChips();
    }
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category.id == _selectedCategoryId;

          return InkWell(
            onTap: () => _onCategorySelected(category.id),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? CatalogScreen.primaryColor
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: CatalogScreen.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  if (category.icon != null) ...[
                    Icon(
                      category.icon,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : CatalogScreen.darkTextColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : CatalogScreen.darkTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5 UI States Rendering
  // ---------------------------------------------------------------------------

  Widget _buildStateContent(double screenWidth, {required bool isTablet}) {
    switch (_viewState) {
      case CatalogViewState.loading:
        return _buildLoadingSkeletonState(screenWidth, isTablet);

      case CatalogViewState.error:
        return _buildErrorState();

      case CatalogViewState.empty:
        return _buildEmptyState(
          title: 'No hay productos disponibles',
          subtitle: 'El catálogo del restaurante se encuentra temporalmente vacío.',
        );

      case CatalogViewState.loaded:
        final items = _filteredProducts;
        if (items.isEmpty) {
          return _buildEmptyState(
            title: 'No hay productos en esta categoría',
            subtitle:
                'Selecciona otra categoría en la parte superior para continuar explorando el menú.',
          );
        }
        return _buildProductGrid(items, screenWidth, isTablet);
    }
  }

  // --- State 1: Loaded Product Grid ---
  Widget _buildProductGrid(
    List<StoreProduct> items,
    double screenWidth,
    bool isTablet,
  ) {
    // Determine responsive column count
    final int crossAxisCount;
    if (isTablet) {
      crossAxisCount = screenWidth > 1100 ? 4 : 3;
    } else {
      crossAxisCount = screenWidth > 420 ? 2 : 1;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.76,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final product = items[index];
        return ProductCard(
          product: product,
          onTap: () => _onProductTapped(product),
        );
      },
    );
  }

  // --- State 2: Loading Shimmer Skeleton ---
  Widget _buildLoadingSkeletonState(double screenWidth, bool isTablet) {
    final int crossAxisCount;
    if (isTablet) {
      crossAxisCount = screenWidth > 1100 ? 4 : 3;
    } else {
      crossAxisCount = screenWidth > 420 ? 2 : 1;
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.9).animate(_shimmerController),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: crossAxisCount * 2,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.76,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) => _buildSkeletonProductCard(),
      ),
    );
  }

  Widget _buildCategorySkeletonChips() {
    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 0.85).animate(_shimmerController),
        child: Row(
          children: List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.only(right: 12),
              width: 120,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonProductCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image skeleton
          Container(
            height: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line
                Container(
                  height: 18,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle line
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 24),
                // Price & button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 22,
                      width: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- State 3: Empty State ---
  Widget _buildEmptyState({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 64,
                color: CatalogScreen.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CatalogScreen.darkTextColor,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: CatalogScreen.subtleTextColor,
                  height: 1.4,
                ),
              ),
            ),
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  widget.sessionController.userInteracted();
                  setState(() {
                    _selectedCategoryId = _categories.first.id;
                  });
                },
                icon: const Icon(Icons.explore_rounded),
                label: const Text('Ver Primera Categoría'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CatalogScreen.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- State 4: Error State with Retry Button ---
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No pudimos cargar el menú',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: CatalogScreen.darkTextColor,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                _errorMessage ??
                    'Ocurrió un error al consultar el catálogo. Por favor intenta de nuevo.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: CatalogScreen.subtleTextColor,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                widget.sessionController.userInteracted();
                _loadCatalog();
              },
              icon: const Icon(Icons.refresh_rounded, size: 22),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CatalogScreen.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
