import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  RecuperarPasswordScreen({super.key});
  @override State<RecuperarPasswordScreen> createState() => _RecuperarState();
}

class _RecuperarState extends State<RecuperarPasswordScreen> {
  final _correo   = TextEditingController();
  final _token    = TextEditingController();
  final _nueva    = TextEditingController();
  final _confirma = TextEditingController();
  int     _step    = 1;
  bool    _loading = false;
  String? _error;
  bool    _ok      = false;
  bool    _obsN    = true, _obsC = true;

  Future<void> _solicitar() async {
    if (!_correo.text.contains('@')) { setState(() => _error = 'Correo inválido'); return; }
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.solicitarRecuperacion(_correo.text.trim());
    if (!mounted) return;
    if (err != null) { setState(() { _loading = false; _error = err; }); return; }
    setState(() { _step = 2; _loading = false; });
  }

  Future<void> _resetear() async {
    if (_nueva.text != _confirma.text) { setState(() => _error = 'Las contraseñas no coinciden'); return; }
    if (_nueva.text.length < 6) { setState(() => _error = 'Mínimo 6 caracteres'); return; }
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.resetPassword(_correo.text.trim(), _token.text.trim(), _nueva.text);
    if (!mounted) return;
    if (err != null) { setState(() { _loading = false; _error = err; }); return; }
    setState(() { _ok = true; _loading = false; });
    await Future.delayed(Duration(milliseconds: 1800));
    if (mounted) context.go('/login');
  }

  @override void dispose() {
    for (final c in [_correo, _token, _nueva, _confirma]) c.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType type = TextInputType.text, bool obs = false, VoidCallback? toggle, int? maxLength}) =>
    TextField(controller: c, keyboardType: type, obscureText: obs, maxLength: maxLength,
      style: TextStyle(color: C.text),
      decoration: InputDecoration(
        hintText: hint, counterText: '',
        prefixIcon: Icon(icon, color: C.textMut, size: 20),
        suffixIcon: toggle != null ? IconButton(icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.textMut, size: 20), onPressed: toggle) : null,
      ));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      title: Text('Recuperar contraseña'),
      leading: IconButton(icon: Icon(Icons.arrow_back_ios_new), onPressed: () => context.go('/login')),
    ),
    body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 24),
        Center(child: Container(width: 72, height: 72,
          decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle, border: Border.all(color: C.green.withOpacity(0.3))),
          child: Icon(Icons.lock_reset_outlined, color: C.green, size: 36))),
        SizedBox(height: 20),
        Center(child: Text(_step == 1 ? 'Recuperar acceso' : 'Nueva contraseña',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text))),
        SizedBox(height: 8),
        Center(child: Text(_step == 1
          ? 'Ingresa tu correo y te enviaremos un código'
          : 'Ingresa el código que recibiste en ${_correo.text}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: C.textSec))),
        SizedBox(height: 32),

        if (_ok)
          Container(padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: C.green), SizedBox(width: 8),
              Text('✅ Contraseña actualizada. Redirigiendo...', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
            ]))
        else ...[
          if (_error != null)
            Container(margin: EdgeInsets.only(bottom: 16), padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.red.withOpacity(0.3))),
              child: Row(children: [Icon(Icons.warning_amber_outlined, color: C.red, size: 18), SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: C.red, fontSize: 13)))])),

          if (_step == 1) ...[
            Text('Correo electrónico', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
            SizedBox(height: 8),
            _field(_correo, 'tucorreo@ejemplo.com', Icons.email_outlined, type: TextInputType.emailAddress),
            SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _solicitar,
                child: _loading ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Enviar código'),
              )),
          ] else ...[
            Text('Código de verificación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
            SizedBox(height: 8),
            TextField(
              controller: _token, keyboardType: TextInputType.number, maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10, color: C.text),
              decoration: InputDecoration(counterText: '', hintText: '000000',
                hintStyle: TextStyle(color: C.textMut.withOpacity(0.4), fontSize: 26, letterSpacing: 10),
                filled: true, fillColor: C.surf2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.green, width: 2))),
            ),
            SizedBox(height: 16),
            Text('Nueva contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
            SizedBox(height: 8),
            _field(_nueva, 'Mínimo 6 caracteres', Icons.lock_outline, obs: _obsN, toggle: () => setState(() => _obsN = !_obsN)),
            SizedBox(height: 14),
            Text('Confirmar contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)),
            SizedBox(height: 8),
            _field(_confirma, 'Repite la contraseña', Icons.lock_outline, obs: _obsC, toggle: () => setState(() => _obsC = !_obsC)),
            SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _resetear,
                child: _loading ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Cambiar contraseña'),
              )),
          ],
          SizedBox(height: 16),
          Center(child: TextButton(onPressed: () => context.go('/login'),
            child: Text('← Volver al login', style: TextStyle(color: C.textSec)))),
        ],
      ]),
    )),
  );
}