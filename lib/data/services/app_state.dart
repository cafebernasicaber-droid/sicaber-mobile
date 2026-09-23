import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import 'api_service.dart';

const _kTokenPref = 'auth_token';

// El mismo client ID de tipo Web que ya usa sicaber-front (ver
// GOOGLE_CLIENT_ID en sicaber-back/.env y REACT_APP_CLIENT_ID en
// sicaber-front/.env) — el backend verifica el idToken con
// `audience: GOOGLE_CLIENT_ID`, así que aquí se pide ese mismo audience
// (serverClientId) en vez de crear uno nuevo por Android; solo hace falta
// registrar la huella SHA-1 de esta app bajo el mismo proyecto de Google
// Cloud, no un client ID Android aparte metido en el código.
const _googleServerClientId =
  '489568993256-10668jlj5jqo1t4ua9oohdbeq8shmrsd.apps.googleusercontent.com';

// ⚠️ AVISO — huella SHA-1 registrada hoy en Google Cloud Console: es la de
// DEPURACIÓN (`cd android && ./gradlew signingReport`, variant debug). El
// proyecto todavía firma su build "release" con esa misma key de debug (ver
// signingConfig en android/app/build.gradle.kts), así que hoy el login con
// Google funciona igual en debug y en el APK "release" actual. El día que
// se firme con una keystore de producción propia, hay que sacar el SHA-1 de
// ESA keystore y agregarlo como huella adicional al mismo cliente OAuth en
// Google Cloud Console — si no, el login con Google fallará (típicamente
// con "DEVELOPER_ERROR" o un cierre silencioso del diálogo) SOLO en los
// APK firmados con la key nueva, mientras que un build de debug seguirá
// funcionando y puede hacer parecer que el problema no existe.
final _googleSignIn = GoogleSignIn(serverClientId: _googleServerClientId);

// ── Registro con Google pendiente de completar ────────────────────
// POST /auth/cliente/google responde así cuando el correo de Google NO existe
// todavía: el backend no crea ninguna fila y entrega un token TEMPORAL de
// registro (JWT de ~20 min, sirve solo para /cliente/google/completar). Vive
// únicamente en memoria: NO se guarda en el teléfono, porque es un token que
// crea cuentas y guardarlo solo ahorraría un toque de Google al reabrir.
class RegistroGoogle {
  final String tokenRegistro;
  final String correo;
  final String nombre;
  const RegistroGoogle({required this.tokenRegistro, required this.correo, required this.nombre});

  // Clasifica la respuesta de /cliente/google. Devuelve un RegistroGoogle SOLO
  // si trae registroPendiente:true y un tokenRegistro utilizable; cualquier
  // otra forma (incluida la del backend viejo, que crea la cuenta al instante
  // y devuelve {token, cliente}) da null y el caller sigue el camino normal.
  // Es lo que hace que el mismo APK sirva antes y después de desplegar el
  // backend nuevo.
  static RegistroGoogle? desdeRespuesta(Map<String, dynamic> data) {
    if (data['registroPendiente'] != true) return null;
    final token = data['tokenRegistro'];
    if (token is! String || token.isEmpty) return null;
    final correo = data['correo'];
    final nombre = data['nombre'];
    return RegistroGoogle(
      tokenRegistro: token,
      correo: correo is String ? correo : '',
      nombre: nombre is String ? nombre : '');
  }
}

// Resultado de loginConGoogle(): exactamente uno de estos cuatro casos.
// Se distingue "cancelado" de "éxito" sin depender de mirar loggedIn después.
class ResultadoGoogle {
  final String? error;             // mensaje listo para mostrar
  final RegistroGoogle? pendiente; // correo nuevo: falta completar el registro
  final bool cancelado;            // el cliente cerró el diálogo de Google
  const ResultadoGoogle._({this.error, this.pendiente, this.cancelado = false});
  const ResultadoGoogle.exito()    : this._();
  const ResultadoGoogle.cancelado(): this._(cancelado: true);
  const ResultadoGoogle.conError(String e): this._(error: e);
  const ResultadoGoogle.registroPendiente(RegistroGoogle r): this._(pendiente: r);
}

// Resultado de completarRegistroGoogle().
class ResultadoCompletar {
  final String? error;
  // true cuando el formulario ya no sirve (token vencido/inválido, o el correo
  // se registró mientras tanto): hay que volver al login, no seguir corrigiendo.
  final bool reiniciarGoogle;
  const ResultadoCompletar({this.error, this.reiniciarGoogle = false});
  bool get exito => error == null;
}

// ── Resultado de verificar la cobertura de una dirección ──────────
// Antes esto era un record de dos campos (cubierto/motivo) y todo lo demás
// que devuelve POST /pedidos/verificar-cobertura se tiraba a la basura,
// incluida la dirección ya normalizada y la comuna. Eso hacía imposible
// mostrarle al cliente QUÉ dirección entendió el sistema.
class CoberturaDireccion {
  final bool    cubierto;
  final String? motivo;     // 'fuera_de_cobertura' | 'no_geocodificada' | 'servicio_no_disponible'
  final String? sede;       // local asignado cuando hay cobertura
  final String? mensaje;    // texto listo para mostrar que arma el backend
  final String? direccionNormalizada; // cómo quedó ubicada en el mapa
  final int?    comuna;

  const CoberturaDireccion({
    required this.cubierto, this.motivo, this.sede, this.mensaje,
    this.direccionNormalizada, this.comuna,
  });

  factory CoberturaDireccion.fromJson(Map<String, dynamic> j) {
    final detalle = j['detalle'] is Map ? Map<String, dynamic>.from(j['detalle'] as Map) : null;
    final comunaRaw = detalle?['comuna'];
    return CoberturaDireccion(
      cubierto: j['cubierto'] == true,
      motivo:   j['motivo'] as String?,
      sede:     j['sede'] as String?,
      mensaje:  j['mensaje'] as String?,
      direccionNormalizada: detalle?['formatted'] as String?,
      comuna: comunaRaw is num ? comunaRaw.toInt() : int.tryParse('${comunaRaw ?? ''}'),
    );
  }

  /// Ni cubierta ni rechazada en firme: hay que confirmar el local a mano.
  /// Cubre tanto "no se pudo ubicar en el mapa" como "el servicio de mapas
  /// no responde" — dos causas distintas, misma salida para el cliente.
  bool get requiereSeleccionManual =>
      !cubierto && (motivo == 'no_geocodificada' || motivo == 'servicio_no_disponible');

  /// Rechazo firme: la dirección se ubicó y quedó fuera de comuna 8/9.
  bool get fueraDeCobertura => !cubierto && motivo == 'fuera_de_cobertura';
}

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
  List<Promocion>  _promociones  = [];
  List<Local>      _locales      = [];
  List<MetodoPago> _metodosPago  = [];

  List<Producto>   get productos    => _productos;
  List<Adicion>    get adiciones    => _adiciones;
  List<Topping>    get toppings     => _toppings;
  List<Categoria>  get categorias   => _categorias;
  List<Combo>      get combos       => _combos;
  List<Promocion>  get promociones  => _promociones;
  List<Local>      get locales      => _locales;
  List<MetodoPago> get metodosPago  => _metodosPago;
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

  // GET /api/metodos-pago (pública, sin auth, solo activo=true) — métodos
  // de pago con QR configurados desde el admin, que el checkout ofrece
  // SOLO para domicilio (ver CheckoutScreen._opcionesPago en cart.dart).
  // Igual que cargarLocales(), aparte de cargarDatos() porque el checkout
  // la necesita justo al abrir el paso de pago, sin depender de que ya
  // haya corrido la carga general del catálogo.
  //
  // El filtro por nombre "efectivo" reproduce el mismo criterio que usa la
  // web (Landing.jsx): en la tabla `metodos_pago` puede existir una fila
  // literalmente llamada "efectivo" (dato de prueba ya activo en el admin)
  // que duplicaría la opción fija "Efectivo contraentrega" que el propio
  // checkout arma aparte — no es un método más de esta lista.
  Future<void> cargarMetodosPago() async {
    try {
      final data = await _api.get('/metodos-pago');
      _metodosPago = (data as List)
          .map((j) => MetodoPagoFromJson.fromJson(j))
          .where((m) => m.nombre.trim().toLowerCase() != 'efectivo')
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ No se pudieron cargar los métodos de pago: $e');
    }
  }

  // Nombres EXACTOS de los dos locales que POST /pedidos acepta como
  // "zona_manual" cuando una dirección no se pudo geocodificar (ver
  // crearPedido) — el backend los compara con igualdad de texto estricta
  // (zonaManualFinal !== 'Local Villa Liliam' && ... !== 'Local 3
  // Esquinas'), así que van fijos acá en vez de salir de GET /locales (esa
  // lista puede tener más locales que no son puntos de referencia válidos
  // para este mecanismo puntual).
  static const localesReferenciaCobertura = ['Local Villa Liliam', 'Local 3 Esquinas'];

  // ── Verificar cobertura de domicilio por dirección ────────────
  // POST /pedidos/verificar-cobertura — mismo endpoint que ya usa el
  // checkout de la web (PasarelaPago en Landing.jsx): hace geocoding real
  // de la dirección y la compara contra las zonas de cobertura (comuna 8 y
  // 9 de Medellín) — no es un simple match de texto contra el perfil.
  // Devuelve también `motivo` porque el mismo geocodificador que usa POST
  // /pedidos tiene 3 resultados posibles, no solo sí/no:
  //   • cubierto=true                        → dentro de comuna 8/9.
  //   • motivo='no_geocodificada'             → no se pudo ubicar en el
  //     mapa (común en comuna 8/9); NO es un rechazo firme — al confirmar
  //     el pedido, el backend pedirá elegir a mano cuál local queda más
  //     cerca (ver crearPedido/zonaManual).
  //   • motivo='fuera_de_cobertura' (u otro)  → rechazo firme.
  // Puede lanzar ApiException (ej. dirección muy corta → 400, o el
  // servicio de geocodificación falló → 502); el checkout trata cualquier
  // falla como "no se pudo verificar" y deja continuar igual que la web
  // (el backend la vuelve a validar como última barrera al crear el
  // pedido), en vez de bloquear al cliente por un problema del servicio.
  //
  // Devuelve además lo que el backend RESOLVIÓ de la dirección, que antes
  // se descartaba: la dirección normalizada tal como quedó ubicada en el
  // mapa, la comuna y la sede asignada. Mostrárselo al cliente es lo que
  // permite que se dé cuenta de que escribió "Calle 45" y el sistema
  // entendió otra cosa — el requisito de "garantizar que la dirección
  // mostrada corresponda a la ingresada" no se puede cumplir si la app
  // nunca enseña qué entendió el servidor.
  Future<CoberturaDireccion> verificarCobertura(String direccion) async {
    final data = await _api.post('/pedidos/verificar-cobertura', {'direccion': direccion});
    return CoberturaDireccion.fromJson(data as Map<String, dynamic>);
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
    // Ojo: esto NO es una validación de formato (esa solo aplica al crear o
    // cambiar contraseña, ver validarPassword/passwordPolicy.js) — es solo
    // "no me mandes el campo vacío". Un mínimo de longitud acá rompería el
    // login de cualquier cuenta creada ANTES de la política vigente de
    // 10-20 caracteres (incluida cualquier contraseña corta ya existente).
    if (password.isEmpty) return 'Ingresa tu contraseña';
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

  // ── Login con Google ────────────────────────────────────────
  // Reutiliza el MISMO endpoint que ya usa la web (POST /auth/cliente/google,
  // ver sicaber-back/src/routes/auth.js). Dos respuestas posibles:
  //
  //  • Correo YA registrado → {token, cliente}, igual que /auth/cliente/login:
  //    basta con _guardarSesion() de siempre. Si es una cuenta normal con ese
  //    correo, el backend la vincula por correo sin rechazar ni duplicar.
  //  • Correo NUEVO → {registroPendiente:true, tokenRegistro, correo, nombre}:
  //    el backend NO creó nada. AQUÍ NO SE GUARDA SESIÓN: se devuelve el
  //    pendiente para que la pantalla abra "Completa tu cuenta" y la sesión
  //    recién se guarde tras completarRegistroGoogle() con éxito.
  //
  // Defensivo a propósito: si la respuesta NO trae registroPendiente:true
  // (backend anterior, que creaba la cuenta al instante), se trata como login
  // normal. Así el mismo APK sirve antes y después de desplegar el backend.
  Future<ResultadoGoogle> loginConGoogle() async {
    try {
      final cuenta = await _googleSignIn.signIn();
      if (cuenta == null) return const ResultadoGoogle.cancelado(); // cerró el diálogo: no es un error
      final auth = await cuenta.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return const ResultadoGoogle.conError('No se pudo obtener la sesión de Google. Intenta de nuevo.');
      final data = await _api.post('/auth/cliente/google', {'token': idToken}) as Map<String, dynamic>;

      final pendiente = RegistroGoogle.desdeRespuesta(data);
      if (pendiente != null) return ResultadoGoogle.registroPendiente(pendiente);

      await _guardarSesion(data['token'] as String, data['cliente'] as Map<String, dynamic>);
      cargarPedidos();
      return const ResultadoGoogle.exito();
    } on ApiException catch (e) {
      return ResultadoGoogle.conError(e.message);
    } catch (_) {
      return const ResultadoGoogle.conError('No se pudo iniciar sesión con Google. Intenta de nuevo.');
    }
  }

  // ── Completar el registro iniciado con Google ────────────────
  // POST /auth/cliente/google/completar — UNA sola llamada con los cuatro
  // datos que Google no da. El correo NO viaja: el backend lo saca del token
  // que él mismo firmó. Solo si responde 201 se guarda la sesión (con el
  // mismo _guardarSesion de siempre): jamás una sesión a medias.
  Future<ResultadoCompletar> completarRegistroGoogle({
    required String tokenRegistro,
    required String password,
    required String tipoDoc,
    required String numeroDoc,
    required String telefono,
  }) async {
    try {
      final data = await _api.post('/auth/cliente/google/completar', {
        'tokenRegistro': tokenRegistro,
        'password': password,
        'tipoDoc': tipoDoc,
        'numeroDoc': numeroDoc,
        'telefono': telefono,
      }) as Map<String, dynamic>;
      await _guardarSesion(data['token'] as String, data['cliente'] as Map<String, dynamic>);
      cargarPedidos();
      return const ResultadoCompletar();
    } on ApiException catch (e) {
      // El formulario ya no sirve si el token venció o es inválido
      // (requiereReiniciarGoogle) o si ese correo ya tiene cuenta (409).
      final reiniciar = e.data?['requiereReiniciarGoogle'] == true ||
          e.motivo == 'correo_ya_registrado';
      if (reiniciar) descartarRegistroGoogle();
      return ResultadoCompletar(error: e.message, reiniciarGoogle: reiniciar);
    } catch (_) {
      return const ResultadoCompletar(error: 'Error de conexión. Verifica tu internet.');
    }
  }

  // Descarta el registro pendiente. No hay nada que borrar en el servidor
  // (no creó ninguna fila) ni en el teléfono (el token nunca se guardó): lo
  // único que hace falta es cerrar la sesión de Google del dispositivo. Sin
  // eso, Android recuerda la cuenta elegida y el siguiente "Continuar con
  // Google" entra directo con la misma — quien eligió la cuenta equivocada
  // no podría cambiarla.
  Future<void> descartarRegistroGoogle() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
  }

  // Se eliminaron register(), verificarCuenta() y reenviarCodigo(): el
  // registro tradicional ya no existe en backend/web (cuentas nuevas solo por
  // Google, ver loginConGoogle) y el PIN de 6 dígitos solo lo usaba ese flujo.

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
  // de datos. Ahora llama a PUT /clientes/mi-perfil (mismo endpoint que usa
  // "Editar mis datos" en la web — ver actualizarMiPerfil() en
  // sicaber-backend/src/routes/index.js) y solo actualiza el estado local
  // si el backend confirma el guardado, devolviendo la fila ya actualizada.
  //
  // IMPORTANTE — tipoDoc/numeroDoc: ese endpoint hace un UPDATE de la fila
  // completa (sin COALESCE), así que cualquier campo que no se mande en el
  // body queda en null. EditProfileScreen no deja editar esos 2 campos, así
  // que si no se reenvían aquí tal cual estaban, CUALQUIER edición de
  // perfil (aunque solo sea cambiar el teléfono) los borraba en silencio.
  // No se exponen como campos editables — solo se preservan con el valor
  // que ya tenía _usuario. (departamento/municipio/comuna/direccion ya no
  // existen como columnas de `clientes` en el backend — no hace falta
  // preservarlos porque ese endpoint ni siquiera los lee.)
  //
  // `correo` es OPCIONAL en el mapa: si no viene, el endpoint deja el
  // correo tal como está (antes ni siquiera se podía cambiar — ver
  // actualizarMiPerfil, que ahora sí lo acepta con validación de formato y
  // de duplicado, mismas reglas que el registro).
  Future<String?> updateProfile(Map<String, String> data) async {
    if (_usuario == null) return 'No hay sesión activa';
    try {
      final row = await _api.put('/clientes/mi-perfil', {
        'nombre':       data['nombre'],
        'telefono':     data['telefono'],
        'tipoDoc':      _usuario!.tipoDoc,
        'numeroDoc':    _usuario!.numeroDoc,
        if (data['correo'] != null) 'correo': data['correo'],
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
    String? comprobante, // imagen del pago en base64 (data URL) — se sube SIEMPRE dentro de la app
    // Texto que el OCR del dispositivo leyó de esa imagen (ver
    // services/ocr_service.dart). Es MATERIA PRIMA para que el backend
    // valide por su cuenta: la app no manda ninguna conclusión sobre el
    // monto, solo el texto. Si el OCR no pudo leer nada, va en null y el
    // backend deja el comprobante en revisión manual.
    String? comprobanteTexto,
    int? localId, // solo aplica si tipoEntrega == 'local' — ver GET /api/locales
    // Solo aplica a domicilio, y solo cuando el backend ya rechazó un
    // primer intento con 409/no_geocodificada: el cliente confirmó a mano
    // cuál de los dos locales de referencia le queda más cerca (ver
    // localesReferenciaCobertura/verificarCobertura) y se reintenta con
    // ese valor exacto en 'zona_manual'.
    String? zonaManual,
    // Nota opcional que solo tiene sentido para tipoEntrega=='local' (ej.
    // "efectivo exacto", "tarjeta física") — el backend la rechaza con 400
    // si se manda junto con 'domicilio' (ver metodo_pago_local en
    // sicaber-backend/src/routes/index.js), así que cart.dart nunca la
    // pasa fuera de ese caso.
    String? metodoPagoLocal,
  }) async {
    // Con comprobante adjunto el pedido nace en verificación de pago; sin
    // comprobante arranca directo en "pendiente" (pago confirmado) — solo
    // pasa con Efectivo, el único método que no exige comprobante.
    final estadoInicial = comprobante != null ? 'pendiente_verificacion' : 'pendiente';
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
      if (tipoEntrega == 'local' && metodoPagoLocal != null) 'metodo_pago_local': metodoPagoLocal,
      if (tipoEntrega == 'domicilio' && zonaManual != null) 'zona_manual': zonaManual,
      if (comprobante != null) 'comprobante_img': comprobante,
      if (comprobante != null) 'comprobante': 'Comprobante subido desde la app móvil',
      // El backend lo reanaliza por su cuenta y decide; ver
      // services/comprobante.js allá.
      if (comprobanteTexto != null && comprobanteTexto.trim().isNotEmpty)
        'comprobante_texto': comprobanteTexto,
    // subida: true → timeout largo. Un comprobante en base64 puede pesar
    // varios MB y con el timeout normal la subida se cortaba a mitad en
    // una red móvil lenta.
    }, subida: comprobante != null);
    final sync = PedidoSync.fromJson(row as Map<String, dynamic>);
    final pedido = Pedido(
      id: 'PED-${sync.backendId}', estado: sync.estado,
      fecha: sync.fecha.isNotEmpty ? sync.fecha : DateTime.now().toString().substring(0, 16),
      metodoPago: metodoPago,
      items: List.from(_carrito),
      // El total que vale es el que devolvió el BACKEND (el que él
      // recalculó y contra el que valida el comprobante), no el que
      // calculó el carrito. Si por cualquier motivo difirieran, mostrar el
      // del carrito dejaría al cliente viendo un número distinto del que
      // se le cobró y validó.
      total: parseNum(row['total_calculado'] ?? row['total']) > 0
          ? parseNum(row['total_calculado'] ?? row['total'])
          : cartTotal,
      notas: notas, direccionEntrega: direccionEntrega,
      tipoEntrega: tipoEntrega,
      backendId: sync.backendId,
      tieneComprobante: sync.tieneComprobante,
      comprobanteImgUrl: sync.comprobanteImgUrl ?? comprobante,
      estadoPago: sync.estadoPago,
      // El veredicto llega en la propia respuesta de creación
      // (comprobanteValidacion) — así el checkout puede decir de una vez
      // "comprobante verificado" o "queda en revisión".
      comprobanteValidacion: sync.comprobanteValidacion,
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
      // Se reconstruye el pedido COMPLETO, no solo cuatro campos: el
      // detalle necesita también el estado del pago, el veredicto del
      // comprobante, el estado de devolución y las cantidades ya devueltas
      // por línea. Antes se copiaban únicamente estado/fecha/comprobante, y
      // por eso una devolución aprobada o un comprobante rechazado nunca se
      // reflejaban en la pantalla aunque el backend ya los tuviera.
      final completo = PedidoFromJson.fromJson(row as Map<String, dynamic>);
      final anterior = _pedidos[idx];
      _pedidos[idx] = completo.copyWith(
        // Se conserva lo que solo existe en la copia local (el backend no
        // guarda "notas" en pedidos, y los ítems reconstruidos pierden
        // imagen/descripción del producto).
        notas: anterior.notas,
        items: completo.items.isNotEmpty ? completo.items : anterior.items,
      );
      notifyListeners();
    } catch (_) {
      // Fallo silencioso: el polling reintentará en el próximo ciclo y el
      // pull-to-refresh deja ver el estado anterior en vez de romper la UI.
    }
  }

  // ── Reenviar comprobante de pago tras un rechazo ──────────────
  // Reutiliza el mismo pedido (mismo backendId): sube el comprobante nuevo
  // y el backend lo vuelve a poner en verificación para que el cajero lo
  // revise (ver POST /pedidos/:id/comprobante, sicaber-back/src/routes/
  // index.js).
  //
  // BUG REAL CORREGIDO (ronda de seguridad del backend): esto usaba
  // PUT /pedidos/:id, que es el endpoint genérico de EDITAR un pedido
  // (cliente/tipo/total/items/sede/atendido_por...). El backend cerró un
  // hueco de autorización real ahí — antes cualquier Cliente autenticado
  // podía editar CUALQUIER pedido, no solo el suyo — bloqueando ese PUT
  // para el rol Cliente por completo (siempre 403, "Los clientes no pueden
  // editar un pedido"). Como resultado, reenviar un comprobante rechazado
  // dejó de funcionar para cualquier cliente real de la app, aunque nunca
  // se vio en pruebas hechas con un rol de staff.
  //
  // El backend ya tiene el reemplazo correcto: POST /pedidos/:id/comprobante
  // es el endpoint dedicado a EXACTAMENTE este caso (adjuntar/reemplazar
  // SOLO el comprobante), permite el rol Cliente en su propio pedido, y
  // corre la misma validación (monto contra el total real, anti-
  // reutilización por hash y por número de aprobación) — es también el que
  // ya usa la web para este mismo flujo.
  Future<void> reenviarComprobante(String id, String comprobanteBase64, {String? comprobanteTexto}) async {
    final idx = _pedidos.indexWhere((p) => p.id == id);
    if (idx == -1) throw ApiException('Pedido no encontrado');
    final backendId = _pedidos[idx].backendId;
    if (backendId == null) throw ApiException('Pedido no sincronizado con el servidor');
    await _api.post('/pedidos/$backendId/comprobante', {
      'comprobante_img': comprobanteBase64,
      if (comprobanteTexto != null && comprobanteTexto.trim().isNotEmpty)
        'comprobante_texto': comprobanteTexto,
    }, subida: true);
    // Se relee del backend en vez de suponer el resultado: el comprobante
    // pudo quedar verificado, en revisión, o rechazado por valor — y eso
    // solo lo sabe el servidor.
    await refrescarPedido(id);
  }

  // ── Solicitar devolución de uno o varios productos de un pedido ────
  // POST /api/devoluciones con el formato que soporta el backend:
  // { pedido_id, items: [{producto_id, cantidad}, ...], motivo } — el
  // cliente puede marcar varios productos del mismo pedido (checkboxes en
  // el diálogo, ver orders.dart), pero un solo motivo para toda la
  // solicitud, no uno por producto. Queda "pendiente" para que el staff la
  // revise — no cambia el estado del pedido por sí sola.
  //
  // DOS BUGS REALES CORREGIDOS ACÁ:
  //
  //  1. Se mandaba `producto_id`. El backend resuelve la línea a devolver
  //     por `item_index` O por `producto_id`, y `producto_id` falla en dos
  //     casos que pasan de verdad:
  //       • un COMBO no tiene id de producto — en `pedidos.items` se guarda
  //         como "combo-5", y al reconstruir el historial la app lo dejaba
  //         en 0, así que el backend respondía "ese producto no está en el
  //         pedido" y NINGUNA devolución de un combo se podía registrar;
  //       • el mismo producto pedido dos veces con toppings distintos son
  //         dos líneas y producto_id no distingue cuál se devuelve.
  //     Ahora se manda `item_index`, que identifica la línea exacta.
  //
  //  2. No se refrescaba el pedido después. La devolución quedaba
  //     registrada en el backend pero la pantalla seguía mostrando el
  //     pedido como si nada hubiera pasado — el cliente no tenía forma de
  //     ver que su solicitud existía.
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
          // item_index cuando se conoce (pedidos traídos del backend);
          // producto_id solo como respaldo para un pedido que todavía vive
          // únicamente en memoria de esta sesión.
          if (p.itemIndex != null) 'item_index': p.itemIndex,
          if (p.itemIndex == null) 'producto_id': p.producto.id,
          // Nunca más de lo que queda por devolver de esa línea.
          'cantidad': p.cantidadDevolvible > 0 ? p.cantidadDevolvible : p.cantidad,
        }).toList(),
        'motivo': motivo,
      });
      // Relee el pedido: trae estado_devolucion y las cantidades ya
      // devueltas por línea, que es lo que la pantalla necesita para
      // mostrar el resultado.
      await refrescarPedido(pedidoId);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

  // Devoluciones ya solicitadas para un pedido, con su estado real
  // ('pendiente' | 'aprobada' | 'rechazada') y el motivo del rechazo si lo
  // hay. GET /devoluciones ya filtra por el cliente autenticado.
  // Sin esto, el cliente mandaba la solicitud y no volvía a saber nunca más
  // en qué quedó.
  Future<List<Map<String, dynamic>>> devolucionesDePedido(String pedidoId) async {
    final idx = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (idx == -1) return const [];
    final backendId = _pedidos[idx].backendId;
    if (backendId == null) return const [];
    try {
      final data = await _api.get('/devoluciones');
      return (data as List)
          .cast<Map<String, dynamic>>()
          .where((d) => d['pedido_id'] == backendId)
          .toList();
    } catch (e) {
      debugPrint('⚠️ No se pudieron cargar las devoluciones: $e');
      return const [];
    }
  }
}