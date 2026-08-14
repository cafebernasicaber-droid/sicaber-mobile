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

  const Combo({
    required this.id, required this.nombre, required this.precio,
    this.descripcion = '', this.imagen, this.estado = true,
    this.items = const [],
  });

  // El "ahorro" se calcula sumando precioOriginal de cada item del combo (si viene informado)
  double get totalOriginal =>
    items.fold(0.0, (s, it) => s + ((it['precioOriginal'] ?? it['precio'] ?? 0) as num).toDouble());

  double get ahorro => totalOriginal > precio ? totalOriginal - precio : 0;

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

// ── CART ITEM ─────────────────────────────────────────────────
class CartItem {
  final String   cartKey;
  final Producto producto;
  int            cantidad;
  final List<Topping> toppings;
  final List<Adicion> adiciones;

  CartItem({
    required this.cartKey, required this.producto, this.cantidad = 1,
    this.toppings = const [], this.adiciones = const [],
  });

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

  const Pedido({
    required this.id, required this.estado, required this.fecha,
    required this.metodoPago, required this.items, required this.total,
    this.notas, this.direccionEntrega, this.tipoEntrega = 'local',
    this.backendId, this.tieneComprobante = false, this.comprobanteImgUrl,
  });

  // Secuencia real de estados que recorre un pedido en el backend.
  // 'cancelado' queda fuera: es un estado especial, no un paso más.
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
  };

  static const coloresEstado = {
    'pendiente_verificacion': 0xFFAD1457,
    'pendiente':              0xFFFFB300,
    'en_preparacion':         0xFF42A5F5,
    'listo':                  0xFF4CAF50,
    'entregado':              0xFF6B6355,
    'cancelado':              0xFFE53935,
  };

  bool get esCancelado => estado == 'cancelado';

  // Índice del paso actual dentro de [secuencia]; -1 si el pedido está
  // cancelado o llegó un estado desconocido.
  int get pasoActual => secuencia.indexOf(estado);

  Pedido copyWith({
    String? id, String? estado, String? fecha, String? metodoPago,
    List<CartItem>? items, double? total, String? notas,
    String? direccionEntrega, String? tipoEntrega,
    int? backendId, bool? tieneComprobante, String? comprobanteImgUrl,
  }) => Pedido(
    id: id ?? this.id, estado: estado ?? this.estado, fecha: fecha ?? this.fecha,
    metodoPago: metodoPago ?? this.metodoPago, items: items ?? this.items,
    total: total ?? this.total, notas: notas ?? this.notas,
    direccionEntrega: direccionEntrega ?? this.direccionEntrega,
    tipoEntrega: tipoEntrega ?? this.tipoEntrega,
    backendId: backendId ?? this.backendId,
    tieneComprobante: tieneComprobante ?? this.tieneComprobante,
    comprobanteImgUrl: comprobanteImgUrl ?? this.comprobanteImgUrl,
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