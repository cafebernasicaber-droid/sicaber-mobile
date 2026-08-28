import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';
import '../../../data/models/models.dart';
import '../../widgets/product/product_card.dart';
import '../../widgets/common/animations.dart';
import '../../widgets/common/auth_gate.dart';

// Cuántas categorías se muestran por "página" del selector de chips.
const int _kCategoriasPorPagina = 5;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  String? _cat;
  final _catPageCtrl = PageController();
  int _catPage = 0;

  @override void dispose() { _catPageCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        // Antes del primer resultado de cargarDatos() (éxito o fallo
        // parcial), un spinner en vez de una pantalla que parece vacía.
        if (AppState.instance.cargandoInicial) {
          return Scaffold(backgroundColor: C.bg,
            body: const Center(child: CircularProgressIndicator(color: C.green)));
        }

        final user    = AppState.instance.usuario;
        final ofertas = AppState.instance.getOfertas();
        final combosA = AppState.instance.combos;
        final productos = AppState.instance.getProductosPorCategoria(_cat);
        final errorCarga = AppState.instance.errorCarga;

        final categorias = AppState.instance.categorias;
        final paginas = <List<dynamic>>[];
        for (var i = 0; i < categorias.length; i += _kCategoriasPorPagina) {
          paginas.add(categorias.sublist(
            i, i + _kCategoriasPorPagina > categorias.length ? categorias.length : i + _kCategoriasPorPagina));
        }
        if (paginas.isEmpty) paginas.add(const []);

        return Scaffold(
          backgroundColor: C.bg,
          body: Column(children: [
            // Banner fijo (no se va con el scroll) cuando alguna parte del
            // catálogo no cargó — con qué faltó y un botón para reintentar
            // SOLO esas partes, sin tener que cerrar la app.
            if (errorCarga != null)
              _ErrorBanner(mensaje: errorCarga, onReintentar: () => AppState.instance.reintentarCarga()),
            Expanded(child: RefreshIndicator(
              color: C.green,
              // Deslizar hacia abajo también reintenta lo que haya fallado,
              // sin depender de que el banner de arriba esté visible.
              onRefresh: AppState.instance.reintentarCarga,
              child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
            // ── AppBar ──
            SliverAppBar(expandedHeight: 150, pinned: true, backgroundColor: C.surface,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(children: [
                  Container(decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [C.surface, C.bg],
                      begin: Alignment.topLeft, end: Alignment.bottomRight))),
                  Positioned(right: -40, top: -40,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: C.green.withOpacity(0.05)))),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end, children: [
                      Row(children: [
                        Container(width: 28, height: 28, padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle),
                          child: Image.asset('assets/images/logo_blanco.png', color: C.green,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Icons.coffee, color: C.green, size: 15))),
                        const SizedBox(width: 8),
                        Expanded(child: Text('¡Hola, ${user?.nombre.split(' ').first ?? 'bienvenido'}! ☕',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.text))),
                      ]),
                      const SizedBox(height: 3),
                      Text('¿Qué vas a pedir hoy?',
                        style: TextStyle(fontSize: 12, color: C.textSec)),
                    ])),
                ]),
              ),
              actions: [
                if (user == null)
                  Padding(padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                      onPressed: () => context.push('/login'),
                      style: TextButton.styleFrom(
                        backgroundColor: C.greenBg,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Text('Iniciar sesión',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.green)),
                    )),
                IconButton(icon: Icon(Icons.search_outlined, color: C.text), onPressed: () => context.push('/search')),
              ],
            ),

            // ── Búsqueda rápida ──
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(onTap: () => context.push('/search'),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                  child: Row(children: [
                    Icon(Icons.search, color: C.textMut, size: 20), const SizedBox(width: 10),
                    Text('Buscar en el menú...', style: TextStyle(color: C.textMut, fontSize: 14))
                  ]))))),

            // ── Marquee animado ──
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12),
              child: MarqueeBanner(items: const [
                '☕ Café con alma propia',
                '🛵 Domicilios en comunas 8 y 9',
                '⭐ Personaliza tu bebida con toppings y adiciones',
              ]))),

            // ── Combos del día ──
            if (combosA.isNotEmpty) ...[
              _header('🎁 Combos del día'),
              SliverToBoxAdapter(child: SizedBox(height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: combosA.length,
                  itemBuilder: (_, i) => StaggeredFadeIn(index: i, child: _ComboCard(combo: combosA[i]))))),
            ],

            // ── Ofertas ──
            if (ofertas.isNotEmpty) ...[
              _header('🔥 Ofertas especiales'),
              SliverToBoxAdapter(child: SizedBox(height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: ofertas.length,
                  itemBuilder: (_, i) => StaggeredFadeIn(index: i,
                    child: SizedBox(width: 160, child: ProductCard(producto: ofertas[i])))))),
            ],

            // ── Nuestro menú (todos los productos, con filtro de categoría) ──
            _header('☕ Nuestro menú'),

            // Categorías (paginadas)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _CatChip(label: 'Todos', selected: _cat == null, onTap: () => setState(() => _cat = null)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(children: [
                    SizedBox(
                      height: 36,
                      child: PageView.builder(
                        controller: _catPageCtrl,
                        itemCount: paginas.length,
                        onPageChanged: (p) => setState(() => _catPage = p),
                        itemBuilder: (_, p) => SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(children: paginas[p].map<Widget>((c) => _CatChip(
                            label: c.nombre, selected: _cat == c.nombre,
                            onTap: () => setState(() => _cat = c.nombre))).toList()),
                        ),
                      ),
                    ),
                    if (paginas.length > 1) ...[
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(paginas.length, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _catPage ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _catPage ? C.green : C.border,
                            borderRadius: BorderRadius.circular(3))))),
                    ],
                  ]),
                ),
              ]),
            )),

            // Grilla con todos los productos de la categoría seleccionada
            if (productos.isEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Column(children: [
                  Icon(Icons.coffee_outlined, size: 48, color: C.textMut),
                  const SizedBox(height: 10),
                  Text('Sin productos en esta categoría', style: TextStyle(fontSize: 14, color: C.textSec)),
                ]))))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => StaggeredFadeIn(index: i, step: const Duration(milliseconds: 35),
                      child: ProductCard(producto: productos[i])), childCount: productos.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.73))),

            // ── Info del café ──
            SliverToBoxAdapter(child: FadeSlideIn(child: _InfoCafe())),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ]),
            )),
          ]),
        );
      },
    );
  }

  Widget _header(String title) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.text))));
}

// ── Banner fijo de "no se pudo cargar todo el catálogo" ────────
class _ErrorBanner extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const _ErrorBanner({required this.mensaje, required this.onReintentar});

  @override Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: C.red.withOpacity(0.12),
    child: SafeArea(bottom: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: C.red, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje,
            style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: onReintentar,
            style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            child: const Text('Reintentar', style: TextStyle(color: C.red, fontWeight: FontWeight.w800))),
        ]))));
}

class _CatChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _CatChip({required this.label, required this.selected, required this.onTap});

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? C.green : C.surf2,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: selected ? C.green : C.border)),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: selected ? Colors.white : C.textSec))));
}

class _ComboCard extends StatelessWidget {
  final Combo combo;
  const _ComboCard({required this.combo});

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _ComboDetalleSheet(combo: combo)),
    child: Container(
      width: 220,
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.green.withOpacity(0.2))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.card_giftcard, color: C.green, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(combo.nombre,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Icon(Icons.chevron_right, size: 18, color: C.textMut),
        ]),
        const SizedBox(height: 8),
        Text(combo.descripcion, style: TextStyle(fontSize: 11, color: C.textSec, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(fmt(combo.precio),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.green)),
          if (combo.ahorro > 0)
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
              child: Text('Ahorras ${fmt(combo.ahorro)}', style: TextStyle(fontSize: 10, color: C.red, fontWeight: FontWeight.w700))),
        ]),
      ]),
    ),
  );
}

// ── Detalle completo de un combo (misma información que la web:
// productos que lo componen sin truncar, ahorro, fecha de inicio y fecha
// de fin — esta última solo si el combo la tiene definida) ────────────
class _ComboDetalleSheet extends StatelessWidget {
  final Combo combo;
  const _ComboDetalleSheet({required this.combo});

  @override Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
    builder: (context, scrollCtrl) => Container(
      decoration: BoxDecoration(color: C.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
        Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(100)))),

        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.card_giftcard, color: C.green, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Text(combo.nombre,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.text))),
        ]),

        if (combo.descripcion.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(combo.descripcion, style: TextStyle(fontSize: 13, color: C.textSec, height: 1.5)),
        ],

        // ── Vigencia: solo se muestra cada fecha si el combo la tiene ──
        if (combo.fechaInicio != null || combo.fechaFin != null) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (combo.fechaInicio != null)
              _ChipFecha(icono: Icons.event_available_outlined, texto: 'Desde ${fmtFechaEsDate(combo.fechaInicio!)}'),
            if (combo.fechaFin != null)
              _ChipFecha(icono: Icons.event_busy_outlined, texto: 'Hasta ${fmtFechaEsDate(combo.fechaFin!)}'),
          ]),
        ],

        const SizedBox(height: 18),
        Text('Incluye', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 10),
        if (combo.items.isEmpty)
          Text('Este combo no tiene productos detallados.', style: TextStyle(fontSize: 12, color: C.textMut))
        else
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              for (final item in combo.items) ...[
                Row(children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: C.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item['nombre']?.toString() ?? '—',
                    style: TextStyle(fontSize: 13, color: C.text))),
                ]),
                if (item != combo.items.last) const SizedBox(height: 8),
              ],
            ])),

        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Precio del combo', style: TextStyle(fontSize: 11, color: C.textSec)),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(fmt(combo.precio), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.green)),
                if (combo.totalOriginal > combo.precio) ...[
                  const SizedBox(width: 8),
                  Text(fmt(combo.totalOriginal), style: TextStyle(fontSize: 13, color: C.textMut,
                    decoration: TextDecoration.lineThrough)),
                ],
              ]),
            ]),
            const Spacer(),
            if (combo.ahorro > 0)
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(100)),
                child: Text('Ahorras ${fmt(combo.ahorro)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700))),
          ])),

        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            if (!ensureLoggedIn(context)) return;
            AppState.instance.addComboToCart(combo);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${combo.nombre} agregado al carrito ✓'),
              backgroundColor: C.green, duration: const Duration(seconds: 2)));
            Navigator.pop(context);
          },
          icon: const Icon(Icons.add_shopping_cart, size: 18),
          label: const Text('Agregar al carrito')),

        const SizedBox(height: 24),
      ]),
    ),
  );
}

class _ChipFecha extends StatelessWidget {
  final IconData icono; final String texto;
  const _ChipFecha({required this.icono, required this.texto});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 14, color: C.textSec),
      const SizedBox(width: 6),
      Text(texto, style: TextStyle(fontSize: 12, color: C.textSec, fontWeight: FontWeight.w600)),
    ]));
}

class _InfoCafe extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.store, color: C.green, size: 18),
        const SizedBox(width: 8),
        Text('Café Don Berna', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.text))]),
      Divider(height: 20, color: C.border),
      ...contacto.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_iconoContacto(e.key), color: C.green, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(e.value, style: TextStyle(fontSize: 13, color: C.textSec, height: 1.4))),
        ]))),
    ]),
  );

  IconData _iconoContacto(String key) {
    switch (key) {
      case 'direccion':   return Icons.location_on_outlined;
      case 'horario':     return Icons.schedule_outlined;
      case 'telefono':    return Icons.phone_outlined;
      case 'correo':      return Icons.email_outlined;
      case 'propietario': return Icons.person_outline;
      default:            return Icons.location_city_outlined;
    }
  }
}
