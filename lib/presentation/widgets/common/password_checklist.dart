import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

// ── Checklist en vivo de los requisitos de contraseña ─────────────
// Mismos 4 requisitos + rango de longitud que valida
// data_service.validarPassword/passwordRegex (10-20 caracteres, mayúscula,
// minúscula, número y carácter especial). Se cuelga directo del
// TextEditingController de la contraseña, así que se actualiza en cada
// pulsación sin que la pantalla que lo usa tenga que manejar su propio
// estado — solo hay que ponerlo debajo del TextField correspondiente.
class PasswordChecklist extends StatelessWidget {
  final TextEditingController controller;
  const PasswordChecklist({super.key, required this.controller});

  static final _mayuscula = RegExp(r'[A-Z]');
  static final _minuscula = RegExp(r'[a-z]');
  static final _numero    = RegExp(r'\d');
  static final _especial  = RegExp(r'[^A-Za-z0-9]');

  @override Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final pass = value.text;
      final checks = <(String, bool)>[
        ('Entre 10 y 20 caracteres',      pass.length >= 10 && pass.length <= 20),
        ('Una letra mayúscula (A-Z)',     _mayuscula.hasMatch(pass)),
        ('Una letra minúscula (a-z)',     _minuscula.hasMatch(pass)),
        ('Un número (0-9)',               _numero.hasMatch(pass)),
        ('Un carácter especial (!@#\$…)', _especial.hasMatch(pass)),
      ];
      return Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: checks.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(c.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 14, color: c.$2 ? C.green : C.textMut),
            const SizedBox(width: 6),
            // Expanded: sin él, una línea larga (p. ej. "Un carácter especial")
            // desbordaba el Row en pantallas de 320px o con la fuente grande de
            // accesibilidad, en Recuperar contraseña y en "Completa tu cuenta".
            Expanded(child: Text(c.$1, style: TextStyle(fontSize: 12, color: c.$2 ? C.green : C.textMut))),
          ]))).toList(),
      ));
    });
}
