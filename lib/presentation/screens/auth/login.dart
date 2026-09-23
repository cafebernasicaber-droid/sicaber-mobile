import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';
import '../../widgets/common/animations.dart';
import '../../widgets/common/aviso_cobertura.dart';

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
  // Aviso a mostrar de entrada (ej. "tu registro con Google venció"), para
  // cuando se vuelve aquí desde "Completa tu cuenta" con un motivo.
  final String? errorInicial;
  LoginScreen({super.key, this.errorInicial});
  @override State<LoginScreen> createState() => _LoginState();
}
class _LoginState extends State<LoginScreen> {
  final _identificador = TextEditingController();
  final _pass   = TextEditingController();
  bool _obs = true, _loading = false;
  late String? _error = widget.errorInicial;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await AppState.instance.login(_identificador.text.trim(), _pass.text);
    if (!mounted) return;
    if (err != null) { setState(() { _loading = false; _error = err; }); return; }
    context.go('/home');
  }

  Future<void> _loginGoogle() async {
    setState(() { _loading = true; _error = null; });
    final r = await AppState.instance.loginConGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.error != null) { setState(() => _error = r.error); return; }
    // Cerró el diálogo de Google: no es un error, no se muestra nada.
    if (r.cancelado) return;
    // Correo nuevo: todavía NO hay sesión. Se abre "Completa tu cuenta" y la
    // sesión se guarda recién cuando ese formulario se envía bien.
    if (r.pendiente != null) { context.go('/completar-registro', extra: r.pendiente); return; }
    context.go('/home');
  }

  @override void dispose() { _identificador.dispose(); _pass.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: FadeSlideIn(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Antes esta pantalla no tenía NINGÚN botón para volver: cuando se
        // abre con push (ej. el CTA de invitado en Home) el back físico de
        // Android sí funcionaba por debajo, pero no había ninguna señal
        // visual de que se podía volver. context.pop() cuando sí hay algo
        // debajo en la pila; si no (se llegó con .go(), ej. tras cerrar
        // sesión), no hay a dónde volver dentro del login, así que se manda
        // a Home en su lugar — igual que ya hace OrderDetailScreen.
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: C.text, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        SizedBox(height: 24),
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
          // El login solo compara contra el hash guardado, nunca valida
          // formato (esa regla vigente de 10-20 caracteres/mayúscula/
          // número/símbolo solo aplica al CREAR o CAMBIAR una contraseña,
          // ver Registro/Recuperar) — así que ni "mínimo 6" ni ningún otro
          // requisito pertenecen acá; una cuenta antigua con una contraseña
          // más corta debe poder seguir entrando con normalidad.
          decoration: InputDecoration(hintText: 'Tu contraseña',
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

        // Separador "o" + botón de Google, mismo lugar y orden que ya usa
        // la web (GoogleLogin justo debajo del submit, ver Landing.jsx).
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: Divider(color: C.border)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('o', style: TextStyle(color: C.textMut, fontSize: 13))),
          Expanded(child: Divider(color: C.border)),
        ]),
        SizedBox(height: 20),
        OutlinedButton(
          onPressed: _loading ? null : _loginGoogle,
          // mainAxisSize.min + Flexible: sin ellos el texto "Continuar con
          // Google" no podía partirse y desbordaba el botón en pantallas de
          // 320px (o con la fuente grande de accesibilidad activada).
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            // Sin asset propio del logo de Google en el proyecto: una "G"
            // en su azul de marca dentro de un círculo blanco es una
            // aproximación liviana y suficientemente reconocible, sin
            // agregar un paquete de íconos ni una imagen nueva solo para
            // este botón.
            Container(width: 20, height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: C.border)),
              child: Center(child: Text('G',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))))),
            SizedBox(width: 10),
            Flexible(child: Text('Continuar con Google', textAlign: TextAlign.center)),
          ]),
        ),

        // Como en la web: sin pestaña de registro, esta línea es lo único que
        // explica cómo se crea una cuenta nueva. Text centrado (no Row) para que
        // se parta en varias líneas en pantallas de 320px sin desbordar.
        SizedBox(height: 10),
        Text('¿Primera vez? Entra con Google y creamos tu cuenta.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: C.textSec)),

        // Mismo aviso y mismo lugar que en el login de la web: debajo del
        // botón de Google. Informa el alcance de los domicilios ANTES de que
        // el cliente arme un pedido, sin bloquear nada (el menú y la
        // recogida en el local son para todos).
        SizedBox(height: 20),
        const AvisoCobertura(),

        // Sin enlace de "Regístrate": el registro tradicional se eliminó (las
        // cuentas nuevas se crean solo al entrar con Google, arriba), así que
        // no queda ninguna pantalla a la que mandar a quien no tiene cuenta.
      ])),
    )),
  );
}
