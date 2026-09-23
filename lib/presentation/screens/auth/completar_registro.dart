import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';
import '../../../data/services/data_service.dart';
import '../../widgets/common/password_checklist.dart';

// ── COMPLETA TU CUENTA (primer ingreso con Google) ─────────────────
// Equivalente móvil del modal "Completa tu cuenta" de la web (Landing.jsx):
// mismos campos (contraseña, tipo y número de documento, teléfono), mismas
// reglas y el mismo endpoint (POST /auth/cliente/google/completar, vía
// AppState.completarRegistroGoogle).
//
// OBLIGATORIO de verdad: PopScope(canPop:false) bloquea el botón atrás de
// Android y el gesto de deslizar, y no hay AppBar con flecha. Como es una
// pantalla completa (ruta de go_router) y no un diálogo, tampoco existe una
// zona "fuera" que la cierre al tocar. La ÚNICA salida es el enlace explícito
// "Cancelar": el backend no crea nada hasta que este formulario se envía bien,
// así que salir no deja ninguna cuenta a medias ni sesión guardada — y sin esa
// salida quien eligió la cuenta de Google equivocada quedaría atrapado.
class CompletarRegistroScreen extends StatefulWidget {
  final RegistroGoogle registro;
  const CompletarRegistroScreen({super.key, required this.registro});
  @override State<CompletarRegistroScreen> createState() => _CompletarState();
}

class _CompletarState extends State<CompletarRegistroScreen> {
  final _pass    = TextEditingController();
  final _confirm = TextEditingController();
  final _tipoOtro = TextEditingController();
  final _numDoc  = TextEditingController();
  final _tel     = TextEditingController();
  // Solo lectura: se crea una vez (no en cada build) y se libera en dispose.
  late final _correo = TextEditingController(text: widget.registro.correo);
  String _tipoDoc = tiposDocConOtros.first;
  bool _obsP = true, _obsC = true, _loading = false;

  // Un error por campo (los que el propio formulario o el backend pueden
  // atribuir sin dudas) + un banner para todo lo demás, igual que la web.
  String? _banner, _errPass, _errConfirm, _errTipo, _errNumDoc, _errTel;

  bool get _esOtros => _tipoDoc == tipoDocOtros;

  @override void dispose() {
    for (final c in [_pass, _confirm, _tipoOtro, _numDoc, _tel, _correo]) { c.dispose(); }
    super.dispose();
  }

  // Validación de forma antes de gastar un viaje al servidor; las reglas de
  // fondo las vuelve a aplicar el backend, y su mensaje es el que manda.
  bool _validar() {
    final tipoOtro = _tipoOtro.text.trim();
    setState(() {
      _errPass = _pass.text.isEmpty
          ? 'Crea una contraseña para tu cuenta.'
          : validarPassword(_pass.text);
      _errConfirm = (_errPass == null && _pass.text != _confirm.text)
          ? 'Las contraseñas no coinciden' : null;
      // "Otros" no puede viajar tal cual: el backend lo rechaza (ver
      // tipoDocOtros en data_service.dart), así que se exige el texto real.
      _errTipo = (_esOtros && (tipoOtro.isEmpty || tipoOtro.toLowerCase() == 'otros'))
          ? 'Selecciona (o escribe) el tipo de documento.' : null;
      _errNumDoc = validarNumeroDocumento(_numDoc.text);
      _errTel = validarTelefono(_tel.text);
    });
    return _errPass == null && _errConfirm == null && _errTipo == null &&
        _errNumDoc == null && _errTel == null;
  }

  // El backend responde los errores de validación solo como {error: "..."} sin
  // decir de qué campo. Se marca un campo ÚNICAMENTE cuando el mensaje lo
  // nombra sin ambigüedad (los textos fijos de auth.js); si no, va al banner.
  // Sin heurísticas más finas a propósito: una mal atribuida confunde más que
  // un banner genérico.
  void _mostrarErrorBackend(String mensaje) {
    final m = mensaje.toLowerCase();
    setState(() {
      _banner = _errPass = _errTipo = _errNumDoc = _errTel = null;
      if (m.contains('tipo de documento')) { _errTipo = mensaje; }
      else if (m.contains('número de documento') || m.contains('numero de documento')) { _errNumDoc = mensaje; }
      else if (m.contains('teléfono') || m.contains('telefono')) { _errTel = mensaje; }
      else if (m.contains('contraseña')) { _errPass = mensaje; }
      else { _banner = mensaje; }
    });
  }

  Future<void> _enviar() async {
    if (_loading) return;
    setState(() => _banner = null);
    if (!_validar()) return;
    setState(() => _loading = true);
    // Igual que la web: con "Otros" se manda lo que el cliente escribió en
    // "¿Cuál?" (ya recortado), nunca el literal "Otros".
    final tipoFinal = _esOtros ? _tipoOtro.text.trim() : _tipoDoc;
    final r = await AppState.instance.completarRegistroGoogle(
      tokenRegistro: widget.registro.tokenRegistro,
      password: _pass.text,
      tipoDoc: tipoFinal,
      numeroDoc: _numDoc.text.trim(),
      telefono: _tel.text.trim(),
    );
    if (!mounted) return;
    if (r.exito) {
      // La sesión ya quedó guardada dentro de completarRegistroGoogle (solo
      // tras el 201). Nada de sesiones a medias.
      context.go('/home');
      return;
    }
    setState(() => _loading = false);
    if (r.reiniciarGoogle) {
      // Token vencido/inválido, o el correo ya tiene cuenta: este formulario
      // no va a pasar nunca. Se vuelve al login con el motivo a la vista, en
      // vez de dejar al cliente corrigiendo campos que no tienen arreglo.
      context.go('/login', extra: r.error);
      return;
    }
    _mostrarErrorBackend(r.error ?? 'No se pudo completar el registro.');
  }

  Future<void> _cancelar() async {
    if (_loading) return;
    // Cierra también la sesión de Google del dispositivo: si no, el próximo
    // "Continuar con Google" reentra con la misma cuenta sin dejar elegir otra.
    await AppState.instance.descartarRegistroGoogle();
    if (!mounted) return;
    context.go('/login');
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSec)));

  Widget _toggle(bool obs, VoidCallback f) => IconButton(
    icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: C.textMut, size: 20),
    onPressed: f);

  @override Widget build(BuildContext context) {
    final primerNombre = widget.registro.nombre.trim().split(' ').first;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: C.bg,
        // Sin flecha de retroceso: la salida es el enlace "Cancelar" de abajo.
        appBar: AppBar(title: const Text('Completa tu cuenta'), automaticallyImplyLeading: false),
        body: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Solo falta esto para terminar de crear tu cuenta${primerNombre.isNotEmpty ? ', $primerNombre' : ''}.',
              style: TextStyle(fontSize: 13.5, color: C.textSec, height: 1.4)),
            const SizedBox(height: 18),

            if (_banner != null) Container(
              margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.red.withOpacity(0.3))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_outlined, color: C.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_banner!, style: TextStyle(color: C.red, fontSize: 13))),
              ])),

            // El correo lo verificó Google y el backend lo toma del token
            // firmado, no de este campo: se muestra deshabilitado solo para que
            // el cliente vea con qué cuenta está entrando.
            _label('Correo (verificado por Google)'),
            TextField(
              controller: _correo,
              enabled: false, style: TextStyle(color: C.textSec),
              decoration: InputDecoration(prefixIcon: Icon(Icons.email_outlined, color: C.textMut, size: 20))),
            const SizedBox(height: 16),

            _label('Crea una contraseña *'),
            TextField(controller: _pass, obscureText: _obsP, style: TextStyle(color: C.text),
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) { if (_errPass != null) setState(() => _errPass = null); },
              decoration: InputDecoration(
                hintText: '10-20 caracteres, con mayúscula, número y símbolo',
                errorText: _errPass, errorMaxLines: 3,
                prefixIcon: Icon(Icons.lock_outline, color: C.textMut, size: 20),
                suffixIcon: _toggle(_obsP, () => setState(() => _obsP = !_obsP)))),
            // Mismo checklist en vivo de Recuperar contraseña (no hay otro).
            PasswordChecklist(controller: _pass),
            const SizedBox(height: 8),

            _label('Confirmar contraseña *'),
            TextField(controller: _confirm, obscureText: _obsC, style: TextStyle(color: C.text),
              onChanged: (_) { if (_errConfirm != null) setState(() => _errConfirm = null); },
              decoration: InputDecoration(
                hintText: 'Repite la contraseña', errorText: _errConfirm,
                prefixIcon: Icon(Icons.lock_outline, color: C.textMut, size: 20),
                suffixIcon: _toggle(_obsC, () => setState(() => _obsC = !_obsC)))),
            const SizedBox(height: 16),

            _label('Tipo de documento *'),
            // isExpanded: sin él, el texto más largo ("Cédula de Extranjería")
            // desbordaba el dropdown en pantallas de 320px.
            DropdownButtonFormField<String>(
              initialValue: _tipoDoc, isExpanded: true, dropdownColor: C.surf2,
              style: TextStyle(color: C.text, fontSize: 14),
              decoration: InputDecoration(
                errorText: _esOtros ? null : _errTipo,
                prefixIcon: Icon(Icons.badge_outlined, color: C.textMut, size: 20)),
              items: tiposDocConOtros.map((t) => DropdownMenuItem(value: t,
                child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() { _tipoDoc = v!; _errTipo = null; })),
            if (_esOtros) ...[
              const SizedBox(height: 16),
              _label('¿Cuál? *'),
              TextField(controller: _tipoOtro, style: TextStyle(color: C.text),
                maxLength: tipoDocMaxCaracteres,
                onChanged: (_) { if (_errTipo != null) setState(() => _errTipo = null); },
                decoration: InputDecoration(
                  hintText: 'Ej: Permiso por Protección Temporal',
                  counterText: '', errorText: _errTipo, errorMaxLines: 2,
                  prefixIcon: Icon(Icons.edit_outlined, color: C.textMut, size: 20))),
            ],
            const SizedBox(height: 16),

            _label('Número de documento *'),
            TextField(controller: _numDoc, keyboardType: TextInputType.number, style: TextStyle(color: C.text),
              // Solo dígitos y máximo 10: la misma regla del backend.
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onChanged: (_) { if (_errNumDoc != null) setState(() => _errNumDoc = null); },
              decoration: InputDecoration(
                hintText: 'Solo números', errorText: _errNumDoc, errorMaxLines: 2,
                prefixIcon: Icon(Icons.numbers, color: C.textMut, size: 20))),
            const SizedBox(height: 16),

            _label('Teléfono *'),
            TextField(controller: _tel, keyboardType: TextInputType.phone, style: TextStyle(color: C.text),
              // Se permiten +57, espacios, guiones y paréntesis porque el
              // backend los acepta (7 a 10 dígitos en total, ver validarTelefono).
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))],
              onChanged: (_) { if (_errTel != null) setState(() => _errTel = null); },
              decoration: InputDecoration(
                hintText: 'Ej: 3001234567', errorText: _errTel, errorMaxLines: 3,
                prefixIcon: Icon(Icons.phone_outlined, color: C.textMut, size: 20))),
            const SizedBox(height: 28),

            ElevatedButton(onPressed: _loading ? null : _enviar,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Crear cuenta y entrar')),
            const SizedBox(height: 8),
            Center(child: TextButton(onPressed: _loading ? null : _cancelar,
              child: Text('Cancelar', style: TextStyle(color: C.textSec, decoration: TextDecoration.underline)))),
            // Misma advertencia que la web: aclara que salir no deja nada.
            Center(child: Text(
              'Tu cuenta se crea al enviar este formulario. Si sales ahora, no se guarda nada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: C.textMut, height: 1.4))),
            const SizedBox(height: 16),
          ]),
        )),
      ),
    );
  }
}
