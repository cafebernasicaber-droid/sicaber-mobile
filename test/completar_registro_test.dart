// Panel "Completa tu cuenta" (primer ingreso con Google).
//
// Se prueba a 320/360/414/600px porque Flutter hace fallar cualquier prueba en
// la que aparezca un "RenderFlex overflowed" (mismo criterio que
// checkout_pago_responsive_test.dart). Ninguna prueba toca la red: los envíos
// con datos válidos llamarían al backend real, así que aquí solo se ejercitan
// los caminos que se resuelven en el cliente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_don_berna/data/services/app_state.dart';
import 'package:cafe_don_berna/data/services/data_service.dart';
import 'package:cafe_don_berna/presentation/screens/auth/completar_registro.dart';

const _anchos = [320.0, 360.0, 414.0, 600.0];

const _registro = RegistroGoogle(
  tokenRegistro: 'token-de-prueba', correo: 'cliente@gmail.com', nombre: 'Juan Pérez');

Future<void> _fijarAncho(WidgetTester tester, double ancho) async {
  tester.view.physicalSize = Size(ancho, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _abrirPanel(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: CompletarRegistroScreen(registro: _registro)));
  await tester.pumpAndSettle();
}

// 1.6x — misma fuente "grande" de accesibilidad que checkout_pago_responsive_test.dart.
Future<void> _abrirPanelConFuenteGrande(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
      child: child!),
    home: const CompletarRegistroScreen(registro: _registro)));
  await tester.pumpAndSettle();
}

Future<void> _tocarEnviar(WidgetTester tester) async {
  final boton = find.text('Crear cuenta y entrar');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  group('validarTelefono — misma regla que el backend (7 a 10 dígitos)', () {
    test('acepta celular, fijo de 7 dígitos, +57 y separadores', () {
      expect(validarTelefono('3001234567'), isNull);
      expect(validarTelefono('2345678'), isNull);          // fijo local de 7
      expect(validarTelefono('+57 300 123 4567'), isNull);
      expect(validarTelefono('(604) 123-4567'), isNull);
    });
    test('rechaza vacío, letras y longitudes fuera de 7-10', () {
      expect(validarTelefono(''), 'Escribe tu teléfono.');
      expect(validarTelefono('   '), 'Escribe tu teléfono.');
      expect(validarTelefono('abc1234567'), contains('solo puede contener números'));
      expect(validarTelefono('123456'), 'El teléfono debe tener entre 7 y 10 dígitos.');
      expect(validarTelefono('30012345678'), 'El teléfono debe tener entre 7 y 10 dígitos.');
    });
  });

  group('validarNumeroDocumento — solo dígitos, máximo 10', () {
    test('acepta y rechaza', () {
      expect(validarNumeroDocumento('1234567890'), isNull);
      expect(validarNumeroDocumento(''), 'Escribe tu número de documento.');
      expect(validarNumeroDocumento('12a45'), 'El número de documento solo puede contener números.');
      expect(validarNumeroDocumento('12345678901'), contains('más de 10 dígitos'));
    });
  });

  group('RegistroGoogle.desdeRespuesta — el APK sirve antes y después del despliegue', () {
    test('backend nuevo: registroPendiente:true con token → registro pendiente', () {
      final r = RegistroGoogle.desdeRespuesta({
        'registroPendiente': true, 'tokenRegistro': 'abc', 'correo': 'a@b.com', 'nombre': 'Ana'});
      expect(r, isNotNull);
      expect(r!.tokenRegistro, 'abc');
      expect(r.correo, 'a@b.com');
    });
    test('backend viejo: {token, cliente} sin bandera → null (entra normal)', () {
      expect(RegistroGoogle.desdeRespuesta({'token': 't', 'cliente': {'id': 1}}), isNull);
    });
    test('bandera sin token utilizable, o en false → null', () {
      expect(RegistroGoogle.desdeRespuesta({'registroPendiente': true}), isNull);
      expect(RegistroGoogle.desdeRespuesta({'registroPendiente': true, 'tokenRegistro': ''}), isNull);
      expect(RegistroGoogle.desdeRespuesta({'registroPendiente': false, 'tokenRegistro': 'x'}), isNull);
    });
  });

  for (final ancho in _anchos) {
    testWidgets('Panel: campos, checklist y avisos — sin overflow a ${ancho}px', (tester) async {
      await _fijarAncho(tester, ancho);
      await _abrirPanel(tester);

      expect(find.text('Completa tu cuenta'), findsOneWidget);
      expect(find.text('Correo (verificado por Google)'), findsOneWidget);
      expect(find.text('cliente@gmail.com'), findsOneWidget);
      expect(find.text('Crea una contraseña *'), findsOneWidget);
      // Es el PasswordChecklist reutilizado (no hay otro checklist).
      expect(find.text('Entre 10 y 20 caracteres'), findsOneWidget);
      expect(find.text('Confirmar contraseña *'), findsOneWidget);
      expect(find.text('Tipo de documento *'), findsOneWidget);
      expect(find.text('Número de documento *'), findsOneWidget);
      expect(find.text('Teléfono *'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.textContaining('Si sales ahora, no se guarda nada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Panel: "Otros" muestra ¿Cuál? y exige el texto — sin overflow a ${ancho}px', (tester) async {
      await _fijarAncho(tester, ancho);
      await _abrirPanel(tester);
      expect(find.text('¿Cuál? *'), findsNothing);

      await tester.tap(find.text('Cédula de Ciudadanía'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otros').last);
      await tester.pumpAndSettle();
      expect(find.text('¿Cuál? *'), findsOneWidget);

      // Todo lo demás válido, "¿Cuál?" vacío: se frena en el cliente, sin red.
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(1), 'Abcdefghi1#x');
      await tester.enterText(campos.at(2), 'Abcdefghi1#x');
      await tester.enterText(campos.at(4), '1234567890');
      await tester.enterText(campos.at(5), '3001234567');
      await _tocarEnviar(tester);
      expect(find.text('Selecciona (o escribe) el tipo de documento.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Panel: enviar vacío marca cada campo, sin red — a ${ancho}px', (tester) async {
      await _fijarAncho(tester, ancho);
      await _abrirPanel(tester);
      await _tocarEnviar(tester);

      expect(find.text('Crea una contraseña para tu cuenta.'), findsOneWidget);
      expect(find.text('Escribe tu número de documento.'), findsOneWidget);
      expect(find.text('Escribe tu teléfono.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Panel: contraseñas distintas → error en la confirmación', (tester) async {
    await _fijarAncho(tester, 360);
    await _abrirPanel(tester);
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(1), 'Abcdefghi1#x');
    await tester.enterText(campos.at(2), 'Otraclave1#xy');
    await tester.enterText(campos.at(3), '1234567890');
    await tester.enterText(campos.at(4), '3001234567');
    await _tocarEnviar(tester);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('Panel: número de documento solo acepta dígitos y tope de 10', (tester) async {
    await _fijarAncho(tester, 360);
    await _abrirPanel(tester);
    final numDoc = find.byType(TextField).at(3);
    await tester.enterText(numDoc, '12ab34-56 78901234');
    await tester.pump();
    expect(tester.widget<TextField>(numDoc).controller!.text, '1234567890');
  });

  testWidgets('Panel con fuente grande de accesibilidad (360px) — sin overflow', (tester) async {
    await _fijarAncho(tester, 360);
    await _abrirPanelConFuenteGrande(tester);
    expect(find.text('Completa tu cuenta'), findsOneWidget);
    expect(find.text('Crear cuenta y entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Panel obligatorio: el botón atrás de Android NO lo cierra', (tester) async {
    await _fijarAncho(tester, 360);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav, home: const Scaffold(body: Text('base'))));
    nav.currentState!.push(MaterialPageRoute(
      builder: (_) => const CompletarRegistroScreen(registro: _registro)));
    await tester.pumpAndSettle();
    expect(find.text('Completa tu cuenta'), findsOneWidget);

    // Equivale a presionar el botón físico "atrás" / el gesto de deslizar.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Completa tu cuenta'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, isFalse);
    // Y no hay flecha de retroceso en la barra.
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
  });
}
