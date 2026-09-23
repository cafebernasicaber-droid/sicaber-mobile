import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

// Aviso de cobertura de domicilios para el LOGIN. Es el equivalente exacto
// del "lx-cobertura-aviso" que la web puso en su modal de inicio de sesión
// (Landing.jsx): mismo título y mismo subtítulo. Se muestra ahí porque es el
// punto por el que pasa todo el que quiere pedir (agregar al carrito exige
// sesión), y antes de tener cuenta es cuando el cliente necesita enterarse
// de que fuera de comunas 8 y 9 igual puede usar la app.
//
// Tono informativo, no un bloqueo: por eso va en verde (color de marca) y no
// en rojo/ámbar de advertencia, y dice qué SÍ puede hacer el cliente
// (ver el menú completo y recoger en el local), no solo qué no.
class AvisoCobertura extends StatelessWidget {
  const AvisoCobertura({super.key});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: C.green.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.green.withOpacity(0.32))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1),
        child: Icon(Icons.location_on_outlined, size: 16, color: C.green)),
      const SizedBox(width: 10),
      // Expanded: sin él, el texto largo desbordaba el Row en pantallas
      // angostas en vez de partirse en varias líneas.
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Domicilios en las comunas 8 y 9 de Medellín',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.text, height: 1.35)),
        const SizedBox(height: 3),
        Text.rich(TextSpan(
          style: TextStyle(fontSize: 11.5, color: C.textSec, height: 1.45),
          children: [
            const TextSpan(text: 'Si estás en otra zona, igual puedes ver todo el menú y pedir para '),
            TextSpan(text: 'recoger en el local',
              style: TextStyle(fontWeight: FontWeight.w700, color: C.text)),
            const TextSpan(text: '.'),
          ])),
      ])),
    ]));
}
