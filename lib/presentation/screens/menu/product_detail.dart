import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';
import '../../widgets/common/animations.dart';
import '../../widgets/common/auth_gate.dart';

class ProductDetailScreen extends StatefulWidget {
  final int id;
  ProductDetailScreen({super.key, required this.id});
  @override State<ProductDetailScreen> createState() => _PDState();
}

class _PDState extends State<ProductDetailScreen> {
  int _qty = 1;
  final List<Topping> _tops = [];
  final List<Adicion> _adds = [];
  // Los toppings del producto se preseleccionan una sola vez, la primera
  // vez que build() encuentra los datos ya cargados. Sin esta bandera, cada
  // rebuild (p. ej. por un cambio de AppState ajeno a esta pantalla, como
  // el carrito) volvería a pisar lo que el cliente ya haya deseleccionado.
  bool _topsInicializados = false;

  void _toggleTop(Topping t) => setState(() => _tops.contains(t) ? _tops.remove(t) : _tops.add(t));
  void _toggleAdd(Adicion a) => setState(() => _adds.contains(a) ? _adds.remove(a) : _adds.add(a));

  double _extra() =>
    _tops.where((t) => !t.gratuito).fold(0.0, (s, t) => s + t.precio) +
    _adds.fold(0.0, (s, a) => s + a.precio);

  double _total(Producto p) => (p.precioFinal + _extra()) * _qty;

  // Igual que en la web (toppings.js → toppingsParaProducto): un topping
  // sin productos_ids (o con el arreglo vacío) aplica a cualquier producto;
  // si trae ids, solo aplica a los productos de esa lista.
  List<Topping> _toppingsDelProducto(Producto p) => AppState.instance.toppings
      .where((t) => t.productosIds.isEmpty || t.productosIds.contains(p.id))
      .toList();

  // Las adiciones son universales (aplican igual a cualquier producto del
  // menú — la tabla "adiciones" del backend no tiene columna de categoría
  // ni producto_id, así que nunca hay que filtrarlas por producto). Antes
  // este filtro comparaba por categoría, pero como Adicion.categoria nunca
  // llegaba del backend (columna inexistente), esa comparación siempre
  // daba falso y las adiciones jamás aparecían.
  List<Adicion> _adicionesDisponibles(Producto p) =>
      AppState.instance.adiciones.where((a) => a.estado).toList();

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
    final lista = AppState.instance.productos;
    if (lista.isEmpty) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = lista.firstWhere((x) => x.id == widget.id, orElse: () => lista.first);
    final tops = _toppingsDelProducto(p);
    final adicionesFiltradas = _adicionesDisponibles(p);

    // Preselección: la primera vez que hay datos, el producto arranca con
    // TODOS sus toppings marcados; el cliente los quita tocándolos. Solo
    // una vez (ver _topsInicializados) para no pisar lo que ya haya tocado.
    if (!_topsInicializados) {
      _topsInicializados = true;
      _tops.addAll(tops);
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        // ── Header imagen ──
        SliverAppBar(expandedHeight: 270, pinned: true, backgroundColor: C.surface,
          leading: IconButton(
            icon: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: C.surface.withOpacity(0.8), shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: C.text)),
            onPressed: () => Navigator.pop(context)),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(color: C.surf2,
              child: _buildImagenGrande(p))),
        ),

        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Nombre y precio ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(100)),
                child: Text(p.categoria.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.green, letterSpacing: 1))),
              SizedBox(height: 8),
              Text(p.nombre, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt(p.precioFinal),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.green)),
              if (p.tieneDescuento)
                Text(fmt(p.precio),
                  style: TextStyle(fontSize: 14, color: C.textMut, decoration: TextDecoration.lineThrough)),
            ]),
          ]),

          if (p.descripcion.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(p.descripcion, style: TextStyle(fontSize: 14, color: C.textSec, height: 1.6))],

          // ── Toppings ──
          if (tops.isNotEmpty) ...[
          SizedBox(height: 24),
          Row(children: [
            Text('Toppings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
            SizedBox(width: 8),
            Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(100)),
              child: Text('2 GRATIS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.green))),
          ]),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: tops.asMap().entries.map((e) {
            final t = e.value;
            final sel = _tops.contains(t);
            return StaggeredFadeIn(index: e.key, step: Duration(milliseconds: 30),
              child: GestureDetector(onTap: () => _toggleTop(t),
              child: AnimatedContainer(duration: Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? C.greenBg : C.surf2,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: sel ? C.green : C.border)),
                child: Text(
                  t.gratuito ? '${t.nombre} · Gratis' : '${t.nombre} +${fmt(t.precio)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? C.green : C.textSec)))));
          }).toList()),
          ],

          // ── Adiciones ──
          if (adicionesFiltradas.isNotEmpty) ...[
          SizedBox(height: 24),
          Text('Adiciones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: adicionesFiltradas.asMap().entries.map((e) {
            final a = e.value;
            final sel = _adds.contains(a);
            return StaggeredFadeIn(index: e.key, step: Duration(milliseconds: 30),
              child: GestureDetector(onTap: () => _toggleAdd(a),
              child: AnimatedContainer(duration: Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? C.gold.withOpacity(0.1) : C.surf2,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: sel ? C.gold : C.border)),
                child: Text('+${fmt(a.precio)} ${a.nombre}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? C.gold : C.textSec)))));
          }).toList()),
          ],

          SizedBox(height: 100),
        ]))),
      ]),

      // ── Bottom bar ──
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
        child: Row(children: [
          // Contador
          Container(
            decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
            child: Row(children: [
              IconButton(icon: Icon(Icons.remove, size: 18), color: C.text,
                onPressed: () { if (_qty > 1) setState(() => _qty--); }),
              Text('$_qty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
              IconButton(icon: Icon(Icons.add, size: 18), color: C.text,
                onPressed: () => setState(() => _qty++)),
            ])),
          SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () {
              if (!ensureLoggedIn(context)) return;
              AppState.instance.addToCart(p,
                toppings: List.from(_tops), adiciones: List.from(_adds), cantidad: _qty);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${p.nombre} agregado al carrito ✓'),
                backgroundColor: C.green, duration: Duration(seconds: 2)));
              Navigator.pop(context);
            },
            child: Text('Agregar · ${fmt(_total(p))}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
        ]),
      ),
    );
    },
  );

  Widget _buildImagenGrande(Producto p) {
    final url = buildImageUrl(p.imagen);
    if (url == null) return Center(child: _bigIcon(p.categoria));
    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(child: _bigIcon(p.categoria));
      },
      errorBuilder: (context, error, stack) => Center(child: _bigIcon(p.categoria)),
    );
  }

  Widget _bigIcon(String cat) {
    if (cat.contains('Frías'))     return Icon(Icons.local_drink, size: 90, color: C.textMut);
    if (cat.contains('Especiales'))return Icon(Icons.auto_awesome, size: 90, color: C.textMut);
    return Icon(Icons.coffee, size: 90, color: C.textMut);
  }
}