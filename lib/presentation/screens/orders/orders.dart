import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';

// ── MIS PEDIDOS ───────────────────────────────────────────────
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override void initState() {
    super.initState();
    // Trae el historial completo del backend al entrar — no solo lo que
    // haya en memoria de pedidos creados en esta misma sesión.
    AppState.instance.cargarPedidos();
  }

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
      final pedidos = AppState.instance.pedidos;
      return Scaffold(backgroundColor: C.bg,
        appBar: AppBar(title: const Text('Mis pedidos'), backgroundColor: C.surface),
        body: RefreshIndicator(
          color: C.green,
          onRefresh: AppState.instance.cargarPedidos,
          child: pedidos.isEmpty
            ? ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: C.textMut),
                  const SizedBox(height: 16),
                  Text('Sin pedidos aún', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
                  const SizedBox(height: 8),
                  Text('Tus pedidos aparecerán aquí', style: TextStyle(color: C.textSec))]))])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: pedidos.length,
                itemBuilder: (_, i) => _OrderCard(pedido: pedidos[i]))));
    });
}

class _OrderCard extends StatelessWidget {
  final Pedido pedido;
  const _OrderCard({required this.pedido});

  @override Widget build(BuildContext context) {
    final color = Color(Pedido.coloresEstado[pedido.estado] ?? 0xFF6B6355);
    final label = Pedido.estados[pedido.estado] ?? pedido.estado;

    return GestureDetector(
      onTap: () => context.push('/pedidos/${pedido.id}'),
      child: Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(pedido.id, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(100),
                border: Border.all(color: color.withOpacity(0.3))),
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
          ]),
          const SizedBox(height: 8),
          Text(pedido.items.map((i) => '${i.cantidad}× ${i.producto.nombre}').join(', '),
            style: TextStyle(fontSize: 13, color: C.textSec), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.schedule_outlined, size: 13, color: C.textMut),
              const SizedBox(width: 4),
              Text(pedido.fecha, style: TextStyle(fontSize: 12, color: C.textMut))]),
            Text(fmt(pedido.total),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.green)),
          ]),
        ])));
  }
}


// ── DETALLE PEDIDO ────────────────────────────────────────────
class OrderDetailScreen extends StatefulWidget {
  final String id;
  const OrderDetailScreen({super.key, required this.id});
  @override State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Timer? _poll;
  bool   _reenviando = false;

  @override void initState() {
    super.initState();
    // Refresco inmediato al entrar + polling cada 18s mientras la pantalla
    // esté abierta, para que el cliente vea el avance sin salir y volver.
    AppState.instance.refrescarPedido(widget.id);
    _poll = Timer.periodic(const Duration(seconds: 18),
      (_) => AppState.instance.refrescarPedido(widget.id));
  }

  @override void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _repetirPedido(Pedido p) async {
    if (AppState.instance.carrito.isNotEmpty) {
      final reemplazar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: C.card,
          title: const Text('¿Reemplazar carrito?'),
          content: const Text(
            'Ya tienes productos en tu carrito. ¿Quieres reemplazarlos con los de este pedido?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Reemplazar', style: TextStyle(color: C.green, fontWeight: FontWeight.w700))),
          ]));
      if (reemplazar != true) return;
    }
    AppState.instance.repetirPedido(p);
    if (!mounted) return;
    context.push('/checkout');
  }

  Future<void> _solicitarDevolucion(Pedido p) async {
    final enviado = await showDialog<bool>(
      context: context,
      builder: (_) => _DevolucionDialog(pedido: p));
    if (enviado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solicitud de devolución enviada ✓'), backgroundColor: C.green));
    }
  }

  Future<void> _reenviarComprobante() async {
    try {
      final archivo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      setState(() => _reenviando = true);
      final comprobanteBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await AppState.instance.reenviarComprobante(widget.id, comprobanteBase64);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Comprobante reenviado, en revisión ✓'), backgroundColor: C.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo reenviar el comprobante: $e'), backgroundColor: C.red));
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
      final p = AppState.instance.pedidos.firstWhere((x) => x.id == widget.id,
        orElse: () => Pedido(id: widget.id, estado: '?', fecha: '', metodoPago: '', items: [], total: 0));

      return Scaffold(backgroundColor: C.bg,
        appBar: AppBar(title: Text(p.id), backgroundColor: C.surface),
        body: RefreshIndicator(
          color: C.green,
          onRefresh: () => AppState.instance.refrescarPedido(widget.id),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Entrega + paso a paso del estado, juntos ──
            _EntregaYTimeline(pedido: p, reenviando: _reenviando,
              onReenviarComprobante: _reenviarComprobante),

            const SizedBox(height: 20),

            // ── Ítems ──
            Text('Productos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(height: 10),
            ...p.items.map((item) => Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('${item.cantidad}',
                    style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.producto.nombre,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
                  if (item.nombresExtras.isNotEmpty)
                    Text(item.nombresExtras.join(', '),
                      style: TextStyle(fontSize: 12, color: C.textMut)),
                ])),
                Text(fmt(item.subtotal),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
              ]))),

            // ── Detalles ──
            _row(Icons.payments_outlined, 'Método de pago', p.metodoPago),
            if (p.notas != null && p.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _row(Icons.notes_outlined, 'Notas', p.notas!)],

            const SizedBox(height: 16),
            Divider(color: C.border),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
              Text(fmt(p.total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.green))]),

            // ── Acciones ── (botones sueltos: directo en el Column, no en
            // un Row, para no chocar con el minimumSize de ancho infinito
            // que el tema le da a ElevatedButton/OutlinedButton).
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _repetirPedido(p),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Repetir pedido')),
            if (p.estado == 'entregado') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _solicitarDevolucion(p),
                style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.red)),
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: const Text('Solicitar devolución')),
            ],

            const SizedBox(height: 40),
          ])),
        ));
    });

  Widget _row(IconData icon, String k, String v) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: C.green),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: TextStyle(fontSize: 11, color: C.textMut)),
      Text(v, style: TextStyle(fontSize: 14, color: C.text, fontWeight: FontWeight.w500))])),
  ]);
}

// ── Formulario "Solicitar devolución" ──────────────────────────
// POST /api/devoluciones (pedido_id + items + motivo) — queda "pendiente"
// para que el staff la revise, no cambia el estado del pedido por sí sola.
// El cliente marca con checkboxes cuáles productos del pedido quiere
// devolver (puede ser más de uno), pero escribe un solo motivo para toda
// la solicitud — ver AppState.solicitarDevolucion.
const _kMaxPalabrasMotivo = 20;

int _contarPalabras(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

// Si el texto ya tiene más de `max` palabras, lo recorta ahí mismo — así
// el límite se aplica mientras el cliente escribe, no solo al enviar.
String _limitarPalabras(String s, int max) {
  final matches = RegExp(r'\S+').allMatches(s).toList();
  if (matches.length <= max) return s;
  return s.substring(0, matches[max - 1].end);
}

class _DevolucionDialog extends StatefulWidget {
  final Pedido pedido;
  const _DevolucionDialog({required this.pedido});
  @override State<_DevolucionDialog> createState() => _DevolucionDialogState();
}

class _DevolucionDialogState extends State<_DevolucionDialog> {
  final _motivoCtrl = TextEditingController();
  bool    _enviando = false;
  String? _error;
  int     _palabras = 0;
  final Set<CartItem> _seleccionados = {};

  @override void initState() {
    super.initState();
    // Un solo producto en el pedido: se preselecciona, no hace falta marcarlo.
    if (widget.pedido.items.length == 1) _seleccionados.add(widget.pedido.items.first);
    _motivoCtrl.addListener(_onMotivoChanged);
  }

  void _onMotivoChanged() {
    final texto = _motivoCtrl.text;
    final limitado = _limitarPalabras(texto, _kMaxPalabrasMotivo);
    if (limitado != texto) {
      // Recortar dispara este mismo listener de nuevo (value setter), pero
      // la segunda pasada ya entra por la rama de arriba (limitado == texto).
      _motivoCtrl.value = TextEditingValue(
        text: limitado, selection: TextSelection.collapsed(offset: limitado.length));
      return;
    }
    setState(() => _palabras = _contarPalabras(texto));
  }

  void _toggle(CartItem item) => setState(() {
    if (!_seleccionados.remove(item)) _seleccionados.add(item);
    _error = null;
  });

  @override void dispose() { _motivoCtrl.dispose(); super.dispose(); }

  Future<void> _enviar() async {
    final motivo = _motivoCtrl.text.trim();
    if (_seleccionados.isEmpty) {
      setState(() => _error = 'Elige al menos un producto para devolver');
      return;
    }
    if (motivo.isEmpty) {
      setState(() => _error = 'Cuéntanos por qué quieres la devolución');
      return;
    }
    setState(() { _enviando = true; _error = null; });
    final err = await AppState.instance.solicitarDevolucion(widget.pedido.id, motivo, _seleccionados.toList());
    if (!mounted) return;
    if (err != null) {
      setState(() { _enviando = false; _error = err; });
      return;
    }
    Navigator.pop(context, true);
  }

  @override Widget build(BuildContext context) {
    final items = widget.pedido.items;
    return AlertDialog(
      backgroundColor: C.card,
      title: const Text('Solicitar devolución'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (items.isNotEmpty) ...[
          Text(items.length > 1 ? '¿Qué productos quieres devolver?' : 'Producto a devolver',
            style: TextStyle(fontSize: 13, color: C.textSec)),
          const SizedBox(height: 8),
          for (final item in items) ...[
            _ProductoDevolucionOpcion(
              item: item,
              seleccionado: _seleccionados.contains(item),
              onTap: () => _toggle(item)),
            if (item != items.last) const SizedBox(height: 6),
          ],
          const SizedBox(height: 16),
        ],
        Text('¿Por qué quieres la devolución?', style: TextStyle(fontSize: 13, color: C.textSec)),
        const SizedBox(height: 8),
        TextField(controller: _motivoCtrl, maxLines: 3, autofocus: items.length <= 1, style: TextStyle(color: C.text),
          decoration: const InputDecoration(hintText: 'Cuéntanos qué pasó...')),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerRight,
          child: Text('$_palabras/$_kMaxPalabrasMotivo palabras',
            style: TextStyle(fontSize: 11,
              color: _palabras >= _kMaxPalabrasMotivo ? C.red : C.textMut))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: C.red, fontSize: 12))),
      ])),
      actions: [
        TextButton(onPressed: _enviando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(onPressed: _enviando ? null : _enviar,
          child: _enviando
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.green))
            : const Text('Enviar', style: TextStyle(color: C.green, fontWeight: FontWeight.w700))),
      ]);
  }
}

// ── Opción seleccionable de producto dentro del diálogo de devolución ──
class _ProductoDevolucionOpcion extends StatelessWidget {
  final CartItem item;
  final bool seleccionado;
  final VoidCallback onTap;
  const _ProductoDevolucionOpcion({required this.item, required this.seleccionado, required this.onTap});

  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: seleccionado ? C.greenBg : C.surf2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: seleccionado ? C.green : C.border)),
      child: Row(children: [
        Icon(seleccionado ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18, color: seleccionado ? C.green : C.textMut),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.cantidad}× ${item.producto.nombre}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
          if (item.nombresExtras.isNotEmpty)
            Text(item.nombresExtras.join(', '), style: TextStyle(fontSize: 11, color: C.textMut)),
        ])),
      ])));
}

// ── Tarjeta de entrega + timeline de estados ──────────────────
// Muestra juntos, en un mismo bloque visual, cómo va el pedido (paso a
// paso) y cómo lo va a recibir el cliente (local/domicilio + dirección),
// para que se entiendan de un vistazo.
class _EntregaYTimeline extends StatelessWidget {
  final Pedido pedido;
  final bool reenviando;
  final VoidCallback onReenviarComprobante;
  const _EntregaYTimeline({required this.pedido, required this.reenviando, required this.onReenviarComprobante});

  @override Widget build(BuildContext context) {
    final esDomicilio = pedido.tipoEntrega == 'domicilio';

    return Container(width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Cómo lo recibe ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(esDomicilio ? Icons.delivery_dining_outlined : Icons.storefront_outlined, size: 20, color: C.green),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(esDomicilio ? 'Entrega a domicilio' : 'Recoges en el local',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            if (esDomicilio && pedido.direccionEntrega != null && pedido.direccionEntrega!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2),
                child: Text(pedido.direccionEntrega!, style: TextStyle(fontSize: 12, color: C.textSec))),
          ])),
          if (pedido.fecha.isNotEmpty)
            Text(pedido.fecha, style: TextStyle(fontSize: 11, color: C.textMut)),
        ]),

        const SizedBox(height: 16),
        Divider(color: C.border, height: 1),
        const SizedBox(height: 16),

        if (pedido.esCancelado)
          _CanceladoBanner(pedido: pedido, reenviando: reenviando, onReenviar: onReenviarComprobante)
        else
          _EstadoStepper(pedido: pedido),
      ]));
  }
}

// ── Paso a paso vertical de los 5 estados reales del backend ──
class _EstadoStepper extends StatelessWidget {
  final Pedido pedido;
  const _EstadoStepper({required this.pedido});

  @override Widget build(BuildContext context) {
    final pasos = Pedido.secuencia;
    // Si por algún motivo llega un estado que no está en la secuencia
    // (o aún no se sincronizó), no se marca ningún paso como superado.
    final actual = pedido.pasoActual == -1 ? 0 : pedido.pasoActual;

    return Column(children: [
      for (var i = 0; i < pasos.length; i++)
        _PasoTimeline(
          estado: pasos[i],
          // El último paso (entregado) no tiene un paso siguiente que lo
          // deje "superado" — llegar ahí YA es la meta. Sin este OR se
          // quedaba marcado para siempre como "en curso" (punto
          // parpadeante) en vez de completado (check verde), aunque el
          // pedido realmente ya estuviera entregado.
          completado: i < actual || (i == actual && i == pasos.length - 1),
          esActual: i == actual,
          esUltimo: i == pasos.length - 1,
          sub: i == 0 ? _subEstadoPago(esActual: i == actual, completado: i < actual) : null,
        ),
    ]);
  }

  // Sub-estados del paso "Verificando pago" cuando el pedido trae
  // comprobante de transferencia adjunto.
  String? _subEstadoPago({required bool esActual, required bool completado}) {
    if (!pedido.tieneComprobante) return null;
    if (esActual)    return 'Esperando revisión del cajero';
    if (completado)  return 'Comprobante aprobado ✓';
    return null;
  }
}

class _PasoTimeline extends StatelessWidget {
  final String estado;
  final bool completado, esActual, esUltimo;
  final String? sub;
  const _PasoTimeline({required this.estado, required this.completado,
    required this.esActual, required this.esUltimo, this.sub});

  @override Widget build(BuildContext context) {
    final label = Pedido.estados[estado] ?? estado;
    final color = Color(Pedido.coloresEstado[estado] ?? 0xFF6B6355);
    final activo = completado || esActual;

    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 24, height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: completado ? C.green : (esActual ? color.withOpacity(0.15) : C.surf2),
            border: Border.all(color: completado ? C.green : (esActual ? color : C.border), width: esActual ? 2 : 1)),
          child: completado
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : (esActual ? Center(child: Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color))) : null)),
        if (!esUltimo)
          Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2),
            color: completado ? C.green : C.border)),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(padding: EdgeInsets.only(bottom: esUltimo ? 0 : 18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 14,
          fontWeight: esActual ? FontWeight.w800 : FontWeight.w600,
          color: activo ? C.text : C.textMut)),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 3),
          child: Text(sub!, style: TextStyle(fontSize: 12,
            color: esActual ? C.gold : C.green, fontWeight: FontWeight.w600))),
      ]))),
    ]));
  }
}

// ── Estado especial "cancelado", fuera de la secuencia normal ──
class _CanceladoBanner extends StatelessWidget {
  final Pedido pedido;
  final bool reenviando;
  final VoidCallback onReenviar;
  const _CanceladoBanner({required this.pedido, required this.reenviando, required this.onReenviar});

  @override Widget build(BuildContext context) {
    // Un pedido cancelado que sí traía comprobante de pago casi siempre
    // significa que el cajero lo rechazó al verificarlo; se le ofrece
    // reenviar uno nuevo. Si nunca tuvo comprobante, es una cancelación
    // normal (sin acción de pago pendiente).
    final rechazoDeComprobante = pedido.tieneComprobante;

    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.red.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cancel_outlined, color: C.red, size: 20),
          const SizedBox(width: 8),
          Text('Pedido cancelado', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.red)),
        ]),
        const SizedBox(height: 8),
        Text(rechazoDeComprobante
          ? 'El cajero rechazó el comprobante de pago que enviaste. Sube uno nuevo para volver a intentarlo.'
          : 'Este pedido fue cancelado. Si tienes dudas, contáctanos.',
          style: TextStyle(fontSize: 13, color: C.textSec)),
        if (rechazoDeComprobante) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: reenviando ? null : onReenviar,
            icon: reenviando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.green))
              : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(reenviando ? 'Subiendo...' : 'Subir nuevo comprobante')),
        ],
      ]));
  }
}