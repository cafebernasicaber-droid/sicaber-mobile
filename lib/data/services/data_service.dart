// ── DATOS ESTÁTICOS DEL NEGOCIO (no vienen de la API) ─────────
// Productos, adiciones, toppings, categorías, combos y promociones
// ahora se cargan desde PostgreSQL vía AppState.instance.cargarDatos()

// ── CONSTANTES DEL NEGOCIO ────────────────────────────────────
const comunasDisponibles = ['Comuna 8 - Villa Hermosa', 'Comuna 9 - Buenos Aires'];
// Igual que la web (PasarelaPago en Landing.jsx, sin Daviplata):
// estos son los únicos 3 métodos de pago que el negocio acepta hoy.
// Estas son las etiquetas que ve el cliente (con mayúscula inicial); el
// valor real que se manda al backend en el POST /pedidos es la versión en
// minúscula (ver _metodo.toLowerCase() en cart.dart) — mismos ids que usa
// METODOS en Landing.jsx ('efectivo'/'nequi'/'transferencia').
const metodosPago = ['Efectivo', 'Nequi', 'Transferencia'];
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