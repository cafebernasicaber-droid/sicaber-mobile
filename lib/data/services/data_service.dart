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
  return '${d.day} de ${_mesesEs[d.month - 1]} de ${d.year}';
}