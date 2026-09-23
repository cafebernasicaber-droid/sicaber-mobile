import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:go_router/go_router.dart';
import '../../data/services/app_state.dart';
import '../theme/theme.dart';
import '../../presentation/screens/splash/splash.dart';
import '../../presentation/screens/onboarding/onboarding.dart';
import '../../presentation/screens/auth/login.dart';
import '../../presentation/screens/auth/completar_registro.dart';
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
      '/splash', '/onboarding', '/login', '/recuperar-password',
      '/home', '/search',
    ];
    // "Completa tu cuenta" (primer ingreso con Google) no requiere sesión —
    // justamente todavía no la hay— pero SÍ requiere el registro pendiente
    // que viaja en `extra`. Sin él (relanzamiento de la app, recarga en
    // caliente) no hay nada que completar: el token vive solo en memoria y
    // nunca se guarda, así que se vuelve al login.
    if (loc == '/completar-registro') return state.extra is RegistroGoogle ? null : '/login';
    if (loc.startsWith('/menu/')) return null;
    if (open.contains(loc)) return null;

    // El resto (carrito, pedidos, perfil, checkout) sí requiere sesión.
    if (!auth) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/splash',     builder: (_, __) => SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => OnboardingScreen()),
    // `extra` String = aviso para mostrar arriba del formulario (ej. el
    // registro con Google venció y hubo que volver aquí).
    GoRoute(path: '/login',      builder: (_, s) => LoginScreen(errorInicial: s.extra is String ? s.extra as String : null)),
    GoRoute(path: '/completar-registro', builder: (_, s) =>
      CompletarRegistroScreen(registro: s.extra as RegistroGoogle)),
    // Se eliminaron /register y /verificar-cuenta: el registro tradicional ya
    // no existe (cuentas nuevas solo por Google), y el PIN de 6 dígitos solo
    // se alcanzaba desde el registro — el login normal nunca revisó
    // `verificado`, y Google ya confirma el correo, así que quedaba huérfano.
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
        // Las 4 pestañas del bottom nav viven en el MISMO Navigator/entrada
        // de historial (van con context.go, que reemplaza en vez de
        // apilar) — por eso el back físico de Android, estando en
        // cualquiera de las 4, no tiene a dónde volver y hoy cierra la app
        // de inmediato, sin avisar. Se bloquea acá y se pide confirmar
        // antes de salir, sin importar en qué pestaña esté el cliente.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final salir = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: C.card,
                title: const Text('¿Salir de la app?'),
                content: Text('Vas a cerrar Café Don Berna.',
                  style: TextStyle(fontSize: 13, color: C.textSec)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Salir', style: TextStyle(color: C.green, fontWeight: FontWeight.w700))),
                ],
              ),
            );
            if (salir == true) SystemNavigator.pop();
          },
          child: Scaffold(
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
          ),
        );
      },
    );
  }
}