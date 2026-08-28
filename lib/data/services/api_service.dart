import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
// ── CONFIGURACIÓN DE LA API ───────────────────────────────────
// Cambia esta URL según tu entorno:
// - Android emulador: 'http://10.0.2.2:4000/api'
// - Dispositivo físico en la misma red: 'http://192.168.X.X:4000/api'
// - Producción: 'https://tu-dominio.com/api'
String get _baseUrl {
  if (kIsWeb) {
    return 'http://localhost:4000/api';
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:4000/api'; // emulador Android
  } else {
    return 'http://localhost:4000/api'; // iOS simulator / desktop
  }
}

// Igual que _baseUrl pero sin el sufijo /api, porque las imágenes se
// sirven como archivos estáticos (ej: http://localhost:4000/uploads/foto.jpg)
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

  // ── GET ───────────────────────────────────────────────────
  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
    return _parse(res);
  }

  // ── POST ──────────────────────────────────────────────────
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_baseUrl$path'),
      headers: _headers, body: jsonEncode(body));
    return _parse(res);
  }

  // ── PUT ───────────────────────────────────────────────────
  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$_baseUrl$path'),
      headers: _headers, body: jsonEncode(body));
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Error ${res.statusCode}');
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
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

  const PedidoSync({
    required this.backendId, required this.estado, required this.fecha,
    this.tieneComprobante = false, this.comprobanteImgUrl,
  });

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
    tieneComprobante: j['comprobante_img'] != null,
    comprobanteImgUrl: buildImageUrl(j['comprobante_img'] as String?),
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
      );
    }).toList();

    return Pedido(
      id: 'PED-${sync.backendId}',
      estado: sync.estado,
      fecha: sync.fecha,
      metodoPago: j['pago'] as String? ?? '',
      items: items,
      total: parseNum(j['total']),
      // El backend todavía no tiene columna "notas" en la tabla pedidos —
      // no hay de dónde traerlas para pedidos históricos.
      notas: null,
      direccionEntrega: j['direccion_alternativa'] as String?,
      tipoEntrega: j['tipo'] as String? ?? 'local',
      backendId: sync.backendId,
      tieneComprobante: sync.tieneComprobante,
      comprobanteImgUrl: sync.comprobanteImgUrl,
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