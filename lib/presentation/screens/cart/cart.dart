import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/precios.dart';
import '../../../data/models/models.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/ocr_service.dart';

// ── Desglose de IVA reutilizable (carrito y checkout) ────────────────
// El impuesto va INCLUIDO en los precios del catálogo: acá NO se suma
// nada, se separa. Ver core/utils/precios.dart para el porqué (resumen: el
// backend recalcula el total con los precios del catálogo y rechaza el
// pedido si no coincide, y contra ESE total valida el comprobante de pago;
// sumar IVA encima rompería las dos cosas).
class DesgloseTotales extends StatelessWidget {
  final double total;
  final bool destacado;
  const DesgloseTotales({super.key, required this.total, this.destacado = true});

  @override Widget build(BuildContext context) {
    final d = DesglosePrecio.deTotalConIva(total);
    Widget linea(String etiqueta, double valor, {bool fuerte = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(etiqueta, style: TextStyle(
          fontSize: fuerte ? 16 : 13,
          fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
          color: fuerte ? C.text : C.textSec)),
        Text(fmt(valor), style: TextStyle(
          fontSize: fuerte ? (destacado ? 20 : 16) : 13,
          fontWeight: fuerte ? FontWeight.w900 : FontWeight.w600,
          color: fuerte ? C.green : C.text)),
      ]));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Con tasa 0 el desglose no aporta nada y solo se muestra el total —
      // el "cuando corresponda" del requisito.
      if (d.aplica) ...[
        linea('Subtotal', d.base),
        linea(etiquetaImpuesto, d.impuesto),
        const SizedBox(height: 4),
      ],
      linea('Total', d.total, fuerte: true),
      if (d.aplica)
        Align(alignment: Alignment.centerRight,
          child: Text('IVA incluido en el precio',
            style: TextStyle(fontSize: 10.5, color: C.textMut))),
    ]);
  }
}

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
      DesgloseTotales(total: total),
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
  // id de la opción de pago elegida — 'pagar_local' (fijo, recogida),
  // 'efectivo_domicilio' (fijo, domicilio), o el id numérico (como string)
  // de un método dinámico de AppState.metodosPago. Nunca el nombre/label
  // directo: dos métodos podrían llamarse parecido, el id es lo único que
  // no cambia. Ver _opcionesPago/_pagoBackend más abajo.
  String? _metodoPagoId;
  // Nota opcional SOLO para "Recoger en el local" (ej. "efectivo exacto",
  // "tarjeta") — mismo campo metodo_pago_local que ya acepta el backend
  // para ese caso (ver AppState.crearPedido). No aplica a domicilio.
  final   _metodoPagoLocalCtrl = TextEditingController();
  final   _dirCtrl      = TextEditingController();
  final   _notasCtrl    = TextEditingController();
  bool    _loading      = false;

  Uint8List? _comprobanteBytes;
  bool       _cargandoComprobante = false;
  // Texto que el OCR del dispositivo leyó del comprobante. Se manda al
  // backend como MATERIA PRIMA; la app no lo interpreta ni decide nada con
  // él (ver services/ocr_service.dart).
  String?    _comprobanteTexto;
  // Estado del OCR, solo para informar al cliente: 'ok' | 'sin_texto' |
  // 'no_soportado' | 'error' | null (aún no se ha leído nada).
  String?    _ocrEstado;
  bool       _leyendoComprobante = false;
  // Último rechazo del backend por el comprobante, para mostrarlo pegado
  // al recuadro de la imagen y no solo como un SnackBar que desaparece.
  String?    _errorComprobante;

  bool _cargandoLocales = true;
  bool _cargandoMetodosPago = true;

  @override void initState() {
    super.initState();
    // Ambas se piden apenas se abre el checkout (no solo cuando el cliente
    // llega al paso que las necesita) para que ningún selector tenga que
    // esperar a una llamada de red en medio del flujo.
    _cargarLocalesInicial();
    _cargarMetodosPagoInicial();
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

  Future<void> _cargarMetodosPagoInicial() async {
    await AppState.instance.cargarMetodosPago();
    if (!mounted) return;
    setState(() => _cargandoMetodosPago = false);
  }

  // ── Opciones de pago según el tipo de entrega ───────────────────
  // Mismas 2 reglas que arma METODOS en Landing.jsx:
  //   • 'local'     → SOLO "Pagar al llegar al local" (fijo, sin
  //     comprobante) — ni los métodos dinámicos ni "Efectivo contraentrega"
  //     tienen sentido para recogida.
  //   • 'domicilio' → los métodos activos configurados desde el admin
  //     (con su descripción/"llave" y QR, si tienen) + "Efectivo
  //     contraentrega" (fijo). Ninguna de las 2 opciones fijas sale de
  //     AppState.metodosPago a propósito — igual que PAGAR_LOCAL_ID/
  //     'efectivo' en la web, así nadie las puede desactivar/editar por
  //     error desde "Métodos de pago" en el admin.
  List<_OpcionPago> get _opcionesPago {
    if (_tipoEntrega == 'local') {
      return const [_OpcionPago(id: 'pagar_local', label: 'Pagar al llegar al local', requiereComprobante: false)];
    }
    if (_tipoEntrega == 'domicilio') {
      return [
        for (final m in AppState.instance.metodosPago)
          _OpcionPago(id: m.id.toString(), label: m.nombre, descripcion: m.descripcion,
            urlQr: m.urlQr, requiereComprobante: true),
        const _OpcionPago(id: 'efectivo_domicilio', label: 'Efectivo contraentrega',
          descripcion: 'Pagas en efectivo al recibir tu pedido', requiereComprobante: false),
      ];
    }
    return const [];
  }

  _OpcionPago? get _opcionPagoSel {
    for (final o in _opcionesPago) { if (o.id == _metodoPagoId) return o; }
    return null;
  }

  // Nequi, Llave Bancolombia o cualquier otro método dinámico exigen
  // comprobante; las 2 opciones fijas (recogida y "efectivo contraentrega")
  // se pagan contraentrega, sin nada que subir.
  bool get _requiereComprobante => _opcionPagoSel?.requiereComprobante ?? false;

  // Único punto donde se traduce la opción elegida al valor real que el
  // backend valida (METODOS_PAGO_VALIDOS: 'efectivo'/'nequi'/
  // 'transferencia') — mismo criterio que pagoBackend en Landing.jsx:
  // CUALQUIER método dinámico manda 'transferencia' (el backend no lo
  // distingue de otro más allá de "necesita comprobante"); las 2 opciones
  // fijas mandan 'efectivo'.
  String get _pagoBackend =>
    (_metodoPagoId == 'pagar_local' || _metodoPagoId == 'efectivo_domicilio') ? 'efectivo' : 'transferencia';

  // ── Cobertura de domicilio por dirección ───────────────────────
  // Igual que la web (PasarelaPago en Landing.jsx): "A domicilio" ya no se
  // habilita/deshabilita según un dato fijo del perfil (el registro ya no
  // pide comuna) — se valida la DIRECCIÓN que el cliente escribe en el
  // paso 2, contra el mismo servicio de geocodificación que usa la web
  // (POST /pedidos/verificar-cobertura). Estados:
  //   idle     — todavía no hay dirección válida que verificar.
  //   checking — verificando.
  //   ok       — cubierta (o no se pudo geocodificar, que tampoco es un
  //              rechazo firme — ver AppState.verificarCobertura; si pasa,
  //              se resuelve confirmando el local más cerca al momento de
  //              confirmar el pedido, no acá).
  //   fuera    — rechazo firme, bloquea "Continuar".
  //   error    — no se pudo verificar (servicio caído); se deja continuar,
  //              el backend la revisa de nuevo al crear el pedido.
  String  _cobertura = 'idle';
  // true cuando _cobertura=='ok' vino de 'no_geocodificada' — se avisa sin
  // bloquear, y ese es el momento en que el backend puede terminar
  // pidiendo confirmar el local más cercano (ver _confirmar).
  bool    _coberturaSinGeocodificar = false;
  Timer?  _coberturaDebounce;
  bool    _direccionTocada = false;
  // Lo que el BACKEND resolvió de la dirección: cómo quedó ubicada, en qué
  // comuna y qué sede la atiende. Antes se descartaba, y por eso el cliente
  // no tenía forma de notar que escribió una dirección y el sistema
  // entendió otra — que es justo lo que pide "garantizar que la dirección
  // mostrada corresponda a la ingresada".
  CoberturaDireccion? _coberturaDetalle;

  // Mismo mínimo que la web (direccionValida = length >= 8).
  bool get _direccionValida => _dirCtrl.text.trim().length >= 8;

  void _onDireccionChanged(String _) {
    _coberturaDebounce?.cancel();
    if (!_direccionValida) {
      setState(() { _cobertura = 'idle'; _coberturaSinGeocodificar = false; _coberturaDetalle = null; });
      return;
    }
    setState(() { _cobertura = 'checking'; _coberturaDetalle = null; });
    // Mismo debounce que la web (700ms) — no dispara una verificación por
    // cada tecla mientras el cliente todavía está escribiendo.
    _coberturaDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      try {
        final r = await AppState.instance.verificarCobertura(_dirCtrl.text.trim());
        if (!mounted) return;
        // requiereSeleccionManual cubre ahora DOS motivos: la dirección no
        // se pudo ubicar ('no_geocodificada') y el servicio de mapas no
        // contestó ('servicio_no_disponible', que el backend dejó de
        // devolver como 502 seco). Los dos se resuelven igual: se deja
        // continuar y al confirmar se pide elegir el local más cercano.
        final sinGeocodificar = r.requiereSeleccionManual;
        setState(() {
          _cobertura = (r.cubierto || sinGeocodificar) ? 'ok' : 'fuera';
          _coberturaSinGeocodificar = sinGeocodificar;
          _coberturaDetalle = r;
        });
      } catch (_) {
        if (!mounted) return;
        // Falla abierta: si el servicio de geocodificación no responde, no
        // se bloquea al cliente — igual que la web.
        setState(() { _cobertura = 'error'; _coberturaSinGeocodificar = false; _coberturaDetalle = null; });
      }
    });
  }

  @override void dispose() {
    _coberturaDebounce?.cancel();
    // ML Kit mantiene recursos NATIVOS abiertos (un modelo cargado en
    // memoria del lado de Android/iOS). Sin cerrarlo, cada paso por el
    // checkout deja uno colgado y la app va creciendo en memoria hasta que
    // el sistema la mata — un problema que solo se nota en el APK, no en
    // pruebas cortas.
    OcrService.instance.liberar();
    _dirCtrl.dispose(); _notasCtrl.dispose(); _metodoPagoLocalCtrl.dispose();
    super.dispose();
  }

  // ── Elegir el comprobante (galería o cámara) + leerlo con OCR ─────
  // El OCR NO valida nada acá: solo extrae el texto para que el backend
  // pueda hacerlo. Si falla, el pedido se crea igual y queda en revisión
  // manual — un OCR imperfecto no puede impedir que alguien pague.
  Future<void> _seleccionarComprobante({ImageSource origen = ImageSource.gallery}) async {
    setState(() { _cargandoComprobante = true; _errorComprobante = null; });
    try {
      // imageQuality 85 (antes 70): el OCR necesita leer cifras pequeñas y
      // comprimir de más emborrona justo los dígitos del monto, que es lo
      // único que de verdad importa del comprobante.
      final archivo = await ImagePicker().pickImage(source: origen, imageQuality: 85);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _comprobanteBytes = bytes;
        _comprobanteTexto = null;
        _ocrEstado = null;
        _leyendoComprobante = true;
      });

      final resultado = await OcrService.instance.leerTexto(archivo.path);
      if (!mounted) return;
      setState(() {
        _comprobanteTexto = resultado.texto;
        _ocrEstado = resultado.estado;
        _leyendoComprobante = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _leyendoComprobante = false; _ocrEstado = 'error'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $e'), backgroundColor: C.red));
    } finally {
      if (mounted) setState(() => _cargandoComprobante = false);
    }
  }

  // Volver a elegir otro comprobante tras un rechazo — el requisito pide
  // explícitamente poder recargar otro cuando la validación falla.
  void _quitarComprobante() => setState(() {
    _comprobanteBytes = null;
    _comprobanteTexto = null;
    _ocrEstado = null;
    _errorComprobante = null;
  });

  // Elegir entre cámara y galería. Un comprobante impreso (recibo de
  // datáfono, por ejemplo) se fotografía; uno de la app del banco es una
  // captura que ya está en la galería. Antes solo existía galería.
  Future<void> _elegirOrigenComprobante() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined, color: C.green),
          title: Text('Elegir de la galería', style: TextStyle(color: C.text)),
          subtitle: Text('Captura de pantalla del pago', style: TextStyle(fontSize: 12, color: C.textMut)),
          onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined, color: C.green),
          title: Text('Tomar una foto', style: TextStyle(color: C.text)),
          subtitle: Text('Recibo impreso o pantalla de otro celular', style: TextStyle(fontSize: 12, color: C.textMut)),
          onTap: () => Navigator.pop(context, ImageSource.camera)),
        const SizedBox(height: 8),
      ])));
    if (origen != null) await _seleccionarComprobante(origen: origen);
  }

  // Cuando el geocodificador no pudo ubicar la dirección (POST /pedidos
  // responde 409 + requiereSeleccionManual — común en comuna 8/9, ver
  // AppState.verificarCobertura), el backend pide confirmar a mano cuál de
  // los 2 locales de referencia le queda más cerca al cliente, en vez de
  // rechazar el pedido. Devuelve el nombre elegido, o null si canceló.
  Future<String?> _elegirLocalMasCercano() => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: C.card,
      title: const Text('¿Cuál local te queda más cerca?'),
      content: Text(
        'No pudimos ubicar tu dirección automáticamente en el mapa. Elige el local más cercano para que tu domicilio se asigne ahí.',
        style: TextStyle(fontSize: 13, color: C.textSec)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        for (final local in AppState.localesReferenciaCobertura)
          TextButton(onPressed: () => Navigator.pop(context, local),
            child: Text(local, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700))),
      ]));

  Future<void> _confirmar({String? zonaManual}) async {
    if (_requiereComprobante && _comprobanteBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Debes subir el comprobante de pago antes de continuar'),
        backgroundColor: C.red));
      return;
    }
    setState(() { _loading = true; _errorComprobante = null; });
    try {
      final comprobanteBase64 = _requiereComprobante
          ? 'data:image/jpeg;base64,${base64Encode(_comprobanteBytes!)}'
          : null;
      final esDomicilio = _tipoEntrega == 'domicilio';
      final dirAlterna = _dirCtrl.text.trim();
      final pedido = await AppState.instance.crearPedido(
        // El texto leído por el OCR viaja con la imagen para que el BACKEND
        // valide el valor contra el total real del pedido. La app no decide
        // si el comprobante sirve: si no sirve, la llamada de abajo falla y
        // el pedido NO se crea (ese es el "solo continuar cuando el backend
        // confirme" del requisito).
        comprobanteTexto: _requiereComprobante ? _comprobanteTexto : null,
        // _pagoBackend ya traduce la opción elegida al id real que el
        // backend valida ('efectivo'/'transferencia' — ver METODOS_PAGO_
        // VALIDOS en sicaber-backend/src/routes/index.js).
        metodoPago: _pagoBackend,
        notas: _notasCtrl.text.isNotEmpty ? _notasCtrl.text : null,
        // Para domicilio, el paso 2 ya exige y valida la dirección (mínimo
        // 8 caracteres + cobertura) antes de dejar avanzar hasta acá, así
        // que dirAlterna nunca llega vacía en ese caso.
        direccionEntrega: esDomicilio ? dirAlterna : null,
        tipoEntrega: esDomicilio ? 'domicilio' : 'local',
        localId: esDomicilio ? null : _localId,
        comprobante: comprobanteBase64,
        zonaManual: esDomicilio ? zonaManual : null,
        // Nota opcional de "¿cómo vas a pagar?" — solo aplica a recogida en
        // el local (ver AppState.crearPedido/metodo_pago_local).
        metodoPagoLocal: esDomicilio ? null
            : (_metodoPagoLocalCtrl.text.trim().isNotEmpty ? _metodoPagoLocalCtrl.text.trim() : null));
      if (!mounted) return;
      // Navegación que NO deja al cliente atrapado (requisito 8): se apila
      // el detalle SOBRE la pestaña de pedidos, así el botón "Regresar" del
      // detalle y el gesto de atrás del sistema llevan a "Mis pedidos" en
      // vez de a un callejón sin salida. Antes era un context.go directo,
      // que REEMPLAZA toda la pila: el detalle quedaba sin nada debajo, sin
      // barra inferior y sin ninguna forma de volver.
      context.go('/pedidos');
      context.push('/pedidos/${pedido.id}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(pedido.comprobanteVerificado
          ? '¡Pedido confirmado! Comprobante verificado ✓'
          : '¡Pedido confirmado! ✓'),
        backgroundColor: C.green));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.statusCode == 409 && e.data?['requiereSeleccionManual'] == true) {
        final elegido = await _elegirLocalMasCercano();
        if (!mounted || elegido == null) return;
        await _confirmar(zonaManual: elegido);
        return;
      }
      // ── El backend rechazó el COMPROBANTE ────────────────────────
      // Dos casos, los dos con la misma salida para el cliente: el pedido
      // NO se creó y hay que subir otro comprobante. El mensaje se deja
      // fijo junto al recuadro de la imagen (no solo un SnackBar que se va
      // en 4 segundos) y se limpia la imagen para que el único camino sea
      // elegir otra — que es lo que pide el requisito.
      final esRechazoDeComprobante = e.motivo == 'valor_no_coincide'
          || e.motivo == 'comprobante_repetido'
          || e.motivo == 'referencia_repetida';
      if (esRechazoDeComprobante) {
        setState(() {
          _errorComprobante = e.message;
          _comprobanteBytes = null;
          _comprobanteTexto = null;
          _ocrEstado = null;
          _step = 3; // se queda en el paso del pago, con todo lo demás intacto
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: C.red,
          duration: const Duration(seconds: 7)));
        return;
      }
      if (e.statusCode == 400) {
        // Mensaje REAL del backend (ej. "fuera de comuna 8/9"), con la
        // alternativa de recoger en el local sin perder el resto del
        // pedido ya armado (carrito, método de pago, comprobante).
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: C.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Recoger en el local', textColor: Colors.white,
            onPressed: () => setState(() { _tipoEntrega = 'local'; _step = 1; }))));
        return;
      }
      // Fallo de RED (sin internet, timeout): el pedido pudo no haberse
      // creado, así que se ofrece reintentar en vez de dejar al cliente sin
      // saber qué pasó con su pago.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message), backgroundColor: C.red,
        duration: const Duration(seconds: 6),
        action: e.esDeRed
          ? SnackBarAction(label: 'Reintentar', textColor: Colors.white,
              onPressed: () => _confirmar(zonaManual: zonaManual))
          : null));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo enviar el pedido: $e'), backgroundColor: C.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Un solo lugar para "retroceder un paso", reutilizado tanto por los
  // botones "← Atrás" del propio formulario como por el back físico/AppBar
  // interceptado abajo — así los dos caminos quedan siempre de acuerdo en
  // a qué paso se vuelve (paso 3 de domicilio vuelve a 2, todo lo demás a 1).
  void _retrocederPaso() =>
    setState(() => _step = (_step == 3 && _tipoEntrega == 'domicilio') ? 2 : 1);

  @override Widget build(BuildContext context) => PopScope(
    // Antes, el botón físico "atrás" de Android (y el que el AppBar agrega
    // solo porque esta pantalla se abrió con push) cerraban de un salto
    // el checkout completo —perdiendo dirección, método de pago y
    // comprobante ya cargados— porque nada interceptaba el pop. Mientras
    // _step > 1 se bloquea el pop acá y en su lugar se retrocede un paso,
    // igual que ya hacían los botones "← Atrás"; en el paso 1 sí se deja
    // salir del checkout normalmente.
    canPop: _step == 1,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      _retrocederPaso();
    },
    child: Scaffold(backgroundColor: C.bg,
      appBar: AppBar(title: const Text('Confirmar pedido'), backgroundColor: C.surface),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PasoIndicador(step: _step, total: _tipoEntrega == 'domicilio' ? 3 : 2),
        const SizedBox(height: 20),
        if (_step == 1) _pasoEntrega()
        else if (_step == 2) _pasoDireccion()
        else _pasoPago(),
      ])),
    ),
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
      // Igual que la web: acá ya no se bloquea por comuna del perfil (el
      // registro no la pide) — la cobertura se valida con la dirección real
      // en el paso siguiente, no antes de que el cliente la escriba.
      _OpcionEntrega(
        icon: Icons.delivery_dining_outlined, titulo: 'A domicilio',
        // El alcance del domicilio se dice AQUÍ, en el punto de decisión, y no
        // recién en el paso 2 (igual que la web): el cliente lo lee antes de
        // elegir, y la recogida justo debajo aclara que es para todos.
        subtitulo: 'Te lo llevamos · comunas 8 y 9 de Medellín',
        seleccionado: _tipoEntrega == 'domicilio', habilitado: true,
        onTap: () => setState(() {
          _tipoEntrega = 'domicilio';
          // El método fijo de recogida ('pagar_local') no existe para
          // domicilio — se limpia para que el cliente tenga que elegir uno
          // de los que sí aplican acá (mismo criterio que el effect de
          // limpieza en Landing.jsx: si el método ya elegido dejó de estar
          // en la lista vigente, se descarta).
          if (_metodoPagoId != null && !_opcionesPago.any((o) => o.id == _metodoPagoId)) {
            _metodoPagoId = null;
          }
          _comprobanteBytes = null;
        })),
      const SizedBox(height: 10),
      _OpcionEntrega(
        icon: Icons.storefront_outlined, titulo: 'Recoger en el local',
        subtitulo: 'Recoge tu pedido en tienda · disponible para todos',
        seleccionado: _tipoEntrega == 'local', habilitado: true,
        onTap: () => setState(() {
          _tipoEntrega = 'local';
          // Única opción posible para recogida — se autoselecciona, sin
          // esperar un tap del cliente (no tiene sentido "elegir" cuando no
          // hay más de una alternativa real, mismo criterio que el local
          // único de _selectorLocales más abajo).
          _metodoPagoId = 'pagar_local';
          _comprobanteBytes = null;
        })),
      if (_tipoEntrega == 'local') ...[
        const SizedBox(height: 12),
        _selectorLocales(),
      ],
      // Se quitó el recuadro azul "Por el momento ... solo cubre la comuna 8 y
      // 9": repetía lo que ahora dicen los subtítulos de arriba y, en
      // singular ("la comuna 8 y 9"), no coincidía con el texto de la web.
      const SizedBox(height: 24),
      ElevatedButton(
        // La limpieza/autoselección de _metodoPagoId ya ocurrió arriba, en
        // el onTap de cada opción — acá solo se avanza de paso.
        onPressed: !entregaValida ? null : () => setState(() {
          _step = _tipoEntrega == 'domicilio' ? 2 : 3;
        }),
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

  // ── Sección de método de pago (paso 3) ──────────────────────────
  // Mismo criterio que _selectorLocales de arriba: si solo hay UNA opción
  // posible (recogida, siempre: solo existe "Pagar al llegar al local"),
  // se muestra como aviso ya confirmado en vez de una tarjeta "para
  // elegir" — no tiene sentido pedirle al cliente que elija entre una sola
  // alternativa real.
  Widget _seccionMetodoPago() {
    if (_cargandoMetodosPago) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: C.green))));
    }
    final opciones = _opcionesPago;
    if (opciones.isEmpty) {
      // Solo puede pasar en domicilio si el admin desactivó todos los
      // métodos de "Métodos de pago" (recogida siempre tiene su opción
      // fija) — se avisa en vez de dejar la pantalla en blanco sin
      // explicar por qué no hay nada para elegir.
      return Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.red.withOpacity(0.3))),
        child: Text('No hay métodos de pago disponibles en este momento. Intenta de nuevo más tarde.',
          style: TextStyle(fontSize: 12, color: C.red)));
    }
    if (opciones.length == 1) {
      final unica = opciones.first;
      return Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.green.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.storefront, color: C.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(unica.label,
            style: TextStyle(fontSize: 13, color: C.text, fontWeight: FontWeight.w600))),
        ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final opcion in opciones) ...[
        _OpcionEntrega(
          icon: opcion.requiereComprobante ? Icons.qr_code_2_outlined : Icons.payments_outlined,
          titulo: opcion.label,
          subtitulo: opcion.descripcion ?? (opcion.requiereComprobante ? 'Requiere comprobante' : 'Sin comprobante'),
          seleccionado: _metodoPagoId == opcion.id, habilitado: true,
          onTap: () => setState(() {
            _metodoPagoId = opcion.id;
            // Cambiar de método invalida cualquier comprobante ya subido
            // para el método anterior — evita mandar la imagen equivocada
            // pegada a un método distinto del que en verdad se pagó.
            _comprobanteBytes = null;
          })),
        if (opcion != opciones.last) const SizedBox(height: 10),
      ],
    ]);
  }

  // ── Detalle del método elegido: descripción/"llave" + QR ampliable ──
  // Mismo contenido que Landing.jsx muestra tras elegir un método (num/
  // titular/urlQr), pero el QR sale más grande acá (220px vs 180px en la
  // web) y SÍ se puede ampliar — la web no lo permite, y un QR chico es
  // literalmente imposible de escanear con la cámara de un celular a la
  // distancia normal a la que se sostiene el teléfono.
  Widget _detallePago(_OpcionPago opcion) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    width: double.infinity,
    decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (opcion.descripcion != null) ...[
        Text('Datos para pagar con ${opcion.label}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.textSec)),
        const SizedBox(height: 6),
        Text(opcion.descripcion!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
      ],
      if (opcion.urlQr != null) ...[
        if (opcion.descripcion != null) const SizedBox(height: 14),
        Center(child: GestureDetector(
          onTap: () => _ampliarQr(opcion),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: Image.network(opcion.urlQr!, width: 220, height: 220, fit: BoxFit.contain,
                // El QR vive en Cloudinary (mismo mecanismo que un
                // comprobante de compra) — si la URL falla (borrada, sin
                // red), un ícono roto es más claro que dejar el hueco en
                // blanco sin ninguna pista de qué pasó.
                errorBuilder: (_, __, ___) => Container(width: 220, height: 220,
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.broken_image_outlined, color: C.textMut, size: 32)),
                loadingBuilder: (context, child, progress) => progress == null ? child
                  : SizedBox(width: 220, height: 220,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.green))))),
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.zoom_in, size: 14, color: C.green),
              const SizedBox(width: 4),
              Text('Toca para ampliar el código QR',
                style: TextStyle(fontSize: 12, color: C.green, fontWeight: FontWeight.w600)),
            ]),
          ]),
        )),
      ],
    ]));

  // Pantalla completa + pellizcar-para-zoom (InteractiveViewer) — "cuidado
  // con" explícito del pedido: un QR de 220px ya es más grande que el de
  // la web, pero en una pantalla realmente chica puede seguir sin ser
  // suficiente, así que además se puede ampliar más y hacer zoom con los
  // dedos antes de escanear.
  void _ampliarQr(_OpcionPago opcion) => showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(minScale: 1, maxScale: 4,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.network(opcion.urlQr!, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 64, color: Colors.black38)),
              const SizedBox(height: 12),
              Text('QR para pagar con ${opcion.label}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
            ]),
          ),
        ),
      ),
    ));

  // ── Paso 2: dirección de entrega + cobertura (solo domicilio) ──
  // Igual que la web (PasarelaPago en Landing.jsx): la dirección ya es
  // OBLIGATORIA acá (antes era opcional porque el registro guardaba una
  // dirección de respaldo; ya no la pide, así que este es el único punto
  // donde se captura) y se verifica en vivo contra el servicio de
  // cobertura mientras el cliente escribe.
  Widget _pasoDireccion() {
    final puedeContinuar = _direccionValida && _cobertura != 'checking' && _cobertura != 'fuera';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Mismo texto que el banner del paso 2 de la web. Informativo: dice el
      // alcance Y la salida (recoger en el local), no solo la restricción.
      const _AvisoDomicilio(child: Text.rich(TextSpan(children: [
        TextSpan(text: 'Los domicilios llegan a las '),
        TextSpan(text: 'comunas 8 y 9 de Medellín', style: TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: '. Si estás en otra zona, igual puedes '),
        TextSpan(text: 'recoger tu pedido en el local', style: TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: '.'),
      ]))),
      const SizedBox(height: 20),
      // Flexible en la etiqueta: en pantallas angostas (320/360px) el texto
      // completo + el " *" en un Row sin protección desbordaba (RenderFlex
      // overflowed) — detectado con test/checkout_pago_responsive_test.dart.
      Row(children: [
        Flexible(child: Text('Dirección de entrega',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text))),
        const Text(' *', style: TextStyle(color: C.red, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      Text('Escribe la dirección exacta donde quieres recibir tu pedido. Incluye barrio, apartamento o punto de referencia si aplica.',
        style: TextStyle(fontSize: 12, color: C.textSec)),
      const SizedBox(height: 10),
      TextField(controller: _dirCtrl, style: TextStyle(color: C.text),
        onChanged: _onDireccionChanged,
        onTapOutside: (_) => setState(() => _direccionTocada = true),
        decoration: InputDecoration(hintText: 'Ej: Calle 45 #23-10, apto 301, Villa Hermosa',
          prefixIcon: Icon(Icons.location_on_outlined, color: C.textMut, size: 20),
          enabledBorder: (_direccionTocada && !_direccionValida) || _cobertura == 'fuera'
              ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.red))
              : null,
          focusedBorder: (_direccionTocada && !_direccionValida) || _cobertura == 'fuera'
              ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.red, width: 1.5))
              : null)),
      if (_direccionTocada && !_direccionValida) ...[
        const SizedBox(height: 6),
        Text('La dirección es obligatoria y debe tener al menos 8 caracteres.',
          style: TextStyle(fontSize: 12, color: C.red, fontWeight: FontWeight.w600)),
      ] else if (_direccionValida && _cobertura == 'checking') ...[
        const SizedBox(height: 6),
        Text('Verificando cobertura...', style: TextStyle(fontSize: 12, color: C.textMut)),
      ],
      // Solo aparece cuando el mapa SÍ ubicó la dirección y está en otra
      // comuna: el único caso que el backend rechaza en firme (POST /pedidos
      // responde 400). Antes era un bloque rojo de error; ahora, igual que en
      // la web, informa y ofrece la salida real (recoger en el local) en un
      // toque, para que no parezca que la app no sirve a quien vive fuera de
      // la zona. Lo que NO cambia: "Continuar" sigue deshabilitado mientras
      // la dirección esté fuera (puedeContinuar) y el campo conserva el
      // borde rojo — la validación es la misma, solo cambia el tono.
      if (_cobertura == 'fuera') ...[
        const SizedBox(height: 10),
        _AvisoDomicilio(
          child: const Text.rich(TextSpan(children: [
            TextSpan(text: 'Esa dirección queda fuera de las '),
            TextSpan(text: 'comunas 8 y 9 de Medellín', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ', donde llegan nuestros domicilios. Puedes escribir otra dirección o recoger tu pedido en el local.'),
          ])),
          accion: OutlinedButton(
            // Mismo efecto que el SnackBar "Recoger en el local" de
            // _confirmar (400 del backend): la recogida se elige en el paso
            // 1, así que se vuelve allá con "local" ya marcado y su único
            // método de pago autoseleccionado (como en el onTap de la opción).
            onPressed: () => setState(() {
              _tipoEntrega = 'local';
              _metodoPagoId = 'pagar_local';
              _comprobanteBytes = null;
              _step = 1;
            }),
            child: const Text('Recoger en el local →'))),
      ] else if (_cobertura == 'error') ...[
        const SizedBox(height: 6),
        Text('No se pudo verificar la dirección en este momento. Puedes continuar; se validará de nuevo al confirmar el pedido.',
          style: TextStyle(fontSize: 12, color: C.textMut)),
      ] else if (_cobertura == 'ok' && _coberturaSinGeocodificar) ...[
        const SizedBox(height: 6),
        Text(
          _coberturaDetalle?.motivo == 'servicio_no_disponible'
            ? 'El servicio de mapas no está disponible en este momento. Puedes continuar; te pediremos confirmar cuál local te queda más cerca al finalizar.'
            : 'No pudimos ubicar automáticamente esa dirección en el mapa. Puedes continuar; te pediremos confirmar cuál local te queda más cerca al finalizar.',
          style: TextStyle(fontSize: 12, color: C.textMut)),
      ] else if (_cobertura == 'ok' && _coberturaDetalle?.cubierto == true) ...[
        // ── Confirmación de QUÉ dirección entendió el sistema ──────
        // Esta tarjeta es el requisito "garantizar que la dirección
        // mostrada corresponda a la ingresada": el backend devuelve la
        // dirección ya ubicada en el mapa, su comuna y la sede asignada, y
        // hasta ahora la app lo descartaba todo. Si el geocodificador
        // entendió otra cosa, el cliente lo ve ACÁ y puede corregir antes
        // de pagar, en vez de enterarse cuando el domicilio no llega.
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.green.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.check_circle_outline, size: 16, color: C.green),
              const SizedBox(width: 6),
              Expanded(child: Text('Dirección dentro de la zona de cobertura',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text))),
            ]),
            if (_coberturaDetalle?.direccionNormalizada != null) ...[
              const SizedBox(height: 6),
              Text('La ubicamos como:', style: TextStyle(fontSize: 11, color: C.textMut)),
              Text(_coberturaDetalle!.direccionNormalizada!,
                style: TextStyle(fontSize: 12.5, color: C.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Si no corresponde a tu dirección, corrígela antes de continuar.',
                style: TextStyle(fontSize: 11, color: C.textMut)),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 2, children: [
              if (_coberturaDetalle?.comuna != null)
                Text('Comuna ${_coberturaDetalle!.comuna}',
                  style: TextStyle(fontSize: 11.5, color: C.textSec, fontWeight: FontWeight.w600)),
              if (_coberturaDetalle?.sede != null)
                Text('Te atiende: ${_coberturaDetalle!.sede}',
                  style: TextStyle(fontSize: 11.5, color: C.textSec, fontWeight: FontWeight.w600)),
            ]),
          ])),
      ],
      const SizedBox(height: 24),
      // Mismo patrón/motivo que en _pasoPago: el OutlinedButton necesita
      // ancho Y alto fijos (SizedBox) para no chocar con el minimumSize de
      // ancho infinito del tema dentro de un Row sin restricciones.
      Row(children: [
        SizedBox(width: 110, height: 44, child: OutlinedButton(
          onPressed: _retrocederPaso, child: const Text('← Atrás'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          onPressed: !puedeContinuar ? null : () {
            setState(() => _direccionTocada = true);
            if (_direccionValida && _cobertura != 'fuera') setState(() => _step = 3);
          },
          child: const Text('Continuar →'))),
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
            // Mismo desglose que el carrito — el cliente ve el IVA
            // separado también acá, justo antes de pagar, y el TOTAL es
            // idéntico al que el backend usará para validar el
            // comprobante (ver core/utils/precios.dart).
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DesgloseTotales(total: total, destacado: false)),
          ]),
        )),

      // ── Método de pago ──
      // Ya no es una lista fija en la app: para domicilio sale de
      // AppState.metodosPago (lo que el admin dejó activo en "Métodos de
      // pago", con su descripción/llave y QR); para recogida solo existe
      // "Pagar al llegar al local" — mismas 2 reglas que la web (ver
      // _opcionesPago). El detalle (llave/QR) se muestra debajo de la
      // lista, no en la propia tarjeta, para que quepa un QR grande y
      // legible sin apretar el resto de opciones.
      const SizedBox(height: 22),
      Text('Método de pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
      const SizedBox(height: 10),
      _seccionMetodoPago(),
      if (_opcionPagoSel != null && (_opcionPagoSel!.descripcion != null || _opcionPagoSel!.urlQr != null))
        _detallePago(_opcionPagoSel!),

      // ── Nota opcional de cómo va a pagar (SOLO recogida en el local) ──
      // Mismo campo metodo_pago_local que ya acepta el backend — igual que
      // la web, es un dato de cortesía para el local, nunca obligatorio ni
      // exigido por el checkout.
      if (_tipoEntrega == 'local') ...[
        const SizedBox(height: 16),
        Text('¿Cómo vas a pagar? (opcional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text)),
        const SizedBox(height: 6),
        TextField(controller: _metodoPagoLocalCtrl, maxLength: 100, style: TextStyle(color: C.text),
          decoration: const InputDecoration(hintText: 'Ej: efectivo exacto, tarjeta...', counterText: '')),
        Text('Si lo dejas vacío, el local te preguntará al recoger tu pedido.',
          style: TextStyle(fontSize: 12, color: C.textMut)),
      ],

      // ── Comprobante de pago (solo métodos dinámicos: Nequi, Llave
      // Bancolombia, o cualquier otro que cargue el admin) — se sube
      // SIEMPRE dentro de la app, no hay alternativa por WhatsApp. Si el
      // cliente tiene problemas subiéndolo, usa "Contáctanos" (ver
      // ProfileScreen) como canal de soporte general, no para comprobantes.
      // Las 2 opciones fijas (recogida, "efectivo contraentrega") ya
      // explican que no hace falta comprobante en su propia tarjeta/
      // detalle — no hace falta repetirlo acá con un cartel aparte.
      if (_requiereComprobante) ...[
        const SizedBox(height: 22),
        Text('Comprobante de pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 4),
        Text('Sube una foto o captura de pantalla del pago (${_opcionPagoSel?.label ?? ''}). '
             'Asegúrate de que se vea el VALOR completo y sin recortar.',
          style: TextStyle(fontSize: 12, color: C.textSec)),
        // Rechazo previo del backend (valor que no coincide, o comprobante
        // ya usado en otro pedido): se muestra fijo acá, no solo en un
        // SnackBar que desaparece, y con la imagen ya limpiada para que la
        // única acción posible sea subir otra.
        if (_errorComprobante != null) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.red.withOpacity(0.35))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, size: 18, color: C.red),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('El comprobante no fue aceptado',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.red)),
                const SizedBox(height: 2),
                Text(_errorComprobante!, style: const TextStyle(fontSize: 12.5, color: C.red)),
                const SizedBox(height: 4),
                Text('Sube el comprobante correcto para continuar. Tu pedido no se ha creado.',
                  style: TextStyle(fontSize: 11.5, color: C.textSec)),
              ])),
            ])),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cargandoComprobante ? null : _elegirOrigenComprobante,
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
        // ── Estado de la lectura (OCR) ────────────────────────────
        // Informativo, NUNCA bloqueante: aunque el OCR no lea nada, el
        // cliente puede continuar y el backend deja el comprobante en
        // revisión de un cajero. Lo que sí se le dice es qué va a pasar.
        if (_comprobanteBytes != null) ...[
          const SizedBox(height: 8),
          if (_leyendoComprobante)
            Row(children: [
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: C.green)),
              const SizedBox(width: 8),
              Text('Leyendo el comprobante...', style: TextStyle(fontSize: 12, color: C.textSec)),
            ])
          else if (_ocrEstado == 'ok')
            Row(children: [
              const Icon(Icons.document_scanner_outlined, size: 15, color: C.green),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Comprobante leído. Verificaremos el valor al confirmar el pedido.',
                style: TextStyle(fontSize: 12, color: C.textSec))),
            ])
          else if (_ocrEstado != null)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 15, color: C.gold),
              const SizedBox(width: 6),
              Expanded(child: Text(
                _ocrEstado == 'sin_texto'
                  ? 'No pudimos leer el texto de la imagen. Puedes continuar: un cajero revisará el comprobante.'
                  : _ocrEstado == 'no_soportado'
                    ? 'La lectura automática no está disponible en este dispositivo. Un cajero revisará el comprobante.'
                    : 'No pudimos leer el comprobante automáticamente. Puedes continuar: un cajero lo revisará.',
                style: TextStyle(fontSize: 12, color: C.textSec))),
            ]),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _cargandoComprobante ? null : _elegirOrigenComprobante,
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Cambiar comprobante'),
            style: TextButton.styleFrom(
              foregroundColor: C.green, padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
        ],
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
          onPressed: _retrocederPaso, child: const Text('← Atrás'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(
          // Se espera a que termine la lectura del comprobante antes de
          // dejar confirmar: si no, el pedido saldría sin el texto del OCR
          // y el backend no tendría con qué validar el valor.
          onPressed: (_loading || _leyendoComprobante || items.isEmpty || _metodoPagoId == null
              || (_requiereComprobante && _comprobanteBytes == null)) ? null : _confirmar,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Confirmar pedido ✓'))),
      ]),
      if (_metodoPagoId == null) ...[
        const SizedBox(height: 8),
        Center(child: Text('Elige un método de pago para continuar',
          style: TextStyle(fontSize: 12, color: C.textMut))),
      ] else if (_requiereComprobante && _comprobanteBytes == null) ...[
        const SizedBox(height: 8),
        Center(child: Text('Sube el comprobante de pago para continuar',
          style: TextStyle(fontSize: 12, color: C.textMut))),
      ] else if (_leyendoComprobante) ...[
        const SizedBox(height: 8),
        Center(child: Text('Espera un momento: estamos leyendo tu comprobante',
          style: TextStyle(fontSize: 12, color: C.textMut))),
      ] else if (_requiereComprobante) ...[
        const SizedBox(height: 8),
        Center(child: Text('Al confirmar verificaremos que el comprobante corresponda a este pedido.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: C.textMut))),
      ],
      const SizedBox(height: 40),
    ]);
  }
}

// ── Una opción de pago seleccionable (fija o de AppState.metodosPago) ──
// Objeto de solo UI: unifica las 2 opciones fijas ("pagar al llegar al
// local", "efectivo contraentrega") con los métodos dinámicos que trae el
// admin, para que el resto del checkout no tenga que preguntar "¿es fijo o
// viene de la API?" en cada lugar donde se usa — ver _ChkState._opcionesPago.
class _OpcionPago {
  final String  id;
  final String  label;
  final String? descripcion;
  final String? urlQr;
  final bool    requiereComprobante;
  const _OpcionPago({required this.id, required this.label, this.descripcion, this.urlQr, required this.requiereComprobante});
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

// Aviso informativo de cobertura del checkout: caja ámbar con 📍, como el
// "pay-coverage-alert" de la web (mismo color de advertencia suave, no rojo).
// `accion` es opcional (el botón "Recoger en el local" del caso fuera de zona).
class _AvisoDomicilio extends StatelessWidget {
  final Widget child;
  final Widget? accion;
  const _AvisoDomicilio({required this.child, this.accion});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: C.gold.withOpacity(0.3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📍', style: TextStyle(fontSize: 16)),
      const SizedBox(width: 10),
      // Expanded: el texto es largo y la pantalla puede ser de 320px.
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DefaultTextStyle(
          style: TextStyle(fontSize: 13, color: C.text, height: 1.4),
          child: child),
        if (accion != null) ...[const SizedBox(height: 10), accion!],
      ])),
    ]));
}
