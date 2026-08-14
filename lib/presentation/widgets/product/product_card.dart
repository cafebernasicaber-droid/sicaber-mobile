import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';
import '../common/auth_gate.dart';

class ProductCard extends StatefulWidget {
  final Producto producto;
  const ProductCard({super.key, required this.producto});
  @override State<ProductCard> createState() => _PCState();
}

class _PCState extends State<ProductCard> {
  bool _pressed = false;

  // Antes esto agregaba directo al carrito sin toppings ni adiciones, sin
  // abrir nunca la personalización — el cliente solo podía elegir
  // toppings/adiciones si tocaba la tarjeta completa (que sí navega a
  // /menu/:id), no si tocaba el "+". Ahora revisa, con el mismo filtro
  // que ya usa product_detail.dart (_toppingsDelProducto/
  // _adicionesDisponibles), si el producto realmente tiene algo que
  // personalizar: si sí, abre el detalle igual que la tarjeta completa;
  // solo agrega directo cuando genuinamente no hay nada que elegir.
  void _add() {
    if (!ensureLoggedIn(context)) return;

    final tieneToppings = AppState.instance.toppings.any((t) =>
      t.productosIds.isEmpty || t.productosIds.contains(widget.producto.id));
    final tieneAdiciones = AppState.instance.adiciones.any((a) => a.estado);

    if (tieneToppings || tieneAdiciones) {
      context.push('/menu/${widget.producto.id}');
      return;
    }

    AppState.instance.addToCart(widget.producto);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.producto.nombre} agregado ✓'),
      backgroundColor: C.green, duration: const Duration(seconds: 1)));
    setState(() {});
  }

  @override Widget build(BuildContext context) {
    final p = widget.producto;

    return GestureDetector(
      onTap: () => context.push('/menu/${p.id}'),
      child: Container(
        decoration: BoxDecoration(color: C.card,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Imagen / icono ──
          Expanded(flex: 3, child: Stack(children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: C.surf2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: _buildImagen(p),
            ),

            // Badge descuento
            if (p.tieneDescuento)
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(100)),
                  child: Text('-${p.descuento.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)))),

            // Agregar rápido
            Positioned(bottom: 8, right: 8,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: _add,
                child: AnimatedScale(
                  scale: _pressed ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  onEnd: () { if (_pressed) setState(() => _pressed = false); },
                  child: Container(width: 34, height: 34,
                    decoration: BoxDecoration(color: C.green, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: C.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]),
                    child: const Icon(Icons.add, color: Colors.white, size: 18))))),
          ])),

          // ── Info ──
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.categoria.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.green, letterSpacing: 1)),
                const SizedBox(height: 3),
                Text(p.nombre,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(fmt(p.precioFinal),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.green)),
                if (p.tieneDescuento) ...[const SizedBox(width: 5),
                  Text(fmt(p.precio),
                    style: TextStyle(fontSize: 11, color: C.textMut, decoration: TextDecoration.lineThrough))],
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildImagen(Producto p) {
    final url = buildImageUrl(p.imagen);
    if (url == null) return Center(child: _coffeeIcon(p.categoria));
    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      // Mientras carga, muestra el ícono en vez de dejar el espacio en blanco
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(child: _coffeeIcon(p.categoria));
      },
      // Si la imagen no existe o la URL falla (ej: ruta rota, backend caído),
      // no se rompe la app: cae de vuelta al ícono genérico.
      errorBuilder: (context, error, stack) => Center(child: _coffeeIcon(p.categoria)),
    );
  }

  Widget _coffeeIcon(String cat) {
    if (cat.contains('Frías')) return Icon(Icons.local_drink_outlined, size: 48, color: C.textMut);
    if (cat.contains('Especiales')) return Icon(Icons.auto_awesome, size: 48, color: C.textMut);
    return Icon(Icons.coffee, size: 48, color: C.textMut);
  }
}