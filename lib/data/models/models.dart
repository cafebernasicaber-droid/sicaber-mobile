import '../services/api_service.dart' show parseNum;

// ── PRODUCTO ──────────────────────────────────────────────────
class Producto {
  final int    id;
  final String nombre, descripcion, categoria;
  final double precio, descuento;
  final String? imagen;
  final bool   estado;

  const Producto({
    required this.id, required this.nombre, required this.descripcion,
    required this.categoria, required this.precio, this.descuento = 0,
    this.imagen, this.estado = true,
  });

  double get precioFinal => descuento > 0 ? precio * (1 - descuento / 100) : precio;
  bool   get tieneDescuento => descuento > 0;
}

// ── TOPPING ───────────────────────────────────────────────────
class Topping {
  final int    id;
  final String nombre, descripcion;
  final double precio;
  final bool   gratuito;
  // Productos a los que aplica este topping (columna productos_ids en el
  // backend). Vacío = aplica a cualquier producto — misma regla que usa la
  // web (ver sicaber-.../src/shared/utils/toppings.js → toppingsParaProducto).
  final List<int> productosIds;
  const Topping({required this.id, required this.nombre, this.descripcion = '', this.precio = 0,
    this.gratuito = false, this.productosIds = const []});
}

// ── ADICION ───────────────────────────────────────────────────
// Universales: aplican igual a cualquier producto del menú (la tabla
// "adiciones" del backend no tiene columna de categoría ni producto_id).
class Adicion {
  final int    id;
  final String nombre;
  final double precio;
  final bool   estado;
  const Adicion({required this.id, required this.nombre, required this.precio, this.estado = true});
}

// ── COMBO ─────────────────────────────────────────────────────
class Combo {
  final int    id;
  final String nombre;
  final double precio;
  final String descripcion;
  final String? imagen;
  final bool   estado;
  final List<Map<String, dynamic>> items; // viene del campo jsonb "items"
  // Vigencia del combo (igual que la web: Landing.jsx/CombosPage.jsx solo
  // muestran estas fechas cuando el combo las tiene definidas — un combo
  // sin fecha de inicio/fin no tiene límite de tiempo).
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  const Combo({
    required this.id, required this.nombre, required this.precio,
    this.descripcion = '', this.imagen, this.estado = true,
    this.items = const [], this.fechaInicio, this.fechaFin,
  });

  // El "ahorro" se calcula sumando precioOriginal de cada item del combo (si viene informado)
  double get totalOriginal =>
    items.fold(0.0, (s, it) => s + parseNum(it['precioOriginal'] ?? it['precio'] ?? 0));

  double get ahorro => totalOriginal > precio ? totalOriginal - precio : 0;

  // true si hoy cae dentro de [fechaInicio, fechaFin] — igual que
  // Promocion.vigente. Un combo sin ninguna de las dos fechas está
  // siempre vigente (no tiene límite de tiempo).
  bool get vigente {
    final now = DateTime.now();
    if (fechaInicio != null && now.isBefore(fechaInicio!)) return false;
    if (fechaFin != null && now.isAfter(fechaFin!)) return false;
    return true;
  }

  // Compatibilidad con código viejo que usaba productosIncluidos/adicionesIncluidas
  List<Map<String, dynamic>> get productosIncluidos => items;
  List<Map<String, dynamic>> get adicionesIncluidas => const [];
}

// ── PROMOCIÓN (producto con descuento activo) ───────────────────
class Promocion {
  final Producto producto;
  final DateTime? inicio;
  final DateTime? fin;

  const Promocion({required this.producto, this.inicio, this.fin});

  double get porcentaje => producto.descuento;
  double get precioFinal => producto.precioFinal;
  double get ahorro => producto.precio - producto.precioFinal;

  bool get vigente {
    final now = DateTime.now();
    if (inicio != null && now.isBefore(inicio!)) return false;
    if (fin != null && now.isAfter(fin!)) return false;
    return true;
  }
}

// ── CATEGORIA ─────────────────────────────────────────────────
class Categoria {
  final int    id;
  final String nombre, descripcion;
  const Categoria({required this.id, required this.nombre, this.descripcion = ''});
}

// ── LOCAL (punto físico para "Recoger en el local") ─────────────
// GET /api/locales (pública, ver sicaber-backend/src/routes/index.js) ya
// solo devuelve locales activos — no hace falta filtrar nada del lado del
// cliente.
class Local {
  final int    id;
  final String nombre;
  final String? direccion;
  const Local({required this.id, required this.nombre, this.direccion});
}

// ── MÉTODO DE PAGO (configurado desde el admin) ─────────────────
// GET /api/metodos-pago (pública, solo activo=true — ver
// sicaber-backend/src/routes/index.js, tabla `metodos_pago`) — la lista de
// métodos con QR que el cliente puede elegir para pagar A DOMICILIO. Ya no
// es una lista fija en la app: el admin la administra desde "Métodos de
// pago" (nombre, descripción/"llave", y opcionalmente un QR). "Efectivo
// contraentrega" (domicilio) y "Pagar al llegar al local" (recogida) NO
// son filas de esta tabla — son opciones fijas que arma el checkout, igual
// que en la web (ver METODOS/PAGAR_LOCAL_ID en Landing.jsx).
class MetodoPago {
  final int     id;
  final String  nombre;
  final String? descripcion;
  final String? urlQr;
  const MetodoPago({required this.id, required this.nombre, this.descripcion, this.urlQr});
}

// ── CART ITEM ─────────────────────────────────────────────────
class CartItem {
  final String   cartKey;
  final Producto producto;
  int            cantidad;
  final List<Topping> toppings;
  final List<Adicion> adiciones;
  // Solo distinto de null cuando este ítem es un combo agregado completo
  // (ver AppState.addComboToCart) — `producto` es entonces un Producto
  // sintético (id negativo, solo para mostrarlo con el resto del carrito),
  // y este es el id REAL del combo en la tabla `combos`. Al armar el POST
  // /pedidos, AppState.crearPedido usa esto para mandar 'id': 'combo-<id>'
  // en vez del id numérico — mismo formato que ya usa la web para vender
  // combos (ver addToCart en Landing.jsx).
  final int? comboId;

  // Posición EXACTA de esta línea dentro de `pedidos.items` en el backend.
  // Solo viene informada en los ítems de un pedido ya guardado (ver
  // PedidoFromJson); en el carrito es null.
  //
  // Es lo que hace que una devolución se registre bien. El backend resuelve
  // qué se devuelve por `item_index` o por `producto_id`, y la app mandaba
  // producto_id — que falla en dos casos reales:
  //   • un COMBO no tiene id de producto (en el pedido se guarda como
  //     "combo-5"), así que producto_id llegaba en 0 y el backend
  //     respondía que ese producto no está en el pedido;
  //   • el MISMO producto pedido dos veces con toppings distintos son dos
  //     líneas, y producto_id no distingue cuál de las dos se devuelve.
  final int? itemIndex;

  // Unidades de esta línea que ya fueron devueltas y aprobadas (lo calcula
  // el backend en conEstadoDevolucion y viaja en cada producto del pedido).
  // Sirve para no dejar pedir de nuevo lo que ya se devolvió.
  final int cantidadDevuelta;

  CartItem({
    required this.cartKey, required this.producto, this.cantidad = 1,
    this.toppings = const [], this.adiciones = const [], this.comboId,
    this.itemIndex, this.cantidadDevuelta = 0,
  });

  /// Unidades que todavía se pueden devolver de esta línea.
  /// Sin `clamp` a propósito: su tipo estático depende de una regla
  /// especial del analizador y acá hace falta un int llano y seguro.
  int get cantidadDevolvible {
    final restante = cantidad - cantidadDevuelta;
    if (restante < 0) return 0;
    if (restante > cantidad) return cantidad;
    return restante;
  }
  bool get totalmenteDevuelto => cantidadDevolvible == 0 && cantidad > 0;

  double get extraTotal =>
    toppings.where((t) => !t.gratuito).fold(0.0, (s, t) => s + t.precio) +
    adiciones.fold(0.0, (s, a) => s + a.precio);

  double get precioUnitario => producto.precioFinal + extraTotal;
  double get subtotal       => precioUnitario * cantidad;

  List<String> get nombresExtras => [
    ...toppings.map((t) => t.nombre),
    ...adiciones.map((a) => a.nombre),
  ];
}

// ── PEDIDO ────────────────────────────────────────────────────
class Pedido {
  final String           id, estado, fecha, metodoPago;
  final List<CartItem>   items;
  final double           total;
  final String?          notas, direccionEntrega;
  final String           tipoEntrega; // 'local' | 'domicilio'

  // Datos para sincronizar con el backend (PostgreSQL): el id numérico
  // real de la fila en `pedidos`, y si trae comprobante de transferencia
  // adjunto (para los sub-estados del paso "Verificando pago").
  final int?             backendId;
  final bool             tieneComprobante;
  final String?          comprobanteImgUrl;

  // ── Estado del PAGO, separado del estado del pedido ──────────────
  // El backend los mantiene aparte a propósito (columna derivada
  // "estado_pago": 'pendiente_verificacion' | 'aprobado' | 'rechazado' |
  // 'pendiente'). Antes la app solo leía `estado`, así que un pago
  // rechazado y una cancelación por cualquier otro motivo se veían igual.
  final String? estadoPago;

  // Veredicto del backend sobre el comprobante (columna
  // comprobante_validacion): qué valor leyó, de qué entidad, si coincide
  // con el total. Es lo que permite mostrarle al cliente POR QUÉ su
  // comprobante quedó en revisión o fue rechazado.
  final Map<String, dynamic>? comprobanteValidacion;

  // Estado de la devolución del pedido, calculado por el backend a partir
  // de las devoluciones aprobadas: null | 'parcial' | 'total'.
  final String? estadoDevolucion;

  const Pedido({
    required this.id, required this.estado, required this.fecha,
    required this.metodoPago, required this.items, required this.total,
    this.notas, this.direccionEntrega, this.tipoEntrega = 'local',
    this.backendId, this.tieneComprobante = false, this.comprobanteImgUrl,
    this.estadoPago, this.comprobanteValidacion, this.estadoDevolucion,
  });

  // ── Lecturas derivadas del veredicto del comprobante ──────────────
  String? get comprobanteEstado => comprobanteValidacion?['estado'] as String?;
  bool get comprobanteVerificado => comprobanteEstado == 'valido';
  bool get comprobanteEnRevision => comprobanteEstado == 'ilegible' || comprobanteEstado == 'sin_comprobante';
  bool get comprobanteValorNoCoincide => comprobanteEstado == 'valor_no_coincide';
  /// Valor que el backend leyó del comprobante (null si no pudo leerlo).
  double? get comprobanteValor {
    final v = comprobanteValidacion?['valor'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
  String? get comprobanteEntidad => comprobanteValidacion?['entidad'] as String?;

  /// true cuando el pago fue rechazado explícitamente (no una cancelación
  /// por otro motivo) — el backend lo marca con estado_pago='rechazado'.
  bool get pagoRechazado => estadoPago == 'rechazado';
  bool get pagoAprobado  => estadoPago == 'aprobado';

  // ── Devoluciones ───────────────────────────────────────────────
  bool get tieneDevolucion => estadoDevolucion == 'parcial' || estadoDevolucion == 'total';
  bool get devolucionTotal => estadoDevolucion == 'total';

  /// Ítems que todavía tienen unidades sin devolver — los únicos que tiene
  /// sentido ofrecer en el formulario de devolución.
  List<CartItem> get itemsDevolvibles =>
    items.where((i) => i.cantidadDevolvible > 0).toList();

  // Secuencia real de estados que recorre un pedido en el backend.
  // 'entregado' es el ÚLTIMO paso (índice 4, el final de la lista) — no un
  // estado aparte: cuando el pedido llega ahí, el paso a paso lo debe
  // mostrar como completado, no como "en curso" (ver _EstadoStepper en
  // orders.dart). 'cancelado' queda fuera: es un estado especial, no un
  // paso más.
  static const List<String> secuencia = [
    'pendiente_verificacion', 'pendiente', 'en_preparacion', 'listo', 'entregado',
  ];

  static const estados = {
    'pendiente_verificacion': 'Verificando pago',
    'pendiente':              'Pago confirmado',
    'en_preparacion':         'En preparación',
    'listo':                  'Listo ✓',
    'entregado':              'Entregado',
    'cancelado':              'Cancelado',
    // Se pone cuando el staff APRUEBA una devolución que el cliente pidió
    // (ver AppState.solicitarDevolucion) — mismo campo `estado` de
    // `pedidos` que todo lo demás en este mapa, el backend simplemente lo
    // cambia a este valor en vez de dejarlo en "entregado".
    'devuelto':               'Devuelto',
  };

  static const coloresEstado = {
    'pendiente_verificacion': 0xFFAD1457,
    'pendiente':              0xFFFFB300,
    'en_preparacion':         0xFF42A5F5,
    'listo':                  0xFF4CAF50,
    // Antes usaba el mismo gris que el color "de respaldo" para un estado
    // desconocido (0xFF6B6355 — ver los "?? 0xFF6B6355" en orders.dart), así
    // que un pedido ENTREGADO se veía igual de apagado que uno con un
    // estado que la app ni siquiera reconoce. Verde oscuro propio, distinto
    // del de "listo", para que se lea claramente como el paso final.
    'entregado':              0xFF2E7D32,
    'cancelado':              0xFFE53935,
    'devuelto':               0xFFEF6C00,
  };

  // El backend/admin ha usado más de un nombre para el mismo paso
  // intermedio ("en_proceso" en el panel de pedidos vs. "en_preparacion"
  // acá) — sin esto, un pedido con ese estado no calza con nada de
  // [secuencia] y su paso a paso se queda clavado en el primer paso en vez
  // de avanzar.
  static const Map<String, String> _aliasEstado = {
    'en_proceso': 'en_preparacion',
  };

  // Limpia lo que venga del backend (espacios, mayúsculas, alias) ANTES de
  // guardarlo en `estado` — así todo el resto del modelo (secuencia,
  // estados, coloresEstado, esCancelado) puede comparar por igualdad simple
  // sin que un estado real quede sin reconocer solo por venir con otro
  // formato. Ver PedidoSync.fromJson, que es donde se aplica.
  static String normalizarEstado(String raw) {
    final limpio = raw.trim().toLowerCase();
    return _aliasEstado[limpio] ?? limpio;
  }

  bool get esCancelado => estado == 'cancelado';
  // 'devuelto' es, igual que 'cancelado', un estado especial fuera de
  // [secuencia] — no un paso más del progreso normal del pedido.
  bool get esDevuelto  => estado == 'devuelto';

  // Índice del paso actual dentro de [secuencia]; -1 si el pedido está
  // cancelado, devuelto, o llegó un estado desconocido.
  int get pasoActual => secuencia.indexOf(estado);

  Pedido copyWith({
    String? id, String? estado, String? fecha, String? metodoPago,
    List<CartItem>? items, double? total, String? notas,
    String? direccionEntrega, String? tipoEntrega,
    int? backendId, bool? tieneComprobante, String? comprobanteImgUrl,
    String? estadoPago, Map<String, dynamic>? comprobanteValidacion,
    String? estadoDevolucion,
  }) => Pedido(
    id: id ?? this.id, estado: estado ?? this.estado, fecha: fecha ?? this.fecha,
    metodoPago: metodoPago ?? this.metodoPago, items: items ?? this.items,
    total: total ?? this.total, notas: notas ?? this.notas,
    direccionEntrega: direccionEntrega ?? this.direccionEntrega,
    tipoEntrega: tipoEntrega ?? this.tipoEntrega,
    backendId: backendId ?? this.backendId,
    tieneComprobante: tieneComprobante ?? this.tieneComprobante,
    comprobanteImgUrl: comprobanteImgUrl ?? this.comprobanteImgUrl,
    estadoPago: estadoPago ?? this.estadoPago,
    comprobanteValidacion: comprobanteValidacion ?? this.comprobanteValidacion,
    estadoDevolucion: estadoDevolucion ?? this.estadoDevolucion,
  );
}

// ── USUARIO (CLIENTE) ─────────────────────────────────────────
class Usuario {
  // id numérico real de "clientes" en el backend — necesario para mandar
  // cliente_id al crear un pedido (POST /pedidos no usa auth, así que no
  // hay forma de que el backend infiera quién es el cliente si no se lo
  // mandamos explícito).
  final int?    id;
  final String  nombre, correo;
  final String? telefono, tipoDoc, numeroDoc, departamento, municipio, comuna, direccion;
  // Fecha de registro (columna created_at del backend, alias "fechaRegistro"
  // — ver sicaber-backend/src/config/clienteCols.js), en formato ISO tal
  // como llega de PostgreSQL. Se formatea en español al mostrarla.
  final String? fechaRegistro;

  const Usuario({
    this.id, required this.nombre, required this.correo,
    this.telefono, this.tipoDoc, this.numeroDoc,
    this.departamento, this.municipio, this.comuna, this.direccion,
    this.fechaRegistro,
  });

  Usuario copyWith({int? id, String? nombre, String? correo, String? telefono,
    String? tipoDoc, String? numeroDoc, String? departamento,
    String? municipio, String? comuna, String? direccion, String? fechaRegistro}) =>
    Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre, correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono, tipoDoc: tipoDoc ?? this.tipoDoc,
      numeroDoc: numeroDoc ?? this.numeroDoc, departamento: departamento ?? this.departamento,
      municipio: municipio ?? this.municipio, comuna: comuna ?? this.comuna,
      direccion: direccion ?? this.direccion,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro);
}