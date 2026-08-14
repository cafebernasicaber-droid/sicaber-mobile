import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';
import '../../widgets/common/animations.dart';

Widget _label(String t) => Padding(padding: EdgeInsets.only(bottom: 8),
  child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)));

Widget _err(String msg) => Container(
  margin: EdgeInsets.only(bottom: 16), padding: EdgeInsets.all(12),
  decoration: BoxDecoration(color: C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
    border: Border.all(color: C.red.withOpacity(0.3))),
  child: Row(children: [Icon(Icons.warning_amber_outlined, color: C.red, size: 18), SizedBox(width: 8),
    Expanded(child: Text(msg, style: TextStyle(color: C.red, fontSize: 13)))]));

// ── LOGIN ─────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}
class _LoginState extends State<LoginScreen> {
  final _identificador = TextEditingController();
  final _pass   = TextEditingController();
  bool _obs = true, _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.login(_identificador.text.trim(), _pass.text);
    if (!mounted) return;
    if (err != null) { setState(() { _loading = false; _error = err; }); return; }
    context.go('/home');
  }

  @override void dispose() { _identificador.dispose(); _pass.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: FadeSlideIn(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 40),
        Center(child: Column(children: [
          Container(width: 80, height: 80, padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle,
              border: Border.all(color: C.green.withOpacity(0.3))),
            child: Image.asset('assets/images/logo_blanco.png',
              color: C.green, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.coffee, color: C.green, size: 40))),
          SizedBox(height: 18),
          Text('Bienvenido de nuevo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
          SizedBox(height: 6),
          Text('Inicia sesión para continuar', style: TextStyle(fontSize: 14, color: C.textSec)),
        ])),
        SizedBox(height: 44),
        if (_error != null) _err(_error!),
        _label('Correo o usuario'),
        TextField(controller: _identificador, keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: C.text),
          decoration: InputDecoration(hintText: 'tucorreo@ejemplo.com o tu usuario',
            prefixIcon: Icon(Icons.person_outline, color: C.textMut, size: 20))),
        SizedBox(height: 16),
        _label('Contraseña'),
        TextField(controller: _pass, obscureText: _obs, style: TextStyle(color: C.text),
          decoration: InputDecoration(hintText: 'Mínimo 6 caracteres',
            prefixIcon: Icon(Icons.lock_outline, color: C.textMut, size: 20),
            suffixIcon: IconButton(icon: Icon(_obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.textMut, size: 20),
              onPressed: () => setState(() => _obs = !_obs)))),
        SizedBox(height: 12),

        // ¿Olvidaste tu contraseña?
        Align(alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => context.go('/recuperar-password'),
            child: Text('¿Olvidaste tu contraseña?', style: TextStyle(color: C.green, fontSize: 13)))),

        SizedBox(height: 16),
        ElevatedButton(onPressed: _loading ? null : _login,
          child: _loading ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Ingresar')),
        SizedBox(height: 16),
        Center(child: TextButton(onPressed: () => context.go('/register'),
          child: RichText(text: TextSpan(text: '¿No tienes cuenta? ',
            style: TextStyle(color: C.textSec, fontSize: 14),
            children: [TextSpan(text: 'Regístrate', style: TextStyle(color: C.green, fontWeight: FontWeight.w700))])))),
      ])),
    )),
  );
}

// ── REGISTER ─────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegState();
}
class _RegState extends State<RegisterScreen> {
  final _nombre   = TextEditingController();
  final _correo   = TextEditingController();
  final _tel      = TextEditingController();
  final _doc      = TextEditingController();
  final _dir      = TextEditingController();
  final _pass     = TextEditingController();
  final _confirm  = TextEditingController();
  String _tipoDoc = tiposDoc.first;
  String? _comuna, _error;
  bool _obsP = true, _obsC = true, _loading = false;

  Future<void> _register() async {
    if (_pass.text != _confirm.text) { setState(() => _error = 'Las contraseñas no coinciden'); return; }
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.register({
      'nombre': _nombre.text.trim(), 'correo': _correo.text.trim(),
      'telefono': _tel.text.trim(), 'tipoDoc': _tipoDoc,
      'numeroDoc': _doc.text.trim(), 'departamento': 'Antioquia',
      'municipio': 'Medellín', 'comuna': _comuna ?? '',
      'direccion': _dir.text.trim(), 'password': _pass.text,
    });
    if (!mounted) return;
    if (err != null) { setState(() { _loading = false; _error = err; }); return; }
    // Registro exitoso → ir a verificar cuenta
    context.go('/verificar-cuenta?correo=${Uri.encodeComponent(_correo.text.trim())}');
  }

  Widget _tf(TextEditingController c, String hint, IconData icon, {TextInputType type = TextInputType.text, bool obs = false, VoidCallback? toggle}) =>
    TextField(controller: c, keyboardType: type, obscureText: obs, style: TextStyle(color: C.text),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: C.textMut, size: 20),
        suffixIcon: toggle != null ? IconButton(icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.textMut, size: 20), onPressed: toggle) : null));

  @override void dispose() {
    for (final c in [_nombre, _correo, _tel, _doc, _dir, _pass, _confirm]) c.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(title: Text('Crear cuenta'),
      leading: IconButton(icon: Icon(Icons.arrow_back_ios_new), onPressed: () => context.go('/login'))),
    body: SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_error != null) _err(_error!),

      _label('Nombre completo *'),
      _tf(_nombre, 'Ej: Juan Pérez', Icons.person_outline),
      SizedBox(height: 14),

      _label('Correo electrónico *'),
      _tf(_correo, 'correo@ejemplo.com', Icons.email_outlined, type: TextInputType.emailAddress),
      SizedBox(height: 14),

      _label('Teléfono'),
      _tf(_tel, '300 000 0000', Icons.phone_outlined, type: TextInputType.phone),
      SizedBox(height: 14),

      _label('Tipo de documento'),
      DropdownButtonFormField<String>(
        value: _tipoDoc, dropdownColor: C.surf2,
        style: TextStyle(color: C.text, fontSize: 14),
        decoration: InputDecoration(prefixIcon: Icon(Icons.badge_outlined, color: C.textMut, size: 20)),
        items: tiposDoc.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _tipoDoc = v!)),
      SizedBox(height: 14),

      _label('Número de documento *'),
      _tf(_doc, 'Ej: 1234567890', Icons.numbers, type: TextInputType.number),
      SizedBox(height: 14),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Departamento'),
          Container(padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
            child: Row(children: [Icon(Icons.map_outlined, color: C.textMut, size: 20), SizedBox(width: 12), Text('Antioquia', style: TextStyle(color: C.textMut))])),
        ])),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Municipio'),
          Container(padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
            child: Row(children: [Icon(Icons.location_city_outlined, color: C.textMut, size: 20), SizedBox(width: 12), Text('Medellín', style: TextStyle(color: C.textMut))])),
        ])),
      ]),
      SizedBox(height: 14),

      _label('Comuna'),
      Text('Servicio de domicilio solo en comunas 8 y 9', style: TextStyle(fontSize: 11, color: C.textMut)),
      SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _comuna, dropdownColor: C.surf2,
        style: TextStyle(color: C.text, fontSize: 14),
        decoration: InputDecoration(hintText: 'Seleccionar...', prefixIcon: Icon(Icons.location_on_outlined, color: C.textMut, size: 20)),
        items: comunasDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _comuna = v)),
      if (_comuna != null)
        Padding(padding: EdgeInsets.only(top: 6),
          child: Row(children: [Icon(Icons.check_circle, color: C.green, size: 14), SizedBox(width: 6),
            Text('¡Hacemos domicilios a tu zona!', style: TextStyle(color: C.green, fontSize: 12, fontWeight: FontWeight.w600))])),
      SizedBox(height: 14),

      _label('Dirección'),
      _tf(_dir, 'Ej: Calle 10 #43-20', Icons.home_outlined),
      SizedBox(height: 14),

      _label('Contraseña *'),
      _tf(_pass, 'Mínimo 6 caracteres', Icons.lock_outline, obs: _obsP, toggle: () => setState(() => _obsP = !_obsP)),
      SizedBox(height: 14),

      _label('Confirmar contraseña *'),
      _tf(_confirm, 'Repite la contraseña', Icons.lock_outline, obs: _obsC, toggle: () => setState(() => _obsC = !_obsC)),
      SizedBox(height: 28),

      ElevatedButton(onPressed: _loading ? null : _register,
        child: _loading ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Crear cuenta')),
      SizedBox(height: 32),
    ])),
  );
}