import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/app_state.dart';

/// Verifica si el usuario está autenticado. Si NO lo está, muestra una
/// alerta invitándolo a iniciar sesión, y retorna `false`.
/// Si SÍ está autenticado, retorna `true` de inmediato sin mostrar nada.
///
/// Uso típico antes de una acción que requiere sesión (ej: agregar al carrito):
/// ```dart
/// if (!ensureLoggedIn(context)) return;
/// AppState.instance.addToCart(producto);
/// ```
bool ensureLoggedIn(BuildContext context, {String accion = 'agregar productos al carrito'}) {
  if (AppState.instance.loggedIn) return true;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: C.greenBg, shape: BoxShape.circle),
        child: Icon(Icons.lock_outline, color: C.green, size: 26),
      ),
      title: Text('Inicia sesión',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.text)),
      content: Text(
        'Necesitas una cuenta para $accion.\n¡Solo toma un momento!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: C.textSec, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      actions: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: C.green,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () { Navigator.pop(ctx); context.push('/login'); },
            child: const Text('Iniciar sesión',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          )),
          const SizedBox(height: 10),
          // Sin botón "Crear cuenta": ya no hay pantalla de registro; quien no
          // tiene cuenta la crea al entrar con Google desde el login.
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Ahora no', style: TextStyle(fontSize: 13, color: C.textMut)),
          ),
        ]),
      ],
    ),
  );

  return false;
}
