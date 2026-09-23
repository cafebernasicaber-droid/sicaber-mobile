// ─────────────────────────────────────────────────────────────────────────
//  Visor del comprobante de pago
// ─────────────────────────────────────────────────────────────────────────
// BUG REAL QUE CORRIGE (requisito 6): el comprobante NUNCA se veía en el
// detalle del pedido, aunque el pedido sí lo tuviera.
//
// El motivo: la app sube el comprobante como data URL en base64
// ("data:image/jpeg;base64,...") — ver AppState.crearPedido — y el backend
// lo devuelve igual. Pero buildImageUrl() deja pasar las data URL tal cual
// y todas las pantallas las cargaban con `Image.network(...)`, que NO sabe
// leer una data URL: hace una petición HTTP a una URL que no existe y cae
// siempre al errorBuilder. Es decir, el comprobante se guardaba bien y se
// devolvía bien, pero era imposible verlo.
//
// [ComprobanteImage] resuelve eso eligiendo el cargador correcto según la
// forma de la fuente, y [ComprobanteVisor] agrega el expandir/reducir que
// pide el requisito.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

/// Pinta un comprobante venga como venga:
///   • data URL en base64  → Image.memory (lo que sube la app móvil)
///   • http(s)             → Image.network (comprobantes subidos desde la
///                           web, que van a un almacenamiento externo)
/// Cualquier otro formato cae al widget de error, nunca a una pantalla en
/// blanco sin explicación.
class ComprobanteImage extends StatelessWidget {
  final String fuente;
  final BoxFit fit;
  final double? width, height;

  const ComprobanteImage({
    super.key, required this.fuente, this.fit = BoxFit.contain, this.width, this.height,
  });

  /// Extrae los bytes de una data URL. Devuelve null si no es una data URL
  /// o si el base64 viene corrupto (comprobante truncado en la subida).
  static Uint8List? bytesDeDataUrl(String fuente) {
    if (!fuente.startsWith('data:')) return null;
    final coma = fuente.indexOf(',');
    if (coma == -1) return null;
    try {
      return base64Decode(fuente.substring(coma + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _error(BuildContext context) => Container(
    width: width, height: height ?? 160,
    color: C.surf2,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.broken_image_outlined, color: C.textMut, size: 30),
      const SizedBox(height: 6),
      Text('No se pudo mostrar el comprobante',
        style: TextStyle(fontSize: 11, color: C.textMut), textAlign: TextAlign.center),
    ]));

  @override
  Widget build(BuildContext context) {
    final bytes = bytesDeDataUrl(fuente);
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, width: width, height: height,
        errorBuilder: (ctx, _, __) => _error(ctx));
    }
    if (fuente.startsWith('http://') || fuente.startsWith('https://')) {
      return Image.network(fuente, fit: fit, width: width, height: height,
        loadingBuilder: (ctx, child, progreso) => progreso == null
          ? child
          : SizedBox(width: width, height: height ?? 160,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.green))),
        errorBuilder: (ctx, _, __) => _error(ctx));
    }
    return _error(context);
  }
}

/// Tarjeta del comprobante en el detalle del pedido: se muestra reducida y
/// se puede EXPANDIR (in situ) o abrir a pantalla completa con zoom.
/// Ambas acciones son reversibles — "expandir" vuelve a "reducir", que es
/// exactamente lo que pide el requisito.
class ComprobanteVisor extends StatefulWidget {
  final String fuente;
  /// Texto opcional debajo del título (ej. "Verificado por $45.000" o
  /// "En revisión") — sale del veredicto del backend.
  final String? estadoTexto;
  final Color? estadoColor;

  const ComprobanteVisor({super.key, required this.fuente, this.estadoTexto, this.estadoColor});

  @override State<ComprobanteVisor> createState() => _ComprobanteVisorState();
}

class _ComprobanteVisorState extends State<ComprobanteVisor> {
  bool _expandido = false;

  void _abrirPantallaCompleta() => showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(children: [
        // InteractiveViewer = pellizcar para hacer zoom. Un comprobante
        // fotografiado de lejos es ilegible sin esto.
        InteractiveViewer(
          minScale: 1, maxScale: 5,
          child: Center(child: ComprobanteImage(fuente: widget.fuente, fit: BoxFit.contain)),
        ),
        Positioned(top: 4, right: 4,
          child: Material(
            color: Colors.black54, shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context)))),
      ]),
    ));

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    decoration: BoxDecoration(
      color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Row(children: [
          const Icon(Icons.receipt_long_outlined, size: 18, color: C.green),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Comprobante de pago',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            if (widget.estadoTexto != null)
              Text(widget.estadoTexto!,
                style: TextStyle(fontSize: 12, color: widget.estadoColor ?? C.textSec)),
          ])),
          // Los dos controles que pide el requisito, siempre visibles:
          // alternar reducido/expandido, y ver a pantalla completa.
          IconButton(
            icon: Icon(_expandido ? Icons.unfold_less : Icons.unfold_more, size: 20, color: C.green),
            tooltip: _expandido ? 'Reducir' : 'Expandir',
            onPressed: () => setState(() => _expandido = !_expandido)),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 22, color: C.green),
            tooltip: 'Ver en pantalla completa',
            onPressed: _abrirPantallaCompleta),
        ]),
      ),
      // La transición de alto hace evidente que "expandir" y "reducir" son
      // la misma acción en dos sentidos, en vez de un salto brusco.
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          onDoubleTap: _abrirPantallaCompleta,
          child: SizedBox(
            width: double.infinity,
            height: _expandido ? 420 : 150,
            // BoxFit.contain al expandir: un comprobante alto y angosto
            // recortado por 'cover' es justamente lo que no deja leer el
            // valor, que suele ir arriba del todo.
            child: ComprobanteImage(
              fuente: widget.fuente,
              fit: _expandido ? BoxFit.contain : BoxFit.cover),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          _expandido
            ? 'Toca para reducir · doble toque para pantalla completa'
            : 'Toca para expandir · doble toque para pantalla completa',
          style: TextStyle(fontSize: 11, color: C.textMut)),
      ),
    ]));
}
