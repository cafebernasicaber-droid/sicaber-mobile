import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

// ── FADE + SLIDE IN ──────────────────────────────────────────
// Entrada de contenido con fundido + desplazamiento hacia arriba,
// igual al efecto "heroIn" / "modalIn" de la web (Landing.css).
// Se usa envolviendo secciones, tarjetas o listas para que aparezcan
// suavemente al construirse en pantalla.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 18,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: Offset(0, widget.offsetY / 100), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── ENTRADA ESCALONADA PARA GRILLAS/LISTAS ──────────────────
// Aplica FadeSlideIn a cada hijo con un pequeño retraso incremental,
// como el efecto de aparición escalonada de tarjetas en la web.
class StaggeredFadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration step;
  const StaggeredFadeIn({super.key, required this.index, required this.child, this.step = const Duration(milliseconds: 60)});

  @override
  Widget build(BuildContext context) => FadeSlideIn(
    delay: step * index,
    duration: const Duration(milliseconds: 380),
    child: child,
  );
}

// ── MARQUEE (banner deslizante infinito) ────────────────────
// Réplica del efecto ".lx-marquee" de la web: una franja con texto
// que se desliza horizontalmente sin parar.
class MarqueeBanner extends StatefulWidget {
  final List<String> items;
  final double height;
  const MarqueeBanner({super.key, required this.items, this.height = 40});

  @override
  State<MarqueeBanner> createState() => _MarqueeBannerState();
}

class _MarqueeBannerState extends State<MarqueeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final text = widget.items.join('   ·   ');
    final line = '$text   ·   $text   ·   ';
    return Container(
      height: widget.height,
      color: C.greenBg,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return LayoutBuilder(builder: (context, constraints) {
              final dx = -constraints.maxWidth * _ctrl.value;
              return Stack(children: [
                Positioned(
                  left: dx,
                  top: 0, bottom: 0,
                  child: Row(children: [
                    _marqueeText(line), _marqueeText(line),
                  ]),
                ),
              ]);
            });
          },
        ),
      ),
    );
  }

  Widget _marqueeText(String line) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(line, maxLines: 1, softWrap: false,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.green, letterSpacing: 0.3)),
    ));
}

// ── VAPOR ANIMADO (steam) ────────────────────────────────────
// Réplica del efecto "lxSteamRise" de la web: pequeñas volutas de
// vapor que suben y se desvanecen sobre el logo, en bucle.
class SteamRise extends StatefulWidget {
  final Color color;
  const SteamRise({super.key, this.color = C.green});

  @override
  State<SteamRise> createState() => _SteamRiseState();
}

class _SteamRiseState extends State<SteamRise> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      vsync: this, duration: Duration(milliseconds: 1600 + i * 220)));
    // Desfasar el inicio de cada voluta
    for (var i = 0; i < _ctrls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 260), () { if (mounted) _ctrls[i].repeat(); });
    }
  }

  @override
  void dispose() { for (final c in _ctrls) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60, height: 34,
    child: Stack(alignment: Alignment.bottomCenter, children: [
      for (var i = 0; i < _ctrls.length; i++)
        AnimatedBuilder(
          animation: _ctrls[i],
          builder: (context, _) {
            final t = _ctrls[i].value;
            final dx = (i - 1) * 14.0 + (8 * (t < 0.5 ? t : 1 - t));
            final dy = -34 * t;
            final opacity = (1 - t).clamp(0.0, 1.0) * 0.5;
            return Positioned(
              left: 30 + dx - 3, bottom: 0,
              child: Transform.translate(offset: Offset(0, dy),
                child: Opacity(opacity: opacity,
                  child: Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)))),
            );
          },
        ),
    ]),
  );
}
