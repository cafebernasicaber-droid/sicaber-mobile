import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';
import '../../widgets/common/animations.dart';

// ── SPLASH ────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: Duration(milliseconds: 1000));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.8, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Restaura la sesión (token guardado de un login anterior) en paralelo
    // con la animación/delay del splash, para no alargar el arranque; si
    // hay un token válido, el perfil completo del cliente queda listo
    // antes de que la app se vuelva interactiva.
    final restaurar = AppState.instance.restaurarSesion();
    await Future.delayed(Duration(milliseconds: 2500));
    await restaurar;
    if (!mounted) return;
    final p = await SharedPreferences.getInstance();
    context.go((p.getBool('onb') ?? false) ? '/home' : '/onboarding');
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: Stack(children: [
      // Fondo decorativo
      Positioned(right: -60, top: -60,
        child: Container(width: 240, height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, color: C.green.withOpacity(0.04)))),
      Positioned(left: -40, bottom: -40,
        child: Container(width: 180, height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle, color: C.green.withOpacity(0.04)))),
      Center(child: FadeTransition(opacity: _fade, child: ScaleTransition(scale: _scale,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Vapor animado subiendo sobre el logo (igual al efecto de la web)
          SteamRise(color: C.green),
          SizedBox(height: 4),
          Container(width: 110, height: 110, padding: EdgeInsets.all(18),
            decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle,
              border: Border.all(color: C.green.withOpacity(0.3), width: 2)),
            child: Image.asset('assets/images/logo_blanco.png',
              color: C.green, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.coffee, color: C.green, size: 58))),
          SizedBox(height: 28),
          Text('CAFÉ DON BERNA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text, letterSpacing: 2.5)),
          SizedBox(height: 8),
          Text('Café con alma propia',
            style: TextStyle(fontSize: 13, color: C.textSec, letterSpacing: 2)),
          SizedBox(height: 52),
          SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(color: C.green, strokeWidth: 2)),
        ])))),
    ]),
  );
}

// ── ONBOARDING ────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnbState();
}

class _OnbState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static final _pages = [
    _P('☕', 'Café Don Berna', 'El mejor café de las comunas 8 y 9 de Medellín.\nTradición, sabor y calidez en cada sorbo.', C.green),
    _P('🍵', 'Personaliza tu bebida', 'Elige tus toppings, adiciones y combos especiales.\nCada bebida única para ti.', C.gold),
    _P('🛵', 'Pide a domicilio', 'Servicio de domicilios en comunas 8 y 9 de Medellín.\nRápido, fácil y desde tu celular.', Color(0xFF42A5F5)),
    _P('⭐', 'Únete a la comunidad', 'Descubre todo nuestro menú\ny sigue el estado de tus pedidos en tiempo real.', Color(0xFFAB47BC)),
  ];

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onb', true);
    if (mounted) context.go('/home');
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: Column(children: [
      Align(alignment: Alignment.topRight,
        child: Padding(padding: EdgeInsets.only(right: 8, top: 4),
          child: TextButton(onPressed: _finish,
            child: Text('Saltar', style: TextStyle(color: C.textSec))))),
      Expanded(child: PageView.builder(
        controller: _ctrl, itemCount: _pages.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) {
          final p = _pages[i];
          return Padding(padding: EdgeInsets.symmetric(horizontal: 36), child: FadeSlideIn(
            key: ValueKey(i),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 130, height: 130,
              decoration: BoxDecoration(color: p.color.withOpacity(0.1), shape: BoxShape.circle,
                border: Border.all(color: p.color.withOpacity(0.3), width: 2)),
              child: Center(child: Text(p.emoji, style: TextStyle(fontSize: 58)))),
            SizedBox(height: 40),
            Text(p.title, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
            SizedBox(height: 14),
            Text(p.sub, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: C.textSec, height: 1.7)),
          ])));
        },
      )),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (i) => AnimatedContainer(
          duration: Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: i == _page ? 28 : 8, height: 8,
          decoration: BoxDecoration(
            color: i == _page ? C.green : C.elevated,
            borderRadius: BorderRadius.circular(4))))),
      SizedBox(height: 32),
      Padding(padding: EdgeInsets.symmetric(horizontal: 24),
        child: ElevatedButton(
          onPressed: () => _page < _pages.length - 1
              ? _ctrl.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut)
              : _finish(),
          child: Text(_page < _pages.length - 1 ? 'Siguiente' : 'Comenzar'))),
      SizedBox(height: 32),
    ])),
  );
}

class _P {
  final String emoji, title, sub; final Color color;
  _P(this.emoji, this.title, this.sub, this.color);
}