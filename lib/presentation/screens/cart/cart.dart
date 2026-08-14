import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';

// ── CARRITO ───────────────────────────────────────────────────
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
      final items = AppState.instance.carrito;
      final total = AppState.instance.cartTotal;

      if (items.isEmpty) return Scaffold(backgroundColor: C.bg,
        appBar: AppBar(title: const Text('Carrito'), backgroundColor: C.surface),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined, size: 68, color: C.textMut),
          const SizedBox(height: 16),
          Text('Tu carrito está vacío', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 8),
          Text('Agrega productos desde el menú', style: TextStyle(color: C.textSec))])));

      return Scaffold(backgroundColor: C.bg,
        appBar: AppBar(title: Text('Carrito (${items.length})'), backgroundColor: C.surface,
          actions: [TextButton(
            onPressed: () => AppState.instance.clearCart(),
            child: const Text('Limpiar', style: TextStyle(color: C.red)))]),
        body: Column(children: [
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
            itemBuilder: (_, i) => _CartTile(item: items[i]))),
          _CartBottom(total: total),
        ]));
    });
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: Row(children: [
      _Miniatura(imagen: item.producto.imagen),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Nombres largos se truncan con "..." en vez de empujar los
        // controles de cantidad fuera de la fila (causaba el
        // "RenderFlex overflowed" al agregar la miniatura).
        Text(item.producto.nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
        if (item.nombresExtras.isNotEmpty)
          Text(item.nombresExtras.join(', '),
            style: TextStyle(fontSize: 11, color: C.textMut), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(fmt(item.subtotal),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.green)),
      ])),
      const SizedBox(width: 8),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _Btn(Icons.remove, () => AppState.instance.updateQty(item.cartKey, -1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${item.cantidad}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text))),
          _Btn(Icons.add, () => AppState.instance.updateQty(item.cartKey, 1), isAdd: true),
        ]),
        const SizedBox(height: 6),
        GestureDetector(onTap: () => AppState.instance.removeFromCart(item.cartKey),
          child: const Text('Quitar', style: TextStyle(fontSize: 12, color: C.red, fontWeight: FontWeight.w600))),
      ]),
    ]));
}

// ── Miniatura de producto (mismo campo/URL que product_detail.dart) ──
class _Miniatura extends StatelessWidget {
  final String? imagen;
  const _Miniatura({required this.imagen});

  @override Widget build(BuildContext context) {
    final url = buildImageUrl(imagen);
    return Container(width: 56, height: 56, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(10)),
      child: url == null
          ? Icon(Icons.coffee, color: C.textMut, size: 26)
          : Image.network(url, width: 56, height: 56, fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                progress == null ? child : Icon(Icons.coffee, color: C.textMut, size: 26),
              errorBuilder: (context, error, stack) => Icon(Icons.coffee, color: C.textMut, size: 26)));
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback fn; final bool isAdd;
  const _Btn(this.icon, this.fn, {this.isAdd = false});

  @override Widget build(BuildContext context) => GestureDetector(onTap: fn,
    child: Container(width: 28, height: 28,
      decoration: BoxDecoration(
        color: isAdd ? C.greenBg : C.surf2, shape: BoxShape.circle,
        border: Border.all(color: isAdd ? C.green.withOpacity(0.3) : C.border)),
      child: Icon(icon, size: 14, color: isAdd ? C.green : C.text)));
}

class _CartBottom extends StatelessWidget {
  final double total;
  const _CartBottom({required this.total});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        Text(fmt(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.green))]),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: () => context.push('/checkout'),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Proceder al pago')),
    ]));
}


// ── CHECKOUT ──────────────────────────────────────────────────
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override State<CheckoutScreen> createState() => _ChkState();
}

class _ChkState extends State<CheckoutScreen> {
  // Paso a paso igual que la web (PasarelaPago en Landing.jsx), simplificado
  // a lo que necesita la app: 1) tipo de entrega (+ selector de local si
  // aplica), 2) dirección alternativa (solo domicilio), 3) método de pago
  // + comprobante + confirmar.
  int     _step        = 1;
  String? _tipoEntrega; // null | 'domicilio' | 'local'
  int?    _localId;     // obligatorio cuando _tipoEntrega == 'local'
  String  _metodo      = metodosPago.first;
  final   _dirCtrl      = TextEditingController();
  final   _notasCtrl    = TextEditingController();
  bool    _loading      = false;

  Uint8List? _comprobanteBytes;
  bool       _cargandoComprobante = false;

  bool _cargandoLocales = true;

  @override void initState() {
    super.initState();
    // Se piden apenas se abre el checkout (no solo cuando el cliente elige
    // "Recoger en el local") para que el selector no tenga que esperar a
    // una llamada de red en medio del flujo.
    _cargarLocalesInicial();
  }

  Future<void> _cargarLocalesInicial() async {
    await AppState.instance.cargarLocales();
    if (!mounted) return;
    final locales = AppState.instance.locales;
    setState(() {
      _cargandoLocales = false;
      // Un solo local activo: se preselecciona solo, sin esperar un tap
      // del cliente (no tiene sentido "elegir" cuando no hay opción real).
      if (locales.length == 1) _localId = locales.first.id;
    });
  }

  // Solo Nequi y Transferencia exigen comprobante — Efectivo se paga al
  // recibir/retirar el pedido, sin nada que subir.
  bool get _requiereComprobante => _metodo != 'Efectivo';

  // El servicio de domicilio solo cubre comuna 8 y 9 (igual que la web).
  // Si el perfil del cliente no está en ninguna de esas dos, "Domicilio"
  // queda deshabilitado y solo puede recoger en el local.
  bool get _comunaValida {
    final comuna = AppState.instance.usuario?.comuna;
    return comuna != null && comunasDisponibles.contains(comuna);
  }

  @override void dispose() { _dirCtrl.dispose(); _notasCtrl.dispose(); super.dispose(); }

  Future<void> _seleccionarComprobante() async {
    setState(() => _cargandoComprobante = true);
    try {
      final archivo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (archivo != null) {
        final bytes = await archivo.readAsBytes();
        if (!mounted) return;
        setState(() => _comprobanteBytes = bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $e'), backgroundColor: C.red));
    } finally {
      if (mounted) setState(() => _cargandoComprobante = false);
    }
  }

  void _quitarComprobante() => setState(() => _comprobanteBytes = null);

  Future<void> _confirmar() async {
    if (_requiereComprobante && _comprobanteBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Debes subir el comprobante de pago antes de continuar'),
        backgroundColor: C.red));
      return;
    }
    setState(() => _loading = true);
    try {
      final comprobanteBase64 = _requiereComprobante
          ? 'data:image/jpeg;base64,${base64Encode(_comprobanteBytes!)}'
          : null;
      final esDomicilio = _tipoEntrega == 'domicilio';
      final dirAlterna = _dirCtrl.text.trim();
      final pedido = await AppState.instance.crearPedido(
        // _metodo se muestra en la UI con mayúscula inicial (coincide con
        // las etiquetas de metodosPago), pero el backend espera el mismo
        // id en minúscula que ya usa la web ('efectivo'/'nequi'/
        // 'transferencia' — ver METODOS en Landing.jsx) — mismo bug de
        // mayúsculas que ya se corrigió ahí, evitado acá desde el inicio.
        metodoPago: _metodo.toLowerCase(),
        notas: _notasCtrl.text.isNotEmpty ? _notasCtrl.text : null,
        // Vacío = se usa la dirección guardada en el perfil del cliente (el
        // backend/cajero la resuelve con cliente_id); no se sobrescribe el
        // perfil, solo aplica a este pedido puntual.
        direccionEntrega: esDomicilio && dirAlterna.isNotEmpty ? dirAlterna : null,
        tipoEntrega: esDomicilio ? 'domicilio' : 'local',
        localId: esDomicilio ? null : _localId,
        comprobante: comprobanteBase64);
      if (!mounted) return;
      context.go('/pedidos/${pedido.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Pedido confirmado! ✓'), backgroundColor: C.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo enviar el pedido: $e'), backgroundColor: C.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: C.bg,
    appBar: AppBar(title: const Text('Confirmar pedido'), backgroundColor: C.surface),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PasoIndicador(step: _step, total: _tipoEntrega == 'domicilio' ? 3 : 2),
      const SizedBox(height: 20),
      if (_step == 1) _pasoEntrega()
      else if (_step == 2) _pasoDireccion()
      else _pasoPago(),
    ])),
  );

  // ── Paso 1: ¿cómo lo recibe? (+ selector de local si aplica) ──
  Widget _pasoEntrega() {
    // "Recoger en el local" solo queda listo para continuar una vez que
    // hay un local elegido (o preseleccionado, si solo hay uno activo).
    final entregaValida = _tipoEntrega == 'domicilio'
        || (_tipoEntrega == 'local' && _localId != null);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('¿Cómo quieres recibir tu pedido?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 14),
      _OpcionEntrega(
        icon: Icons.delivery_dining_outlined, titulo: 'A domicilio',
        subtitulo: _comunaValida ? 'Te lo llevamos a tu dirección' : 'No disponible para tu comuna',
        seleccionado: _tipoEntrega == 'domicilio', habilitado: _comunaValida,
        onTap: () => setState(() => _tipoEntrega = 'domicilio')),
      const SizedBox(height: 10),
      _OpcionEntrega(
        icon: Icons.storefront_outlined, titulo: 'Recoger en el local',
        subtitulo: 'Recoge tu pedido en tienda',
        seleccionado: _tipoEntrega == 'local', habilitado: true,
        onTap: () => setState(() => _tipoEntrega = 'local')),
      if (_tipoEntrega == 'local') ...[
        const SizedBox(height: 12),
        _selectorLocales(),
      ],
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.info.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.info.withOpacity(0.25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 16, color: C.info),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Por el momento nuestro servicio de domicilios solo cubre la comuna 8 y 9 de Medellín.',
            style: TextStyle(fontSize: 12, color: C.textSec))),
        ])),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: !entregaValida ? null : () => setState(() => _step = _tipoEntrega == 'domicilio' ? 2 : 3),
        child: const Text('Continuar →')),
    ]);
  }

  // Selector de local para "Recoger en el local" — GET /api/locales
  // (ya filtrado a solo activos por el backend). Obligatorio: el botón
  // "Continuar" de arriba queda deshabilitado hasta que _localId != null.
  Widget _selectorLocales() {
    if (_cargandoLocales) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: C.green))));
    }

    final locales = AppState.instance.locales;
    if (locales.isEmpty) {
      return Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.red.withOpacity(0.3))),
        child: Text('No hay locales disponibles para recoger en este momento.',
          style: TextStyle(fontSize: 12, color: C.red)));
    }

    // Un solo local activo: aviso en vez de una tarjeta "para elegir" —
    // ya quedó preseleccionado en _cargarLocalesInicial().
    if (locales.length == 1) {
      final unico = locales.first;
      return Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.green.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.storefront, color: C.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Hoy solo estamos atendiendo en ${unico.nombre}.',
            style: TextStyle(fontSize: 13, color: C.text, fontWeight: FontWeight.w600))),
        ]));
    }

    // Varios locales activos: tarjetas seleccionables, mismo estilo que
    // las opciones de tipo de entrega.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Elige tu local más cercano', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 10),
      for (final local in locales) ...[
        _OpcionEntrega(
          icon: Icons.storefront_outlined, titulo: local.nombre,
          subtitulo: local.direccion ?? '', seleccionado: _localId == local.id, habilitado: true,
          onTap: () => setState(() => _localId = local.id)),
        if (local != locales.last) const SizedBox(height: 10),
      ],
    ]);
  }

  // ── Paso 2: dirección alternativa (solo domicilio) ──
  Widget _pasoDireccion() {
    final dirPerfil = AppState.instance.usuario?.direccion;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.gold.withOpacity(0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📍', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Recuerda que por el momento nuestro servicio de domicilios solo cubre la comuna 8 y 9 de Medellín.',
            style: TextStyle(fontSize: 13, color: C.text)))])),
      const SizedBox(height: 20),
      Text('¿Deseas recibir el pedido en otra dirección?',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
      const SizedBox(height: 4),
      Text(dirPerfil != null && dirPerfil.isNotEmpty
          ? 'Si lo dejas vacío usaremos tu dirección guardada: $dirPerfil'
          : 'Si lo dejas vacío, el cajero se pondrá en contacto para confirmar la dirección.',
        style: TextStyle(fontSize: 12, color: C.textSec)),
      const SizedBox(height: 10),
      TextField(controller: _dirCtrl, style: TextStyle(color: C.text),
        decoration: InputDecoration(hintText: 'Ej: Calle 45 #23-10, apto 301 (opcional)',
          prefixIcon: Icon(Icons.location_on_outlined, color: C.textMut, size: 20))),
      const SizedBox(height: 24),
      // Mismo patrón/motivo que en _pasoPago: el OutlinedButton necesita
      // ancho Y alto fijos (SizedBox) para no chocar con el minimumSize de
      // ancho infinito del tema dentro de un Row sin restricciones.
      Row(children: [
        SizedBox(width: 110, height: 44, child: OutlinedButton(
          onPressed: () => setState(() => _step = 1), child: const Text('← Atrás'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: () => setState(() => _step = 3), child: const Text('Continuar →'))),
      ]),
    ]);
  }

  // ── Paso 3: resumen + método de pago + comprobante + confirmar ──
  Widget _pasoPago() {
    final items = AppState.instance.carrito;
    final total = AppState.instance.cartTotal;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Resumen ──
      Text('Resumen del pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 10),
      Container(clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: [
            ...items.map((i) => ListTile(dense: true,
              leading: Text('${i.cantidad}×', style: const TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 14)),
              title: Text(i.producto.nombre, style: TextStyle(color: C.text, fontSize: 13)),
              subtitle: i.nombresExtras.isNotEmpty
                  ? Text(i.nombresExtras.join(', '), style: TextStyle(color: C.textMut, fontSize: 11))
                  : null,
              trailing: Text(fmt(i.subtotal), style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)))),
            Divider(height: 1, color: C.border),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                Text(fmt(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.green))])),
          ]),
        )),

      // ── Método de pago ──
      const SizedBox(height: 22),
      Text('Método de pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: metodosPago.map((m) {
        final sel = _metodo == m;
        return GestureDetector(onTap: () => setState(() => _metodo = m),
          child: AnimatedContainer(duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? C.greenBg : C.surf2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? C.green : C.border)),
            child: Text(m, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: sel ? C.green : C.textSec))));
      }).toList()),

      // ── Comprobante de pago (solo Nequi/Transferencia) ──
      if (_requiereComprobante) ...[
        const SizedBox(height: 22),
        Text('Comprobante de pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 4),
        Text('Sube una foto o captura de pantalla del pago ($_metodo)',
          style: TextStyle(fontSize: 12, color: C.textSec)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cargandoComprobante ? null : _seleccionarComprobante,
          child: _comprobanteBytes == null
              ? Container(
                  width: double.infinity, height: 140,
                  decoration: BoxDecoration(
                    color: C.surf2, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.border)),
                  child: Center(
                    child: _cargandoComprobante
                        ? const CircularProgressIndicator(color: C.green, strokeWidth: 2)
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.cloud_upload_outlined, size: 30, color: C.textMut),
                            const SizedBox(height: 8),
                            Text('Toca para subir el comprobante',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
                          ])))
              : Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
                  child: Stack(children: [
                    Image.memory(_comprobanteBytes!,
                      width: double.infinity, height: 180, fit: BoxFit.cover),
                    Positioned(top: 8, right: 8,
                      child: GestureDetector(
                        onTap: _quitarComprobante,
                        child: Container(padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                    Positioned(bottom: 8, left: 8,
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle, color: C.green, size: 14),
                          SizedBox(width: 4),
                          Text('Comprobante cargado', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ]))),
                  ])),
        ),
      ] else ...[
        const SizedBox(height: 22),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.green.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.payments_outlined, color: C.green, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Pagas en efectivo al recibir o retirar tu pedido. No necesitas subir comprobante.',
              style: TextStyle(fontSize: 12, color: C.text))),
          ])),
      ],

      // ── Notas ──
      const SizedBox(height: 16),
      Text('Notas (opcional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
      const SizedBox(height: 8),
      TextField(controller: _notasCtrl, maxLines: 3, style: TextStyle(color: C.text),
        decoration: const InputDecoration(hintText: 'Ej: sin azúcar, extra caliente, aperitivo de amaretto...')),

      const SizedBox(height: 24),
      // Ancho Y alto fijos y explícitos en el OutlinedButton (SizedBox), en
      // vez de dejarlo calcular su tamaño intrínseco dentro de un Row sin
      // restricciones — el tema de la app le da a ElevatedButton/
      // OutlinedButton un minimumSize con ancho double.infinity (ver
      // theme.dart), y un Row da ancho NO acotado a los hijos que no son
      // Expanded/Flexible, así que ese botón intentaba satisfacer un ancho
      // infinito contra una restricción ya infinita → "BoxConstraints
      // forces an infinite width" y, en cascada, "Cannot hit test a render
      // box that has never been laid out". NO uses crossAxisAlignment:
      // stretch en este Row: vive dentro de un Column dentro de un
      // SingleChildScrollView (alto infinito), y "stretch" pide llenar esa
      // altura — eso fue lo que causó el error de "altura infinita" en un
      // intento anterior.
      Row(children: [
        SizedBox(width: 110, height: 44, child: OutlinedButton(
          onPressed: () => setState(() => _step = _tipoEntrega == 'domicilio' ? 2 : 1),
          child: const Text('← Atrás'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: (_loading || items.isEmpty || (_requiereComprobante && _comprobanteBytes == null)) ? null : _confirmar,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirmar pedido ✓'))),
      ]),
      if (_requiereComprobante && _comprobanteBytes == null) ...[
        const SizedBox(height: 8),
        Center(child: Text('Sube el comprobante de pago para continuar',
          style: TextStyle(fontSize: 12, color: C.textMut))),
      ],
      const SizedBox(height: 40),
    ]);
  }
}

// ── Indicador simple de paso (1/2, 1/3, etc.) ──────────────────
class _PasoIndicador extends StatelessWidget {
  final int step, total;
  const _PasoIndicador({required this.step, required this.total});

  @override Widget build(BuildContext context) => Row(children: [
    for (var i = 1; i <= total; i++) ...[
      if (i > 1) Expanded(child: Container(height: 2, color: i <= step ? C.green : C.border)),
      Container(width: 24, height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: i <= step ? C.green : C.surf2,
          border: Border.all(color: i <= step ? C.green : C.border)),
        child: Center(child: Text('$i', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: i <= step ? Colors.white : C.textMut)))),
    ],
  ]);
}

// ── Tarjeta seleccionable de tipo de entrega ────────────────────
class _OpcionEntrega extends StatelessWidget {
  final IconData icon; final String titulo, subtitulo;
  final bool seleccionado, habilitado; final VoidCallback onTap;
  const _OpcionEntrega({required this.icon, required this.titulo, required this.subtitulo,
    required this.seleccionado, required this.habilitado, required this.onTap});

  @override Widget build(BuildContext context) => Opacity(
    opacity: habilitado ? 1 : 0.45,
    child: GestureDetector(onTap: habilitado ? onTap : null,
      child: Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado ? C.greenBg : C.surf2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: seleccionado ? C.green : C.border)),
        child: Row(children: [
          Icon(icon, color: seleccionado ? C.green : C.textMut, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
            Text(subtitulo, style: TextStyle(fontSize: 12, color: C.textSec)),
          ])),
          if (seleccionado) const Icon(Icons.check_circle, color: C.green, size: 20),
        ]))));
}