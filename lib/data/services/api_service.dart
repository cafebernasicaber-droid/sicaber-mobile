import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

// ── CONFIGURACIÓN DE LA API ───────────────────────────────────
// Apunta al backend desplegado en Render, que funciona igual en web,
// Android, iOS y escritorio. Antes cada plataforma tenía su propia URL a
// localhost (10.0.2.2 para el emulador, localhost para el resto), así que
// la app solo servía con el backend corriendo en la misma máquina — y al
// moverlo a Render dejó de conectar por completo.
//
// Para desarrollar contra un backend local NO hay que editar este archivo:
// se pasa la URL al ejecutar.
//   flutter run --dart-define=API_URL=http://localhost:4000/api
//   flutter run --dart-define=API_URL=http://10.0.2.2:4000/api
//
// Ese 10.0.2.2 es para el emulador de Android: ahí "localhost" es el
// propio emulador, no el PC — 10.0.2.2 es la dirección con la que el
// emulador ve la máquina anfitriona.
//
// Nota: Render suspende el servicio gratuito tras 15 minutos sin tráfico.
// La primera petición después de eso puede tardar 30-50 segundos.
const String _apiUrlPorDefecto = 'https://sicaber-back.onrender.com/api';

String get _baseUrl => const String.fromEnvironment(
      'API_URL',
      defaultValue: _apiUrlPorDefecto,
    );

// Igual que _baseUrl pero sin el sufijo /api, porque las imágenes se
// sirven como archivos estáticos (ej: https://…/uploads/foto.jpg)
String get _mediaBaseUrl => _baseUrl.replaceAll('/api', '');

/// Convierte lo que venga en el campo `imagen` del backend (puede ser una
/// ruta relativa como "/uploads/xyz.jpg" o ya una URL completa) en una URL
/// que el navegador / dispositivo pueda cargar directamente.
/// Devuelve null si no hay imagen, para que la UI muestre un ícono de respaldo.
String? buildImageUrl(String? imagen) {
  if (imagen == null || imagen.isEmpty) return null;
  if (imagen.startsWith('http://') || imagen.startsWith('https://') || imagen.startsWith('data:')) {
    return imagen;
  }
  final ruta = imagen.startsWith('/') ? imagen : '/$imagen';
  return '$_mediaBaseUrl$ruta';
}

// ── TIEMPOS MÁXIMOS DE ESPERA ─────────────────────────────────
// CAUSA RAÍZ de las "pantallas de carga indefinidas": ninguna petición
// tenía timeout. El paquete http de Dart, sin un .timeout() explícito,
// espera para siempre — si el servidor acepta la conexión y no contesta
// (Render suspende el plan gratuito y la primera petición puede quedarse
// colgada, o el celular pierde la red a mitad de una subida), el Future
// nunca se completa y el spinner de la pantalla gira sin fin, sin error
// que mostrar y sin forma de reintentar.
//
// Son tres valores distintos a propósito: subir un comprobante en base64
// es muchísimo más pesado que pedir el menú, y usar el mismo número para
// los dos obligaría a poner un timeout larguísimo en todo.
const Duration _timeoutLectura  = Duration(seconds: 20);
const Duration _timeoutEscritura = Duration(seconds: 30);
const Duration _timeoutSubida   = Duration(seconds: 90);

// El plan gratuito de Render apaga el servicio tras 15 minutos sin
// tráfico y tarda ~30-50 s en despertar. Un solo intento con timeout corto
// lo daría por caído siempre que el cliente sea el primero en entrar en un
// rato, así que las lecturas se reintentan una vez.
const int _reintentosLectura = 1;

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _token;
  String? get token => _token;
  bool    get hasToken => _token != null;

  void setToken(String t) => _token = t;
  void clearToken()       => _token = null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Envuelve cualquier petición con su timeout y traduce los fallos de red
  // a un ApiException con mensaje entendible. Sin esto, un corte de red
  // llegaba a la UI como un SocketException crudo con texto en inglés.
  Future<dynamic> _enviar(
    Future<http.Response> Function() peticion, {
    required Duration timeout,
    int reintentos = 0,
  }) async {
    for (var intento = 0; ; intento++) {
      try {
        final res = await peticion().timeout(timeout);
        return _parse(res);
      } on ApiException {
        // Error de negocio (4xx/5xx con cuerpo): se propaga tal cual, no
        // se reintenta — la respuesta sería idéntica.
        rethrow;
      } on TimeoutException {
        if (intento < reintentos) continue;
        throw ApiException(
          'El servidor está tardando demasiado en responder. Revisa tu conexión e intenta de nuevo.',
          statusCode: 0, esDeRed: true);
      } catch (e) {
        if (intento < reintentos) continue;
        throw ApiException(
          'No pudimos conectarnos con el servidor. Revisa tu conexión a internet.',
          statusCode: 0, esDeRed: true);
      }
    }
  }

  // ── GET ───────────────────────────────────────────────────
  Future<dynamic> get(String path, {Duration? timeout}) => _enviar(
    () => http.get(Uri.parse('$_baseUrl$path'), headers: _headers),
    timeout: timeout ?? _timeoutLectura,
    reintentos: _reintentosLectura,
  );

  // ── POST ──────────────────────────────────────────────────
  // `subida: true` para los cuerpos que llevan una imagen en base64 (crear
  // un pedido con comprobante): necesitan mucho más tiempo que una
  // petición normal.
  Future<dynamic> post(String path, Map<String, dynamic> body, {bool subida = false, Duration? timeout}) => _enviar(
    () => http.post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body)),
    timeout: timeout ?? (subida ? _timeoutSubida : _timeoutEscritura),
  );

  // ── PUT ───────────────────────────────────────────────────
  Future<dynamic> put(String path, Map<String, dynamic> body, {bool subida = false, Duration? timeout}) => _enviar(
    () => http.put(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body)),
    timeout: timeout ?? (subida ? _timeoutSubida : _timeoutEscritura),
  );

  // ── PATCH ─────────────────────────────────────────────────
  // No existía. El backend expone varias rutas que solo aceptan PATCH
  // (estado de un pedido, aprobar/rechazar comprobante, estado de una
  // devolución); sin este método no había forma de llamarlas desde la app.
  Future<dynamic> patch(String path, Map<String, dynamic> body, {Duration? timeout}) => _enviar(
    () => http.patch(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body)),
    timeout: timeout ?? _timeoutEscritura,
  );

  dynamic _parse(http.Response res) {
    final cuerpo = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = cuerpo.isEmpty ? null : jsonDecode(cuerpo);
    } catch (_) {
      // El servidor contestó algo que no es JSON: una página de error del
      // hosting, un portal cautivo del wifi, un HTML de "servicio
      // suspendido". Antes esto reventaba con un FormatException críptico
      // dentro del jsonDecode, ANTES de poder mirar siquiera el código de
      // estado.
      throw ApiException(
        res.statusCode >= 400
          ? 'El servidor respondió con un error (${res.statusCode}).'
          : 'El servidor respondió algo inesperado. Intenta de nuevo.',
        statusCode: res.statusCode);
    }
    if (res.statusCode >= 400) {
      final mapa = data is Map<String, dynamic> ? data : null;
      throw ApiException(
        (mapa?['error'] as String?) ?? 'Error ${res.statusCode}',
        statusCode: res.statusCode,
        data: mapa);
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  // statusCode/data — antes ApiException solo cargaba el mensaje. Hacen
  // falta para distinguir respuestas de error que traen más que un texto
  // (ej. POST /pedidos con dirección a domicilio: 409 +
  // {motivo:'no_geocodificada', requiereSeleccionManual:true} pide elegir
  // el local más cercano a mano, mientras que 400 es un rechazo firme por
  // estar fuera de comuna 8/9 — ver AppState.crearPedido/cart.dart).
  final int statusCode;
  final Map<String, dynamic>? data;
  // true cuando el fallo fue de RED (sin internet, timeout), no una
  // respuesta del servidor. La UI lo usa para ofrecer "Reintentar" en vez
  // de mostrar el error como si el pedido se hubiera rechazado.
  final bool esDeRed;
  ApiException(this.message, {this.statusCode = 0, this.data, this.esDeRed = false});

  // Clave estable que manda el backend para distinguir el caso concreto
  // (ej. 'valor_no_coincide', 'comprobante_repetido', 'no_geocodificada').
  String? get motivo => data?['motivo'] as String?;

  @override String toString() => message;
}

// ── HELPER: convierte num o String (Postgres NUMERIC llega como texto) ──
double parseNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

// ── MODELOS DESDE JSON ────────────────────────────────────────
extension ProductoFromJson on Producto {
  static Producto fromJson(Map<String, dynamic> j) => Producto(
    id:          j['id'] as int,
    nombre:      j['nombre'] as String,
    descripcion: j['descripcion'] as String? ?? '',
    categoria:   j['categoria'] as String? ?? '',
    precio:      parseNum(j['precio']),
    descuento:   parseNum(j['descuento']),
    imagen:      j['imagen'] as String?,
    estado:      j['estado'] == 'Activo',
  );
}

extension AdicionFromJson on Adicion {
  static Adicion fromJson(Map<String, dynamic> j) => Adicion(
    id:     j['id'] as int,
    nombre: j['nombre'] as String,
    precio: parseNum(j['precio']),
    estado: (j['estado'] as String? ?? 'Activo') == 'Activo',
  );
}

extension ToppingFromJson on Topping {
  static Topping fromJson(Map<String, dynamic> j) => Topping(
    id:          j['id'] as int,
    nombre:      j['nombre'] as String,
    descripcion: j['descripcion'] as String? ?? '',
    precio:      parseNum(j['precio']),
    gratuito:    parseNum(j['precio']) == 0,
    productosIds: _parseIdList(j['productos_ids']),
  );
}

// Columna jsonb: normalmente ya llega como List<dynamic> (node-pg parsea
// jsonb automáticamente), pero por robustez también acepta un string JSON
// crudo — mismo patrón defensivo que ComboFromJson usa para "items".
List<int> _parseIdList(dynamic raw) {
  List<dynamic> lista = const [];
  if (raw is List) {
    lista = raw;
  } else if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) lista = decoded;
    } catch (_) {}
  }
  return lista.map((e) => (e as num).toInt()).toList();
}

extension CategoriaFromJson on Categoria {
  static Categoria fromJson(Map<String, dynamic> j) => Categoria(
    id:          j['id'] as int,
    nombre:      j['nombre'] as String,
    descripcion: j['descripcion'] as String? ?? '',
  );
}

extension LocalFromJson on Local {
  static Local fromJson(Map<String, dynamic> j) => Local(
    id:        j['id'] as int,
    nombre:    j['nombre'] as String,
    direccion: j['direccion'] as String?,
  );
}

// METODO_PAGO_COLS en el backend ya devuelve "urlQr" en camelCase (alias
// de la columna url_qr) — mismo patrón que el resto de columnas snake_case
// que se alían al traerlas (ver clienteCols.js).
extension MetodoPagoFromJson on MetodoPago {
  static MetodoPago fromJson(Map<String, dynamic> j) => MetodoPago(
    id:          j['id'] as int,
    nombre:      j['nombre'] as String,
    descripcion: j['descripcion'] as String?,
    urlQr:       j['urlQr'] as String?,
  );
}

extension ComboFromJson on Combo {
  // Acepta las dos formas que se han visto en el backend: un solo campo
  // "items" (jsonb unificado), o "productos"/"adiciones" por separado
  // (como los devuelve GET /combos en Landing.jsx) — se combinan en un
  // único listado para no depender de cuál de las dos esté vigente.
  static List<Map<String, dynamic>> _parseItemList(dynamic raw) {
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return const [];
  }

  static DateTime? _parseFecha(dynamic v) {
    if (v == null) return null;
    try { return DateTime.parse(v.toString()); } catch (_) { return null; }
  }

  static Combo fromJson(Map<String, dynamic> j) {
    final itemsUnificados = _parseItemList(j['items']);
    final items = itemsUnificados.isNotEmpty
        ? itemsUnificados
        : [..._parseItemList(j['productos']), ..._parseItemList(j['adiciones'])];
    return Combo(
      id:          j['id'] as int,
      nombre:      j['nombre'] as String,
      precio:      parseNum(j['precio']),
      descripcion: j['descripcion'] as String? ?? '',
      imagen:      j['imagen'] as String?,
      estado:      (j['estado'] as String? ?? 'Activo') == 'Activo',
      items:       items,
      fechaInicio: _parseFecha(j['fechaInicio'] ?? j['fecha_inicio']),
      fechaFin:    _parseFecha(j['fechaFin'] ?? j['fecha_fin']),
    );
  }
}

// ── USUARIO (CLIENTE) — respuesta de /auth/cliente/login,
// /auth/cliente/verificar y GET /clientes/mi-perfil ────────────
// Los tres endpoints devuelven el mismo "perfil completo" (misma
// constante CLIENTE_COLS en el backend, con alias camelCase para las
// columnas snake_case: tipo_doc→tipoDoc, numero_doc→numeroDoc,
// created_at→fechaRegistro). Ver sicaber-backend/src/config/clienteCols.js.
extension UsuarioFromJson on Usuario {
  static Usuario fromJson(Map<String, dynamic> c) => Usuario(
    id:            c['id'] as int?,
    nombre:        c['nombre'] as String,
    correo:        c['correo'] as String,
    telefono:      c['telefono'] as String?,
    tipoDoc:       c['tipoDoc'] as String?,
    numeroDoc:     c['numeroDoc'] as String?,
    departamento:  c['departamento'] as String?,
    municipio:     c['municipio'] as String?,
    comuna:        c['comuna'] as String?,
    direccion:     c['direccion'] as String?,
    fechaRegistro: c['fechaRegistro'] as String?,
  );
}

// ── PEDIDO (respuesta cruda de la fila `pedidos` en PostgreSQL) ──
// Se usa tanto al crear un pedido (POST /pedidos) como al refrescar su
// estado (GET /pedidos/:id). No reconstruye los `items` completos (el
// backend solo guarda nombre/precio/cantidad, no el Producto completo);
// para eso se conserva la copia local creada en el checkout y solo se
// actualizan campos "vivos" como estado y comprobante vía [Pedido.copyWith].
class PedidoSync {
  final int     backendId;
  final String  estado;
  final String  fecha;
  final bool    tieneComprobante;
  final String? comprobanteImgUrl;
  // Campos que el backend ya devolvía (o devuelve desde la corrección de
  // esta ronda) y que la app simplemente no estaba leyendo.
  final String? estadoPago;
  final Map<String, dynamic>? comprobanteValidacion;
  final String? estadoDevolucion;

  const PedidoSync({
    required this.backendId, required this.estado, required this.fecha,
    this.tieneComprobante = false, this.comprobanteImgUrl,
    this.estadoPago, this.comprobanteValidacion, this.estadoDevolucion,
  });

  // comprobante_validacion es una columna JSONB: node-pg normalmente la
  // entrega ya parseada, pero se acepta también el texto crudo — mismo
  // patrón defensivo que ComboFromJson usa con "items".
  static Map<String, dynamic>? _parseMapa(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  factory PedidoSync.fromJson(Map<String, dynamic> j) => PedidoSync(
    backendId: j['id'] as int,
    // normalizarEstado limpia espacios/mayúsculas y resuelve alias (ej.
    // "en_proceso" → "en_preparacion") para que Pedido.secuencia/estados/
    // coloresEstado siempre lo reconozcan — ver Pedido.normalizarEstado.
    estado: Pedido.normalizarEstado(j['estado'] as String? ?? 'pendiente_verificacion'),
    fecha: (j['created_at'] as String? ?? '').replaceFirst('T', ' ').replaceFirst(RegExp(r'\.\d+Z?$'), '').trim(),
    // "comprobante" en el backend es solo un texto corto (nombre de
    // archivo / "Enviado por WhatsApp" / etc.); la imagen real que revisa
    // el cajero vive en "comprobante_img" — es esa la que determina si
    // hay algo que verificar.
    tieneComprobante: j['comprobante_img'] != null || j['comprobanteImg'] != null,
    // OJO: aquí NO se usa buildImageUrl. El comprobante que sube la app es
    // una data URL en base64, y buildImageUrl la devolvía intacta para que
    // después Image.network intentara descargarla como si fuera una
    // dirección web — por eso el comprobante nunca se veía. Se guarda la
    // fuente TAL CUAL y es ComprobanteImage quien decide cómo pintarla
    // (ver widgets/common/comprobante_view.dart).
    comprobanteImgUrl: (j['comprobante_img'] ?? j['comprobanteImg']) as String?,
    estadoPago: j['estado_pago'] as String?,
    comprobanteValidacion: _parseMapa(j['comprobanteValidacion'] ?? j['comprobante_validacion']),
    estadoDevolucion: j['estado_devolucion'] as String?,
  );
}

// Convierte lo que venga en "id" (int real de producto, o algo tipo
// "combo-5" para combos del carrito compartido) a un int usable como
// Producto.id. Un combo no tiene id numérico real — se resuelve a 0 en vez
// de reventar el cast, ya que esto es solo para reconstruir el historial
// de pedidos (no hace falta un id navegable de vuelta a /menu/:id).
int _asId(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// ── PEDIDO completo (GET /pedidos/mis-pedidos) ──────────────────
// A diferencia de PedidoSync (que solo trae los campos "vivos" de un
// pedido ya conocido localmente), esto reconstruye un Pedido entero —
// items, toppings y adiciones incluidos — a partir del historial que
// devuelve el backend, para pedidos que la sesión actual de la app nunca
// creó (otra sesión, otro dispositivo, o la propia web). Usa el campo
// "productos" que arma enriquecerItemsPedido() en el backend: cada línea
// trae producto_id/producto_nombre + personalizacion.toppings/adiciones
// ya resueltos a {id, nombre[, precio]} (no solo ids sueltos).
//
// Los Producto/Topping/Adicion reconstruidos aquí son "de solo lectura
// para mostrar" — no tienen descripcion/categoria/imagen reales (el
// backend nunca guardó eso en el pedido), así que no deben usarse para
// nada más que listar el historial.
extension PedidoFromJson on Pedido {
  static Pedido fromJson(Map<String, dynamic> j) {
    final sync = PedidoSync.fromJson(j);
    final productos = (j['productos'] as List?) ?? const [];

    // cartKey solo necesita ser único dentro de este pedido (se usa como
    // key de lista al mostrar el detalle) — el índice dentro de
    // "productos" alcanza.
    final items = productos.asMap().entries.map((entry) {
      final p = entry.value as Map<String, dynamic>;
      final producto = Producto(
        id: _asId(p['producto_id'] ?? p['id']),
        nombre: (p['producto_nombre'] ?? p['nombre']) as String? ?? 'Producto',
        descripcion: '', categoria: '',
        precio: parseNum(p['precio']),
      );
      final personalizacion = p['personalizacion'] as Map<String, dynamic>?;
      final toppings = ((personalizacion?['toppings'] as List?) ?? const [])
        .map((t) => t as Map<String, dynamic>)
        .map((t) => Topping(id: _asId(t['id']), nombre: t['nombre'] as String? ?? ''))
        .toList();
      final adiciones = ((personalizacion?['adiciones'] as List?) ?? const [])
        .map((a) => a as Map<String, dynamic>)
        .map((a) => Adicion(id: _asId(a['id']), nombre: a['nombre'] as String? ?? '', precio: parseNum(a['precio'])))
        .toList();
      final cantidad = _asId(p['cantidad']);
      return CartItem(
        cartKey: '${producto.id}-${entry.key}',
        producto: producto,
        cantidad: cantidad == 0 ? 1 : cantidad,
        toppings: toppings, adiciones: adiciones,
        // La POSICIÓN de la línea dentro del pedido. El backend arma
        // "productos" en el mismo orden que `pedidos.items`, así que el
        // índice de este map es exactamente el item_index que espera
        // POST /devoluciones — y es lo único que identifica sin ambigüedad
        // una línea (un combo no tiene producto_id, y el mismo producto
        // puede aparecer dos veces con toppings distintos).
        itemIndex: entry.key,
        // Lo ya devuelto y aprobado de esta línea (lo calcula
        // conEstadoDevolucion en el backend).
        cantidadDevuelta: _asId(p['cantidadDevuelta']),
      );
    }).toList();

    return Pedido(
      id: 'PED-${sync.backendId}',
      estado: sync.estado,
      fecha: sync.fecha,
      metodoPago: j['pago'] as String? ?? '',
      items: items,
      // El total que manda el backend es el que ÉL calculó y contra el que
      // valida el comprobante (total_calculado cuando pudo reconstruir el
      // carrito, si no el total guardado) — nunca se recalcula en la app,
      // justo para que los dos números no puedan separarse.
      total: parseNum(j['totalCalculado'] ?? j['total_calculado'] ?? j['total']),
      // El backend todavía no tiene columna "notas" en la tabla pedidos —
      // no hay de dónde traerlas para pedidos históricos.
      notas: null,
      direccionEntrega: j['direccion_alternativa'] as String?,
      tipoEntrega: j['tipo'] as String? ?? 'local',
      backendId: sync.backendId,
      tieneComprobante: sync.tieneComprobante,
      comprobanteImgUrl: sync.comprobanteImgUrl,
      estadoPago: sync.estadoPago,
      comprobanteValidacion: sync.comprobanteValidacion,
      estadoDevolucion: sync.estadoDevolucion,
    );
  }
}

extension PromocionFromProducto on Promocion {
  static Promocion fromProducto(Producto p, Map<String, dynamic> j) {
    DateTime? parseFecha(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }
    return Promocion(
      producto: p,
      inicio: parseFecha(j['fecha_inicio_desc']),
      fin:    parseFecha(j['fecha_fin_desc']),
    );
  }
}