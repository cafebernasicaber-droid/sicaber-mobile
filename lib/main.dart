import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'core/theme/theme.dart';
import 'core/routes/router.dart';
import 'data/services/app_state.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // ── Diagnóstico de errores ──────────────────────────────────
    // Muestra el mensaje de error REAL en pantalla (caja roja) en vez de
    // solo dejarlo en la consola. Así, la próxima vez que algo falle,
    // el texto exacto queda visible en la app y es fácil de copiar.
    ErrorWidget.builder = (FlutterErrorDetails details) => Material(
      color: const Color(0xFFB00020),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Text(
            '⚠️ Error de widget:\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );

    // Errores de build/framework: los imprime completos en consola.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 FlutterError: ${details.exceptionAsString()}');
      debugPrint(details.stack.toString());
    };

    // Errores async/plataforma que antes se perdían silenciosamente.
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🔴 Error async no capturado: $error');
      debugPrint(stack.toString());
      return true;
    };

    // Cargar preferencia de tema guardada
    await ThemeController.instance.cargarPreferencia();

    // Cargar datos desde la API al iniciar
    AppState.instance.cargarDatos();

    runApp(const CafeDonBernaApp());
  }, (error, stack) {
    debugPrint('🔴 Error no capturado en runZonedGuarded: $error');
    debugPrint(stack.toString());
  });
}

class CafeDonBernaApp extends StatelessWidget {
  const CafeDonBernaApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ThemeController.instance,
    builder: (context, _) {
      final dark = ThemeController.instance.isDark;
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark));

      return MaterialApp.router(
        title: 'Café Don Berna',
        theme: dark ? darkTheme : lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      );
    },
  );
}