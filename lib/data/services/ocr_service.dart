import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ── Resultado de leer un comprobante con OCR ──────────────────────
// 'ok'          → se extrajo texto (puede o no contener el monto real; eso
//                 lo decide el backend, acá solo se entrega materia prima).
// 'sin_texto'   → el reconocedor corrió pero la imagen no tenía texto legible.
// 'no_soportado'→ ML Kit on-device no está disponible en esta plataforma
//                 (Flutter Web, por ejemplo — no hay build nativo de ML Kit).
// 'error'       → falló la lectura (archivo corrupto, sin permisos, etc.).
class OcrResultado {
  final String? texto;
  final String  estado;
  const OcrResultado({this.texto, required this.estado});
}

// ── Lectura de comprobantes de pago con ML Kit (on-device) ────────
// Se usa SOLO para extraer texto de la imagen que el cliente sube como
// comprobante — ver _seleccionarComprobante en cart.dart. La app NUNCA
// decide con esto si el pago es válido: solo manda el texto crudo al
// backend (campo comprobante_texto en crearPedido/AppState), que es quien
// compara el monto contra el total del pedido. Un OCR que falla o lee mal
// no puede bloquear una compra real, por eso todo error acá se traduce en
// un estado informativo en vez de una excepción que tumbe el checkout.
class OcrService {
  OcrService._();
  static final OcrService _i = OcrService._();
  static OcrService get instance => _i;

  // Se crea una sola vez y se reutiliza entre comprobantes de la misma
  // sesión de checkout — instanciarlo por foto es innecesariamente lento
  // (carga el modelo de nuevo cada vez).
  TextRecognizer? _recognizer;

  Future<OcrResultado> leerTexto(String rutaImagen) async {
    // google_mlkit_text_recognition no tiene implementación web: el propio
    // paquete no compila el plugin ahí, así que ni se intenta.
    if (kIsWeb) return const OcrResultado(estado: 'no_soportado');
    try {
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      final resultado = await _recognizer!.processImage(InputImage.fromFilePath(rutaImagen));
      final texto = resultado.text.trim();
      if (texto.isEmpty) return const OcrResultado(estado: 'sin_texto');
      return OcrResultado(texto: texto, estado: 'ok');
    } catch (_) {
      return const OcrResultado(estado: 'error');
    }
  }

  // Libera el modelo nativo cargado — ver CheckoutScreen.dispose() en
  // cart.dart para el porqué (recursos nativos que si no se cierran se van
  // acumulando por cada paso por el checkout).
  Future<void> liberar() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
