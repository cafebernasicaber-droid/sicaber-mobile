// ── DATOS ESTÁTICOS DEL NEGOCIO (no vienen de la API) ─────────
// Productos, adiciones, toppings, categorías, combos y promociones
// ahora se cargan desde PostgreSQL vía AppState.instance.cargarDatos()

// ── CONSTANTES DEL NEGOCIO ────────────────────────────────────
// El backend solo entiende 3 valores de pago en la columna `pedidos.pago`
// ('efectivo'/'nequi'/'transferencia' — ver METODOS_PAGO_VALIDOS en
// sicaber-backend/src/routes/index.js), pero la lista de métodos que el
// cliente puede ELEGIR ya no es fija: la administra el admin desde
// "Métodos de pago" (tabla `metodos_pago`, con descripción/llave y QR —
// ver GET /metodos-pago) y el checkout la trae en vivo (AppState.
// cargarMetodosPago/AppState.metodosPago), igual que ya hace la web
// (METODOS en Landing.jsx). CUALQUIER método dinámico que el admin cargue
// se manda al backend como 'transferencia' (igual que la web: el backend
// no distingue Nequi de otra cuenta más allá de "necesita comprobante"),
// así que esta etiqueta es la única forma de mostrar algo más específico
// que "Transferencia" en el HISTORIAL de un pedido ya creado — no se puede
// recuperar cuál método dinámico exacto se usó una vez guardado el pedido
// (mismo límite que tiene el propio panel admin, ver METODOS_PAGO_LABEL en
// PedidosPage.jsx: ahí también se muestra "Llave Bancolombia" genérico
// para cualquier pedido con pago='transferencia').
const metodosPagoLabels = {
  'Efectivo': 'Efectivo',
  'Nequi': 'Nequi',
  'Transferencia': 'Llave Bancolombia',
};

const tiposDoc = ['Cédula de Ciudadanía', 'Tarjeta de Identidad', 'Pasaporte', 'Cédula de Extranjería'];

const contacto = {
  'direccion':   'Calle 10A #52-44, en frente del D1',
  'horario':     'Lun–Sáb 7am–8pm · Dom 8am–6pm',
  'telefono':    '324 644 4774',
  'correo':      'sebastiancastano9704@gmail.com',
  'propietario': 'Sebastian Castaño Palacio',
  'municipio':   'Medellín, Antioquia',
};

// ── WHATSAPP DEL NEGOCIO ─────────────────────────────────────
// Mismo número que contacto['telefono'], pero en formato E.164 sin
// espacios ni signos — lo que exige el enlace wa.me. +57 = Colombia.
final String telefonoWhatsappNegocio =
  '57${contacto['telefono']!.replaceAll(RegExp(r'\D'), '')}';

// Arma el enlace "https://wa.me/<numero>?text=<mensaje>" para abrir un chat
// de WhatsApp con el negocio ya con un mensaje prellenado (usado como
// alternativa a subir el comprobante directo en la app — ver checkout.dart).
Uri whatsappUrl(String mensaje) => Uri.parse(
  'https://wa.me/$telefonoWhatsappNegocio?text=${Uri.encodeComponent(mensaje)}');

// ── VALIDACIÓN DE CONTRASEÑA ──────────────────────────────────
// 10-20 caracteres, con al menos una mayúscula, una minúscula, un número y
// un carácter especial — igual que la web. Se usa tanto al registrarse
// como en cualquier cambio de contraseña (recuperar/reset).
final RegExp passwordRegex =
  RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{10,20}$');

const passwordRequisitosMsg =
  'La contraseña debe tener entre 10 y 20 caracteres, con al menos una '
  'mayúscula, una minúscula, un número y un carácter especial.';

String? validarPassword(String pass) =>
  passwordRegex.hasMatch(pass) ? null : passwordRequisitosMsg;

// ── TIPO DE DOCUMENTO PARA "COMPLETAR REGISTRO" (Google) ──────────
// Mismos valores que tiposDoc + "Otros", igual que el formulario de la web
// (Landing.jsx). "Otros" NUNCA viaja al backend: POST /auth/cliente/google/
// completar lo rechaza con 400 ("Debes especificar el tipo de documento").
// Lo que se manda es el texto que el cliente escribe en "¿Cuál?" (ver
// CompletarRegistroScreen), exactamente como hace la web.
const tipoDocOtros = 'Otros';
const tiposDocConOtros = [...tiposDoc, tipoDocOtros];

// Tope de la columna clientes.tipo_doc (VARCHAR(60)). La web no lo limita y
// un texto más largo reventaría en la base con un 500; acá se corta antes.
const tipoDocMaxCaracteres = 60;

// ── VALIDACIÓN DE TELÉFONO (misma regla que el backend) ───────────
// Espejo de errorTelefono en sicaber-back/src/config/validaciones.js, pero
// OBLIGATORIO (en "completar registro" el teléfono es requerido). Acepta el
// prefijo +57 y espacios, guiones o paréntesis; quitados esos separadores
// deben quedar entre 7 (fijo) y 10 (celular) dígitos. No se usa una regla
// más estricta (p. ej. 10 exactos) porque rechazaría fijos que el backend sí
// acepta: manda el backend.
String? validarTelefono(String valor) {
  final limpio = valor.trim();
  if (limpio.isEmpty) return 'Escribe tu teléfono.';
  final soloDigitos = limpio
      .replaceFirst(RegExp(r'^\+?57\s*'), '')
      .replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\d+$').hasMatch(soloDigitos)) {
    return 'El teléfono solo puede contener números (y opcionalmente el prefijo +57, espacios, guiones o paréntesis).';
  }
  if (soloDigitos.length < 7 || soloDigitos.length > 10) {
    return 'El teléfono debe tener entre 7 y 10 dígitos.';
  }
  return null;
}

// ── VALIDACIÓN DE NÚMERO DE DOCUMENTO (misma regla que el backend) ──
// Solo dígitos y máximo 10 (errorDocumento en validaciones.js). Ojo: el
// backend NO revisa duplicados (no hay UNIQUE en clientes.numero_doc), así
// que la app tampoco inventa ese error.
String? validarNumeroDocumento(String valor) {
  final limpio = valor.trim();
  if (limpio.isEmpty) return 'Escribe tu número de documento.';
  if (!RegExp(r'^\d+$').hasMatch(limpio)) return 'El número de documento solo puede contener números.';
  if (limpio.length > 10) return 'El número de documento no puede tener más de 10 dígitos (tiene ${limpio.length}).';
  return null;
}

// ── VALIDACIÓN DE CORREO ──────────────────────────────────────
// Misma regla mínima que ya usaba el registro (antes vivía inline en
// AppState.register: "exige un @") — se extrajo acá para que "Editar
// perfil" (donde ahora también se puede cambiar el correo) valide
// exactamente igual, sin duplicar la regla en dos lugares.
String? validarCorreo(String correo) =>
  correo.contains('@') ? null : 'Correo inválido';

// ── HELPERS ──────────────────────────────────────────────────
String fmt(double n) => '\$${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';

const _mesesEs = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

// Formatea una fecha ISO (ej. "fechaRegistro" del backend) igual que la
// web: "3 de agosto de 2026". Sin depender de inicializar locales de intl
// (evita el LocaleDataException si nadie llamó initializeDateFormatting).
String fmtFechaEs(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return fmtFechaEsDate(d);
}

// Mismo formato que fmtFechaEs, pero partiendo de un DateTime ya parseado
// (ej. Combo.fechaInicio/fechaFin) en vez de un string ISO crudo.
String fmtFechaEsDate(DateTime d) => '${d.day} de ${_mesesEs[d.month - 1]} de ${d.year}';