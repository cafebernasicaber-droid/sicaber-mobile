import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';

class VerificarCuentaScreen extends StatefulWidget {
  final String correo;
  VerificarCuentaScreen({super.key, required this.correo});
  @override State<VerificarCuentaScreen> createState() => _VerificarState();
}

class _VerificarState extends State<VerificarCuentaScreen> {
  final _token = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _ok = false;

  Future<void> _verificar() async {
    if (_token.text.trim().length != 6) {
      setState(() => _error = 'El código debe tener 6 dígitos');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.verificarCuenta(widget.correo, _token.text.trim());
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
      return;
    }
    setState(() { _ok = true; _loading = false; });
    await Future.delayed(Duration(milliseconds: 1500));
    if (mounted) context.go('/home');
  }

  @override void dispose() { _token.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      title: Text('Verificar cuenta'),
      leading: IconButton(icon: Icon(Icons.arrow_back_ios_new), onPressed: () => context.go('/login')),
    ),
    body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(height: 32),
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle,
            border: Border.all(color: C.green.withOpacity(0.3))),
          child: Icon(Icons.mark_email_read_outlined, color: C.green, size: 40)),
        SizedBox(height: 20),
        Text('Revisa tu correo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
        SizedBox(height: 8),
        Text('Enviamos un código de 6 dígitos a\n${widget.correo}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: C.textSec)),
        SizedBox(height: 40),

        if (_ok)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: C.green), SizedBox(width: 8),
              Text('✅ ¡Cuenta verificada! Redirigiendo...', style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
            ]),
          )
        else ...[
          if (_error != null)
            Container(
              margin: EdgeInsets.only(bottom: 16), padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.red.withOpacity(0.3))),
              child: Row(children: [
                Icon(Icons.warning_amber_outlined, color: C.red, size: 18), SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: C.red, fontSize: 13))),
              ]),
            ),

          TextField(
            controller: _token,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 12, color: C.text),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(color: C.textMut.withOpacity(0.4), fontSize: 28, letterSpacing: 12),
              counterText: '',
              filled: true, fillColor: C.surf2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.green, width: 2)),
            ),
          ),
          SizedBox(height: 24),

          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verificar,
              child: _loading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Confirmar cuenta'),
            ),
          ),
          SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text('← Volver al login', style: TextStyle(color: C.textSec)),
          ),
        ],
      ]),
    )),
  );
}