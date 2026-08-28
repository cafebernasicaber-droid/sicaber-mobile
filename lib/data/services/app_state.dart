import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_service.dart';

const _kTokenPref = 'auth_token';

// ── APP STATE ─────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState _i = AppState._();
  static AppState get instance => _i;

  final _api = ApiService.instance;

  // ── Auth ──────────────────────────────────────────────────
  Usuario?  _usuario;
  Usuario?  get usuario  => _usuario;
  bool      get loggedIn => _usuario != null;

  // ── Datos de la API ───────────────────────────────────────
  List<Producto>  _productos   = [];
  List<Adicion>   _adiciones   = [];
  List<Topping>   _toppings    = [];
  List<Categoria> _categorias  = [];
  List<Combo>     _combos      = [];
  List<Promocion> _promociones = [];
  List<Local>     _locales     = [];

  List<Producto>  get productos   => _productos;
  List<Adicion>   get adiciones   => _adiciones;
  List<Topping>   get toppings    => _toppings;
  List<Categoria> get categorias  => _categorias;
  List<Combo>     get combos      => _combos;
  List<Promocion> get promociones => _promociones;
  List<Local>     get locales     => _locales;
  bool _datosLoaded = false;

  // Antes, un solo fetch fallando (adiciones, toppings, lo que fuera) tumbaba
  // TODO cargarDatos() a mitad de camino: el catch general cortaba la
  // ejecución antes de llegar a "_datosLoaded = true", así que ni siquiera
  // los productos que sí habían cargado bien quedaban disponibles, y como
  // _datosLoaded se quedaba en false para siempre, no había forma de
  // reintentar sin cerrar y volver a abrir la app. Ahora cada sección se
  // pide con su propio try/catch (ver _cargarProductos/_cargarAdiciones/...
  // más abajo) y se registra aparte en _seccionesFallidas.
  final Set<String> _seccionesFallidas = {};
  static const _etiquetasSeccion = {
    'productos':  'productos',
    'adiciones':  'adiciones',
    'toppings':   'toppings',
    'categorias': 'categorías',
    'combos':     'combos',
  };

  // null = todo cargó bien. Si no, algo como "No se pudieron cargar:
  // adiciones, toppings." — para mostrar en un banner con botón reintentar.
  String? get errorCarga => _seccionesFallidas.isEmpty
      ? null
      : 'No se pudieron cargar: '
        '${_seccionesFallidas.map((k) => _etiquetasSeccion[k]!).join(', ')}.';

  // false hasta que el PRIMER intento de cargarDatos() (éxito o fallo
  // parcial) termine — para que la pantalla de menú pueda mostrar un
  // spinner en vez de una grilla vacía mientras arranca.
  bool _primerIntentoTerminado = false;
  bool get cargandoInicial => !_primerIntentoTerminado;

  // GET /api/locales (pública, sin auth) — locales activos donde el
  // cliente puede elegir "Recoger en el local". Aparte de cargarDatos()
  // porque el checkout la necesita justo al abrir el paso de tipo de
  // entrega, sin depender de que ya haya corrido la carga general.
  Future<void> cargarLocales() async {
    try {
      final data = await _api.get('/locales');
      _locales = (data as List).map((j) => LocalFromJson.fromJson(j)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar la lista de locales: $e');
    }
  }

  Future<bool> _cargarProductos() async {
    try {
      final ps = await _api.get('/productos');
      final psList = (ps as List).cast<Map<String, dynamic>>();
      _productos = psList.map((j) => ProductoFromJson.fromJson(j)).toList();
      // Promociones = productos con descuento activo (no viene endpoint aparte,
      // se deriva de la misma tabla productos, igual que hace la web)
      _promociones = [
        for (final j in psList)
          if (parseNum(j['descuento']) > 0)
            PromocionFromProducto.fromProducto(ProductoFromJson.fromJson(j), j)
      ].where((p) => p.vigente).toList();
      return true;
    } catch (e) {
      debugPrint('❌ ERROR cargando productos: $e');
      return false;
    }
  }

  Future<bool> _cargarAdiciones() async {
    try {
      final as_ = await _api.get('/adiciones');
      _adiciones = (as_ as List).map((j) => AdicionFromJson.fromJson(j)).toList();
      return true;
    } catch (e) {
      debugPrint('❌ ERROR cargando adiciones: $e');
      return false;
    }
  }

  Future<bool> _cargarToppings() async {
    try {
      final ts = await _api.get('/toppings');
      _toppings = (ts as List).map((j) => ToppingFromJson.fromJson(j)).toList();
      return true;
    } catch (e) {
      debugPrint('❌ ERROR cargando toppings: $e');
      return false;
    }
  }

  Future<bool> _cargarCategorias() async {
    try {
      final cs = await _api.get('/categorias');
      _categorias = (cs as List).map((j) => CategoriaFromJson.fromJson(j)).toList();
      return true;
    } catch (e) {
      debugPrint('❌ ERROR cargando categorias: $e');
      return false;
    }
  }

  Future<bool> _cargarCombos() async {
    try {
      final cb = await _api.get('/combos');
      _combos = (cb as List).map((j) => ComboFromJson.fromJson(j)).toList();
      return true;
    } catch (e) {
      debugPrint('❌ ERROR cargando combos: $e');
      return false;
    }
  }

  // Pide en paralelo cada sección de `claves` con su propio loader, y
  // actualiza _seccionesFallidas según el resultado individual de cada
  // una — una que falle no le impide terminar a las demás. Con productos
  // alcanza para que _datosLoaded quede en true y se pueda mostrar el
  // menú, aunque adiciones/toppings/etc. hayan fallado.
  Future<void> _cargarSecciones(List<String> claves) async {
    final loaders = <String, Future<bool> Function()>{
      'productos':  _cargarProductos,
      'adiciones':  _cargarAdiciones,
      'toppings':   _cargarToppings,
      'categorias': _cargarCategorias,
      'combos':     _cargarCombos,
    };
    final resultados = await Future.wait(
      claves.map((k) async => MapEntry(k, await loaders[k]!())));
    for (final r in resultados) {
      if (r.value) {
        _seccionesFallidas.remove(r.key);
      } else {
        _seccionesFallidas.add(r.key);
      }
    }
    if (!_seccionesFallidas.contains('productos')) _datosLoaded = true;
  }

  void _limpiarSeccion(String clave) {
    switch (clave) {
      case 'productos':  _productos = []; _promociones = []; break;
      case 'adiciones':  _adiciones = []; break;
      case 'toppings':   _toppings = []; break;
      case 'categorias': _categorias = []; break;
      case 'combos':     _combos = []; break;
    }
  }

  Future<void> cargarDatos() async {
    if (_datosLoaded) return;
    await _cargarSecciones(_etiquetasSeccion.keys.toList());
    _primerIntentoTerminado = true;
    notifyListeners();
  }

  // ── Reintentar SOLO lo que falló la última vez ────────────────
  // A diferencia de refrescarDatos() (fuerza recargar TODO, útil cuando
  // algo cambió en el admin), esto es para una carga inicial parcialmente
  // fallida: solo vuelve a pedir las secciones en _seccionesFallidas —
  // productos/adiciones/etc. que ya cargaron bien no se tocan.
  Future<void> reintentarCarga() async {
    if (_seccionesFallidas.isEmpty) return;
    final claves = _seccionesFallidas.toList();
    for (final k in claves) { _limpiarSeccion(k); }
    await _cargarSecciones(claves);
    notifyListeners();
  }

  // ── Forzar recarga del catálogo completo (productos/adiciones/etc.) ──
  // cargarDatos() solo pide los datos UNA vez por sesión de la app
  // (_datosLoaded evita repetir la carga en cada pantalla que la llama).
  // Si algo se crea/edita en el admin DESPUÉS de que la app ya cargó datos
  // una vez, la app nunca vuelve a pedirlos — no hay forma de verlo sin
  // reiniciar la app por completo. Esto resetea esa bandera y vuelve a
  // pedir TODO, para usarlo desde un pull-to-refresh o un botón
  // "Actualizar" en vez de depender de reiniciar la app.
  Future<void> refrescarDatos() async {
    _datosLoaded = false;
    await cargarDatos();
  }

  List<Producto> getProductosPorCategoria(String? cat) =>
    cat == null ? _productos : _productos.where((p) => p.categoria == cat).toList();

  List<Producto> buscarProductos(String q) {
    if (q.isEmpty) return _productos;
    final lq = q.toLowerCase();
    return _productos.where((p) =>
      p.nombre.toLowerCase().contains(lq) ||
      p.descripcion.toLowerCase().contains(lq) ||
      p.categoria.toLowerCase().contains(lq)).toList();
  }

  List<Producto> getOfertas() => _promociones.map((p) => p.producto).toList();

  // ── Login ─────────────────────────────────────────────────
  // Acepta tanto correo electrónico como nombre de usuario: el backend
  // (POST /auth/cliente/login) ya resuelve "correo" contra correo, username
  // o nombre (ver sicaber-backend/src/routes/auth.js), así que aquí solo
  // validamos que el campo no esté vacío.
  Future<String?> login(String identificador, String password) async {
    if (identificador.trim().isEmpty) return 'Ingresa tu correo o usuario';
    if (password.length < 6) return 'Contraseña mínimo 6 caracteres';
    try {
      final data = await _api.post('/auth/cliente/login', {
        'correo': identificador.trim(), 'password': password,
      });
      final c = data['cliente'] as Map<String, dynamic>;
      // TEMPORAL: confirma los nombres EXACTOS de las claves que manda el
      // backend (camelCase vs snake_case) antes de mapearlas más abajo.
      // Quita este print cuando ya no lo necesites para depurar.
      debugPrint('🔍 cliente (login): $c');
      await _guardarSesion(data['token'] as String, c);
      // No se espera (fire-and-forget): el login ya se dio por exitoso con
      // la sesión guardada arriba, no debe quedar pendiente de que el
      // historial de pedidos también responda.
      cargarPedidos();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

  // ── Registro ──────────────────────────────────────────────
  Future<String?> register(Map<String, String> data) async {
    if ((data['nombre'] ?? '').isEmpty) return 'El nombre es obligatorio';
    if (!(data['correo'] ?? '').contains('@')) return 'Correo inválido';
    if ((data['password'] ?? '').length < 6) return 'Contraseña mínimo 6 caracteres';
    try {
      await _api.post('/auth/cliente/registro', data);
      return null; // éxito → ir a verificar
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

  // ── Verificar token de correo ─────────────────────────────
  // POST /auth/cliente/verificar solo devuelve id/nombre/correo (la cuenta
  // recién se está creando, no hace falta el perfil completo todavía) —
  // por eso, a diferencia de login(), aquí sí hace falta un refresco
  // aparte con cargarPerfilCompleto() para traer el resto de campos que el
  // cliente ya escribió en el formulario de registro (dirección, comuna,
  // documento, etc.), que _guardarSesion por sí sola no tendría de dónde sacar.
  Future<String?> verificarCuenta(String correo, String token) async {
    try {
      final data = await _api.post('/auth/cliente/verificar', {
        'correo': correo, 'token': token,
      });
      final c = data['cliente'] as Map<String, dynamic>;
      debugPrint('🔍 cliente (verificar): $c');
      await _guardarSesion(data['token'] as String, c);
      // El perfil que acaba de crearse tiene más campos de los que
      // /cliente/verificar devuelve (ver comentario arriba) — se completan
      // con un refresco a GET /clientes/mi-perfil. Si falla (p. ej. sin
      // señal justo en ese instante), el login normal más adelante los
      // completará igual, así que no se trata como error de la verificación.
      await cargarPerfilCompleto();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión.';
    }
  }

  // Token + datos del cliente que sí vinieron en la respuesta → sesión activa.
  Future<void> _guardarSesion(String token, Map<String, dynamic> c) async {
    _api.setToken(token);
    _usuario = UsuarioFromJson.fromJson(c);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenPref, token);
  }

  // ── Perfil completo del cliente autenticado ────────────────
  // Mismo endpoint que usa la web para "Mi perfil" (GET /clientes/mi-perfil,
  // ver sicaber-backend/src/routes/index.js) — trae TODOS los campos del
  // cliente, no solo el subconjunto que devuelve el login.
  //
  // IMPORTANTE: si la petición falla (sin señal, 401, lo que sea), el
  // catch de abajo NO debe tocar _usuario — se deja tal cual estaba (lo
  // que ya vino del login) en vez de ponerlo en null. ProfileScreen llama
  // esto cada vez que se abre, así que un usuario=null aquí borraría de la
  // pantalla datos que sí eran válidos solo porque un refresco en segundo
  // plano falló.
  Future<void> cargarPerfilCompleto() async {
    try {
      final data = await _api.get('/clientes/mi-perfil');
      debugPrint('🔍 cliente (mi-perfil): $data');
      _usuario = UsuarioFromJson.fromJson(data as Map<String, dynamic>);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar el perfil completo: $e');
      // Deliberadamente no se toca _usuario ni se notifica: se conserva el
      // último perfil bueno que había en memoria.
    }
  }

  // ── Restaurar sesión al abrir la app ────────────────────────
  // Se llama una vez al arrancar (ver splash.dart). Si hay un token
  // guardado de un login anterior, lo reusa y trae el perfil completo en
  // vez de forzar al cliente a iniciar sesión de nuevo cada vez que abre
  // la app.
  Future<void> restaurarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenPref);
    if (token == null) return;
    _api.setToken(token);
    try {
      final data = await _api.get('/clientes/mi-perfil');
      _usuario = UsuarioFromJson.fromJson(data as Map<String, dynamic>);
      notifyListeners();
      // Fire-and-forget: la sesión ya quedó restaurada arriba; el
      // historial de pedidos puede tardar/fallar sin bloquear el arranque.
      cargarPedidos();
    } catch (_) {
      // Token vencido/inválido: no dejar la app con un token muerto puesto.
      await logout();
    }
  }

  // ── Recuperar contraseña ──────────────────────────────────
  Future<String?> solicitarRecuperacion(String correo) async {
    try {
      await _api.post('/auth/cliente/recuperar', {'correo': correo});
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión.';
    }
  }

  Future<String?> resetPassword(String correo, String token, String nuevaPassword) async {
    try {
      await _api.post('/auth/cliente/reset-password', {
        'correo': correo, 'token': token, 'nuevaPassword': nuevaPassword,
      });
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión.';
    }
  }

  // Antes esto solo tocaba el Usuario en memoria y nunca llamaba al
  // backend: los cambios "se guardaban" en la pantalla pero se perdían en
  // cuanto la app se cerraba o refrescaba, porque nunca llegaban a la base
  // de datos. Ahora llama a PUT /clientes/mi-perfil (mismo endpoint que
  // usa "Editar mis datos" en la web — ver actualizarMiPerfil() en
  // sicaber-backend/src/routes/index.js) y solo actualiza el estado local
  // si el backend confirma el guardado, devolviendo la fila ya actualizada.
  //
  // IMPORTANTE — tipoDoc/numeroDoc/departamento/municipio: ese endpoint
  // hace un UPDATE de la fila completa (sin COALESCE), así que cualquier
  // campo que no se mande en el body queda en null. EditProfileScreen
  // (igual que el formulario "Editar mis datos" de la propia web) no deja
  // editar esos 4 campos, así que si no se reenvían aquí tal cual estaban,
  // CUALQUIER edición de perfil (aunque solo sea cambiar el teléfono) los
  // borraba en silencio. No se exponen como campos editables — solo se
  // preservan con el valor que ya tenía _usuario.
  Future<String?> updateProfile(Map<String, String> data) async {
    if (_usuario == null) return 'No hay sesión activa';
    try {
      final row = await _api.put('/clientes/mi-perfil', {
        'nombre':       data['nombre'],
        'telefono':     data['telefono'],
        'direccion':    data['direccion'],
        'comuna':       data['comuna'],
        'tipoDoc':      _usuario!.tipoDoc,
        'numeroDoc':    _usuario!.numeroDoc,
        'departamento': _usuario!.departamento,
        'municipio':    _usuario!.municipio,
      });
      _usuario = UsuarioFromJson.fromJson(row as Map<String, dynamic>);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

  Future<void> logout() async {
    _usuario = null;
    _api.clearToken();
    _carrito.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenPref);
  }

  // ── Carrito ───────────────────────────────────────────────
  final List<CartItem> _carrito = [];
  List<CartItem> get carrito => List.unmodifiable(_carrito);
  double get cartTotal => _carrito.fold(0, (s, i) => s + i.subtotal);
  int    get cartCount => _carrito.fold(0, (s, i) => s + i.cantidad);

  // Si ya hay en el carrito una línea con el mismo producto Y exactamente
  // los mismos toppings/adiciones (comparados por id, sin importar el
  // orden), suma "cantidad" a esa línea en vez de crear una nueva. Si el
  // producto es el mismo pero la personalización difiere, queda como una
  // unidad aparte — cada combinación de extras es, para el carrito, un
  // ítem distinto.
  void addToCart(Producto p, {List<Topping> toppings = const [], List<Adicion> adiciones = const [], int cantidad = 1, int? comboId}) {
    final topIds = toppings.map((t) => t.id).toSet();
    final addIds = adiciones.map((a) => a.id).toSet();
    final idx = _carrito.indexWhere((i) =>
      i.producto.id == p.id &&
      i.toppings.map((t) => t.id).toSet().length == topIds.length &&
      i.toppings.every((t) => topIds.contains(t.id)) &&
      i.adiciones.map((a) => a.id).toSet().length == addIds.length &&
      i.adiciones.every((a) => addIds.contains(a.id)));

    if (idx != -1) {
      _carrito[idx].cantidad += cantidad;
    } else {
      final key = '${p.id}-${DateTime.now().millisecondsSinceEpoch}';
      _carrito.add(CartItem(cartKey: key, producto: p, cantidad: cantidad, toppings: toppings, adiciones: adiciones, comboId: comboId));
    }
    notifyListeners();
  }

  // ── Agregar un combo completo al carrito ──────────────────────
  // Los combos se venden "tal cual" (igual que el botón "+" de un combo en
  // la web): sin pantalla de personalización de toppings/adiciones. Se
  // envuelve en un Producto sintético con id negativo (nunca choca con un
  // id real de producto, que siempre es positivo) solo para poder reusar
  // CartItem/addToCart sin cambiarlos de raíz — lo que en verdad identifica
  // el combo de cara al backend es `comboId` (ver CartItem y
  // AppState.crearPedido).
  void addComboToCart(Combo combo) {
    final productoCombo = Producto(
      id: -combo.id, nombre: combo.nombre, descripcion: combo.descripcion,
      categoria: 'Combo', precio: combo.precio, imagen: combo.imagen);
    addToCart(productoCombo, comboId: combo.id);
  }

  void removeFromCart(String key) {
    _carrito.removeWhere((i) => i.cartKey == key);
    notifyListeners();
  }

  void updateQty(String key, int delta) {
    final idx = _carrito.indexWhere((i) => i.cartKey == key);
    if (idx == -1) return;
    _carrito[idx].cantidad += delta;
    if (_carrito[idx].cantidad <= 0) _carrito.removeAt(idx);
    notifyListeners();
  }

  void clearCart() { _carrito.clear(); notifyListeners(); }

  // ── Repetir un pedido anterior ("Repetir pedido" en el historial) ──
  // Vacía el carrito y vuelve a agregar los mismos productos/toppings/
  // adiciones de ese pedido — el pago se hace de cero en el checkout, no
  // se reutiliza nada del pedido original (ni método de pago, ni tipo de
  // entrega, ni comprobante). El caller es responsable de confirmar con
  // el cliente si hacía falta reemplazar un carrito que ya tenía algo.
  //
  // Cuando el producto/topping/adición todavía existe en el catálogo
  // vivo (AppState.productos/toppings/adiciones), se usa esa versión
  // actual (precio/imagen al día); si ya no existe — se borró, cambió de
  // categoría, etc. — se usa la copia que quedó guardada en el propio
  // pedido histórico.
  void repetirPedido(Pedido pedido) {
    clearCart();
    for (final item in pedido.items) {
      final productoVivo = _productos.firstWhere(
        (p) => p.id == item.producto.id, orElse: () => item.producto);
      final toppingsVivos = item.toppings
        .map((t) => _toppings.firstWhere((tv) => tv.id == t.id, orElse: () => t))
        .toList();
      final adicionesVivas = item.adiciones
        .map((a) => _adiciones.firstWhere((av) => av.id == a.id, orElse: () => a))
        .toList();
      addToCart(productoVivo, toppings: toppingsVivos, adiciones: adicionesVivas, cantidad: item.cantidad);
    }
  }

  // ── Pedidos ───────────────────────────────────────────────
  final List<Pedido> _pedidos = [];
  List<Pedido> get pedidos => List.unmodifiable(_pedidos);

  // ── Historial completo de pedidos del cliente ────────────────
  // GET /pedidos/mis-pedidos (filtrado en el backend por el cliente
  // autenticado — ver sicaber-backend/src/routes/index.js). A diferencia
  // de refrescarPedido() (que solo actualiza un pedido ya en _pedidos),
  // esto reemplaza la lista completa con TODO el historial real: pedidos
  // creados en otra sesión, otro dispositivo, o desde la web, que la
  // sesión actual de la app nunca vio nacer.
  Future<void> cargarPedidos() async {
    try {
      final data = await _api.get('/pedidos/mis-pedidos');
      final rows = (data as List).cast<Map<String, dynamic>>();
      _pedidos
        ..clear()
        ..addAll(rows.map((j) => PedidoFromJson.fromJson(j)));
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar el historial de pedidos: $e');
      // No se toca _pedidos: se conserva lo que ya había (p. ej. el pedido
      // recién creado en esta misma sesión) en vez de vaciar la pantalla
      // por un fallo momentáneo de red.
    }
  }

  Future<Pedido> crearPedido({
    required String metodoPago,
    String? notas,
    String? direccionEntrega,
    String tipoEntrega = 'local',
    String? comprobante, // imagen del pago en base64 (data URL)
    int? localId, // solo aplica si tipoEntrega == 'local' — ver GET /api/locales
    // true cuando el cliente eligió "Enviar por WhatsApp" en vez de subir
    // la imagen directo en la app — ver _AlternativaWhatsapp en checkout.dart.
    // El pedido igual nace en verificación de pago (el cajero debe revisar
    // el chat de WhatsApp del negocio), pero sin comprobante_img adjunto.
    bool comprobanteViaWhatsApp = false,
  }) async {
    // Con comprobante adjunto (subido en la app O avisado por WhatsApp) el
    // pedido nace en verificación de pago; solo si no hay ninguno de los
    // dos (ej. Efectivo) arranca directo en "pendiente" (pago confirmado).
    final estadoInicial = (comprobante != null || comprobanteViaWhatsApp)
        ? 'pendiente_verificacion' : 'pendiente';
    // Antes este error se ignoraba silenciosamente (catch (_) {}) y el pedido
    // se guardaba como "exitoso" localmente aunque el backend fallara.
    // Ahora se propaga para que la pantalla de checkout pueda mostrar el error real.
    //
    // IMPORTANTE: los nombres de campo de abajo (items/pago/direccion_alternativa/
    // comprobante_img/cliente_id) están verificados contra el POST /pedidos real
    // (sicaber-backend/src/routes/index.js). Antes este body mandaba
    // "productos"/"metodoPago"/"direccion"/"comprobante" — ninguno de esos
    // nombres existe en el destructuring del backend (que lee
    // items/pago/direccion_alternativa/comprobante_img), así que TODO pedido
    // creado desde la app perdía silenciosamente sus productos, su método de
    // pago, la dirección de entrega y la imagen del comprobante (el cajero
    // nunca veía nada que revisar en comprobante_img, aunque "comprobante"
    // sí quedara con el data URL completo metido ahí por error).
    final row = await _api.post('/pedidos', {
      'cliente_id': _usuario?.id,
      'cliente':    _usuario?.nombre ?? 'App móvil',
      'items': _carrito.map((i) => {
        // Un combo se manda como "combo-<id>" (string), igual que hace la
        // web (ver addToCart en Landing.jsx) — así el backend/historial
        // puede distinguirlo de un producto real con id numérico. Ver
        // CartItem.comboId / AppState.addComboToCart.
        'id': i.comboId != null ? 'combo-${i.comboId}' : i.producto.id,
        'nombre': i.producto.nombre,
        'precio': i.producto.precio, 'cantidad': i.cantidad,
        'precioTotal': i.subtotal,
        // Toppings tal como quedaron tras deseleccionar en el detalle del
        // producto — no todos los del producto, solo los activos en
        // _tops (ver product_detail.dart). Se manda el objeto completo
        // (id+nombre), mismo formato que ya acepta enriquecerItemsPedido
        // en el backend.
        'toppings':  i.toppings.map((t) => {'id': t.id, 'nombre': t.nombre}).toList(),
        'adiciones': i.adiciones.map((a) => {'id': a.id, 'nombre': a.nombre, 'precio': a.precio}).toList(),
      }).toList(),
      'total':  cartTotal,
      'notas':  notas, // el backend aún no tiene columna "notas": se manda igual por si se agrega, pero hoy se ignora en silencio.
      'tipo':   tipoEntrega,
      'origen': 'app',
      'estado': estadoInicial,
      'pago':   metodoPago,
      'direccion_alternativa': direccionEntrega,
      // El backend solo lee local_id cuando tipo == 'local' (ver POST
      // /pedidos) — mandarlo siempre no hace daño, pero solo importa ahí.
      if (tipoEntrega == 'local' && localId != null) 'local_id': localId,
      if (comprobante != null) 'comprobante_img': comprobante,
      if (comprobante != null) 'comprobante': 'Comprobante subido desde la app móvil',
      if (comprobante == null && comprobanteViaWhatsApp) 'comprobante': 'Comprobante enviado por WhatsApp',
    });
    final sync = PedidoSync.fromJson(row as Map<String, dynamic>);
    final pedido = Pedido(
      id: 'PED-${sync.backendId}', estado: sync.estado,
      fecha: sync.fecha.isNotEmpty ? sync.fecha : DateTime.now().toString().substring(0, 16),
      metodoPago: metodoPago,
      items: List.from(_carrito),
      total: cartTotal,
      notas: notas, direccionEntrega: direccionEntrega,
      tipoEntrega: tipoEntrega,
      backendId: sync.backendId,
      tieneComprobante: sync.tieneComprobante,
      comprobanteImgUrl: sync.comprobanteImgUrl,
    );
    _pedidos.insert(0, pedido);
    clearCart();
    return pedido;
  }

  // ── Sincronizar un pedido con su estado real en el backend ───
  // Se usa para el polling y el pull-to-refresh del detalle de pedido.
  Future<void> refrescarPedido(String id) async {
    final idx = _pedidos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final backendId = _pedidos[idx].backendId;
    if (backendId == null) return; // pedido nunca sincronizado con el backend
    try {
      final row = await _api.get('/pedidos/$backendId');
      final sync = PedidoSync.fromJson(row as Map<String, dynamic>);
      _pedidos[idx] = _pedidos[idx].copyWith(
        estado: sync.estado,
        fecha: sync.fecha.isNotEmpty ? sync.fecha : null,
        tieneComprobante: sync.tieneComprobante,
        comprobanteImgUrl: sync.comprobanteImgUrl,
      );
      notifyListeners();
    } catch (_) {
      // Fallo silencioso: el polling reintentará en el próximo ciclo y el
      // pull-to-refresh deja ver el estado anterior en vez de romper la UI.
    }
  }

  // ── Reenviar comprobante de pago tras un rechazo ──────────────
  // Reutiliza el mismo pedido (mismo backendId): actualiza su comprobante
  // y lo vuelve a poner en verificación para que el cajero lo revise.
  Future<void> reenviarComprobante(String id, String comprobanteBase64) async {
    final idx = _pedidos.indexWhere((p) => p.id == id);
    if (idx == -1) throw ApiException('Pedido no encontrado');
    final backendId = _pedidos[idx].backendId;
    if (backendId == null) throw ApiException('Pedido no sincronizado con el servidor');
    await _api.put('/pedidos/$backendId', {
      'comprobante': comprobanteBase64,
      'estado':      'pendiente_verificacion',
    });
    _pedidos[idx] = _pedidos[idx].copyWith(
      estado: 'pendiente_verificacion', tieneComprobante: true);
    notifyListeners();
  }

  // ── Solicitar devolución de uno o varios productos de un pedido ────
  // POST /api/devoluciones con el formato que soporta el backend:
  // { pedido_id, items: [{producto_id, cantidad}, ...], motivo } — el
  // cliente puede marcar varios productos del mismo pedido (checkboxes en
  // el diálogo, ver orders.dart), pero un solo motivo para toda la
  // solicitud, no uno por producto. Queda "pendiente" para que el staff la
  // revise — no cambia el estado del pedido por sí sola.
  Future<String?> solicitarDevolucion(String pedidoId, String motivo, List<CartItem> productos) async {
    if (productos.isEmpty) return 'Elige al menos un producto para devolver';
    final idx = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (idx == -1) return 'Pedido no encontrado';
    final backendId = _pedidos[idx].backendId;
    if (backendId == null) return 'Pedido no sincronizado con el servidor';
    try {
      await _api.post('/devoluciones', {
        'pedido_id': backendId,
        'items': productos.map((p) => {
          'producto_id': p.producto.id,
          'cantidad': p.cantidad,
        }).toList(),
        'motivo': motivo,
      });
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

}