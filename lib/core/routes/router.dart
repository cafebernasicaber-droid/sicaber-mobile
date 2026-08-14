import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/app_state.dart';
import '../../presentation/screens/splash/splash.dart';
import '../../presentation/screens/onboarding/onboarding.dart';
import '../../presentation/screens/auth/login.dart';
import '../../presentation/screens/auth/register.dart';
import '../../presentation/screens/auth/verificar.dart';
import '../../presentation/screens/auth/recuperar.dart';
import '../../presentation/screens/home/home.dart';
import '../../presentation/screens/menu/product_detail.dart';
import '../../presentation/screens/search/search.dart';
import '../../presentation/screens/cart/cart.dart';
import '../../presentation/screens/orders/orders.dart';
import '../../presentation/screens/profile/profile.dart';
import '../../presentation/screens/profile/edit_profile.dart';

final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final loc  = state.matchedLocation;
    final auth = AppState.instance.loggedIn;

    // Rutas totalmente públicas: no requieren sesión iniciada.
    // Incluye el "landing" (home), la búsqueda y el detalle de producto,
    // para que cualquiera pueda explorar el menú sin registrarse.
    const open = [
      '/splash', '/onboarding', '/login', '/register', '/recuperar-password',
      '/home', '/search',
    ];
    if (loc.startsWith('/verificar-cuenta')) return null;
    if (loc.startsWith('/menu/')) return null;
    if (open.contains(loc)) return null;

    // El resto (carrito, pedidos, perfil, checkout) sí requiere sesión.
    if (!auth) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/splash',     builder: (_, __) => SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => OnboardingScreen()),
    GoRoute(path: '/login',      builder: (_, __) => LoginScreen()),
    GoRoute(path: '/register',   builder: (_, __) => RegisterScreen()),
    GoRoute(path: '/verificar-cuenta', builder: (_, s) => VerificarCuentaScreen(
      correo: s.uri.queryParameters['correo'] ?? '',
    )),
    GoRoute(path: '/recuperar-password', builder: (_, __) => RecuperarPasswordScreen()),
    GoRoute(path: '/search',     builder: (_, __) => SearchScreen()),
    GoRoute(path: '/checkout',   builder: (_, __) => CheckoutScreen()),
    // key única por producto (y por cada nueva visita al mismo producto):
    // sin esto, GoRouter puede reutilizar el mismo State (_PDState) al
    // navegar entre productos distintos. Como _topsInicializados es una
    // bandera de instancia que solo corre una vez, un State reutilizado
    // nunca recalculaba la preselección de toppings del producto nuevo —
    // se quedaba con lo que había seleccionado el producto anterior
    // ("a veces aparecen, a veces no", y no se podía elegir una
    // combinación distinta en una segunda visita al mismo producto).
    GoRoute(path: '/menu/:id', builder: (_, s) {
      final id = int.parse(s.pathParameters['id']!);
      return ProductDetailScreen(key: ValueKey('producto-$id'), id: id);
    }),
    GoRoute(path: '/pedidos/:id',builder: (_, s)  => OrderDetailScreen(id: s.pathParameters['id']!)),
    GoRoute(path: '/perfil/editar',    builder: (_, __) => EditProfileScreen()),
    ShellRoute(
      builder: (_, __, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home',    builder: (_, __) => HomeScreen()),
        GoRoute(path: '/carrito', builder: (_, __) => CartScreen()),
        GoRoute(path: '/pedidos', builder: (_, __) => OrdersScreen()),
        GoRoute(path: '/perfil',  builder: (_, __) => ProfileScreen()),
      ],
    ),
  ],
);

// ── BOTTOM NAV SHELL ─────────────────────────────────────────
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = ['/home', '/carrito', '/pedidos', '/perfil'];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => loc.startsWith(t));

    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final count = AppState.instance.cartCount;
        return Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: idx < 0 ? 0 : idx,
            onTap: (i) => context.go(_tabs[i]),
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_outlined),         activeIcon: Icon(Icons.home),         label: 'Inicio'),
              BottomNavigationBarItem(
                icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined)),
                activeIcon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart)),
                label: 'Carrito'),
              const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline),        activeIcon: Icon(Icons.person),       label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}