import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';

// ── PERFIL ────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override void initState() {
    super.initState();
    // Refresca contra el backend cada vez que se entra a esta pantalla, en
    // vez de confiar en lo que quedó en memoria desde el login: si el
    // perfil se editó desde la web, el móvil lo refleja aquí.
    AppState.instance.cargarPerfilCompleto();
  }

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
      final u = AppState.instance.usuario;
      // cargarPerfilCompleto() está en curso (o el usuario entró a esta
      // ruta sin sesión activa todavía): no hay datos que mostrar aún, así
      // que se evita el "!" que tronaba con "Unexpected null value" y se
      // muestra un loader en su lugar. cargarPerfilCompleto() nunca deja
      // _usuario en null si la petición falla (conserva lo que ya había
      // del login) — esta pantalla solo puede ver null si aún no hubo
      // ningún login exitoso en esta sesión de la app.
      if (u == null) {
        return Scaffold(backgroundColor: C.bg,
          appBar: AppBar(title: const Text('Mi perfil'), backgroundColor: C.surface),
          body: const Center(child: CircularProgressIndicator(color: C.green)));
      }
      return Scaffold(backgroundColor: C.bg,
        appBar: AppBar(title: const Text('Mi perfil'), backgroundColor: C.surface),
        body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          // ── Avatar ──
          Container(width: 92, height: 92,
            decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle,
              border: Border.all(color: C.green.withOpacity(0.4), width: 2)),
            child: Center(child: Text(u.nombre.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: C.green)))),
          const SizedBox(height: 12),
          Text(u.nombre, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.text)),
          Text(u.correo, style: TextStyle(fontSize: 14, color: C.textSec)),
          const SizedBox(height: 28),

          // ── Datos (mismos campos y orden que "Mi perfil" en la web) ──
          _InfoCard(items: [
            _IR(Icons.phone_outlined,          'Teléfono',      u.telefono ?? '—'),
            _IR(Icons.location_on_outlined,    'Dirección',     u.direccion ?? '—'),
            _IR(Icons.map_outlined,            'Comuna',        u.comuna ?? '—'),
            _IR(Icons.explore_outlined,        'Ubicación',
              (u.municipio != null && u.departamento != null) ? '${u.municipio}, ${u.departamento}' : '—'),
            _IR(Icons.badge_outlined,          'Documento',
              (u.tipoDoc != null && u.numeroDoc != null) ? '${u.tipoDoc}: ${u.numeroDoc}' : '—'),
            _IR(Icons.calendar_today_outlined, 'Miembro desde', fmtFechaEs(u.fechaRegistro)),
          ]),
          const SizedBox(height: 16),

          // ── Opciones ──
          _MenuCard(items: [
            _MI(Icons.receipt_long_outlined, 'Mis pedidos',       () => context.go('/pedidos')),
            _MI(Icons.edit_outlined,          'Editar perfil',    () => context.push('/perfil/editar')),
          ]),
          const SizedBox(height: 16),

          // ── Apariencia ──
          const _ThemeSwitchCard(),
          const SizedBox(height: 16),

          // ── Info café ──
          _InfoCard(title: 'Café Don Berna', items: [
            _IR(Icons.location_on_outlined, 'Dirección', contacto['direccion']!),
            _IR(Icons.schedule_outlined,    'Horario',   contacto['horario']!),
            _IR(Icons.phone_outlined,       'Teléfono',  contacto['telefono']!),
          ]),
          const SizedBox(height: 20),

          // ── Cerrar sesión ──
          SizedBox(width: double.infinity, height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.red, side: BorderSide(color: C.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () { AppState.instance.logout(); context.go('/login'); },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 40),
        ])));
    });
}

class _ThemeSwitchCard extends StatelessWidget {
  const _ThemeSwitchCard();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ThemeController.instance,
    builder: (context, _) {
      final dark = ThemeController.instance.isDark;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            onTap: () => ThemeController.instance.toggle(),
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: C.green)),
            title: Text('Modo ${dark ? 'oscuro' : 'claro'}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
            subtitle: Text(dark ? 'Activado' : 'Desactivado',
              style: TextStyle(fontSize: 12, color: C.textSec)),
            trailing: Switch(
              value: dark,
              activeColor: C.green,
              onChanged: (v) => ThemeController.instance.setDark(v)),
          ),
        ),
      );
    },
  );
}

class _InfoCard extends StatelessWidget {
  final List<_IR> items; final String? title;
  const _InfoCard({required this.items, this.title});

  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text(title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.textSec))),
      ...items.asMap().entries.map((e) => Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Icon(e.value.icon, size: 18, color: C.textMut),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.value.label, style: TextStyle(fontSize: 11, color: C.textMut, letterSpacing: 0.5)),
              Text(e.value.value, style: TextStyle(fontSize: 14, color: C.text, fontWeight: FontWeight.w500))])),
          ])),
        if (e.key < items.length - 1) Divider(height: 1, color: C.border, indent: 16, endIndent: 16),
      ])),
    ]));
}

class _MenuCard extends StatelessWidget {
  final List<_MI> items;
  const _MenuCard({required this.items});

  @override Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: items.asMap().entries.map((e) => Column(children: [
        ListTile(
          onTap: e.value.onTap,
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(e.value.icon, size: 18, color: C.green)),
          title: Text(e.value.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
          trailing: Icon(Icons.chevron_right, color: C.textMut)),
        if (e.key < items.length - 1) Divider(height: 1, color: C.border, indent: 16, endIndent: 16),
      ])).toList()),
    ));
}

class _IR { final IconData icon; final String label, value; const _IR(this.icon, this.label, this.value); }
class _MI { final IconData icon; final String label; final VoidCallback onTap; const _MI(this.icon, this.label, this.onTap); }


// ── EDITAR PERFIL ─────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override State<EditProfileScreen> createState() => _EditState();
}

class _EditState extends State<EditProfileScreen> {
  final _nombre    = TextEditingController();
  final _telefono  = TextEditingController();
  final _dir       = TextEditingController();
  String? _comuna, _error;
  bool _loading = false;

  @override void initState() {
    super.initState();
    final u = AppState.instance.usuario!;
    _nombre.text   = u.nombre;
    _telefono.text = u.telefono ?? '';
    _dir.text      = u.direccion ?? '';
    _comuna        = u.comuna;
  }

  @override void dispose() { _nombre.dispose(); _telefono.dispose(); _dir.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.updateProfile({
      'nombre': _nombre.text.trim(), 'telefono': _telefono.text.trim(),
      'direccion': _dir.text.trim(), 'comuna': _comuna ?? ''});
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
      return;
    }
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Perfil actualizado ✓'), backgroundColor: C.green));
    Navigator.pop(context);
  }

  Widget _tf(String label, TextEditingController c, IconData icon, {TextInputType type = TextInputType.text}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
      const SizedBox(height: 8),
      TextField(controller: c, keyboardType: type, style: TextStyle(color: C.text),
        decoration: InputDecoration(prefixIcon: Icon(icon, color: C.textMut, size: 20))),
      const SizedBox(height: 14)]);

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: C.bg,
    appBar: AppBar(title: const Text('Editar perfil'), backgroundColor: C.surface),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.red.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.warning_amber_outlined, color: C.red, size: 18), const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: const TextStyle(color: C.red, fontSize: 13))),
          ])),
      _tf('Nombre completo', _nombre, Icons.person_outline),
      _tf('Teléfono', _telefono, Icons.phone_outlined, type: TextInputType.phone),
      _tf('Dirección', _dir, Icons.home_outlined),
      Text('Comuna', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _comuna, dropdownColor: C.surf2, style: TextStyle(color: C.text, fontSize: 14),
        decoration: const InputDecoration(hintText: 'Seleccionar...'),
        items: comunasDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _comuna = v)),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: _loading ? null : _save,
        child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Guardar cambios')),
      const SizedBox(height: 40),
    ])),
  );
}
