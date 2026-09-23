// ─────────────────────────────────────────────────────────────────────────
//  IVA y desglose de precios
// ─────────────────────────────────────────────────────────────────────────
// REGLA FUNDAMENTAL DE ESTE ARCHIVO — el impuesto va INCLUIDO en el precio.
//
// Los precios del catálogo (tabla `productos`.precio en el backend) son
// precios finales al público, con el impuesto ya dentro. Esto NO es una
// preferencia de diseño: es lo único que hace que el requisito
// "el total mostrado en la app debe coincidir con el total usado para
// validar el pago" se cumpla de verdad.
//
// Por qué: el backend recalcula el total del pedido sumando los precios
// del catálogo (ver calcularTotalPedido en sicaber-back/src/routes/
// index.js) y RECHAZA el pedido si el total que manda la app no coincide.
// Después compara ese mismo total contra el valor leído del comprobante de
// pago. Si la app le sumara un IVA encima al total, pasarían dos cosas, las
// dos malas:
//   1. POST /pedidos devolvería 400 "el total no corresponde a los precios
//      vigentes" y NINGÚN pedido podría crearse desde la app.
//   2. Aun si pasara, el cliente habría pagado (y el comprobante diría) un
//      valor distinto al que el backend espera → comprobante rechazado.
//
// Entonces el IVA no se SUMA: se DESGLOSA. El total cobrado es exactamente
// el del catálogo, y lo que se muestra aparte es qué parte de ese total
// corresponde a la base y qué parte al impuesto.
//
// ⚠️ TASA: cámbiala en UN solo lugar (abajo) o por línea de comandos:
//     flutter build apk --dart-define=IVA_PORCENTAJE=8
// El 19 % es el IVA general de Colombia. Si el negocio tributa como
// restaurante/cafetería, el que aplica es el Impuesto Nacional al Consumo
// (INC) del 8 % — en ese caso pon 8 acá y la etiqueta cambia sola.

// Porcentaje del impuesto incluido en los precios del catálogo.
// Es un int a propósito: en Colombia las tarifas son enteras (19, 8, 5, 0)
// y Dart no tiene `double.fromEnvironment` — solo bool/int/String.
const int kIvaPorcentajeEntero = int.fromEnvironment('IVA_PORCENTAJE', defaultValue: 19);
const double kIvaPorcentaje = kIvaPorcentajeEntero * 1.0;

// Etiqueta que se muestra junto al desglose. El 8 % en Colombia no se llama
// IVA sino "Impuesto al consumo", y mostrarlo con el nombre equivocado en
// una factura es un problema real, no cosmético.
String get etiquetaImpuesto => kIvaPorcentajeEntero == 8
    ? 'Impuesto al consumo (8%)'
    : 'IVA ($kIvaPorcentajeEntero%)';

/// Desglose de un total que YA incluye impuesto.
///
/// Se garantiza, por construcción, que `base + impuesto == total` en pesos
/// enteros: el residuo del redondeo se le carga al impuesto en vez de
/// dejar que los tres números no cuadren en pantalla (el clásico "subtotal
/// 42.017 + IVA 7.983 = 50.001" que hace desconfiar al cliente).
class DesglosePrecio {
  final double total;    // lo que de verdad se cobra (precio del catálogo)
  final double base;     // total sin impuesto
  final double impuesto; // la parte de impuesto contenida en el total

  const DesglosePrecio({required this.total, required this.base, required this.impuesto});

  /// Desglosa un total con impuesto incluido.
  factory DesglosePrecio.deTotalConIva(double totalConIva, {double porcentaje = kIvaPorcentaje}) {
    if (porcentaje <= 0 || totalConIva <= 0) {
      return DesglosePrecio(total: totalConIva, base: totalConIva, impuesto: 0);
    }
    final totalRedondeado = totalConIva.roundToDouble();
    final baseRedondeada = (totalRedondeado / (1 + porcentaje / 100)).roundToDouble();
    // El impuesto es siempre el RESTO, nunca un segundo redondeo
    // independiente — así los tres números siempre suman.
    return DesglosePrecio(
      total: totalRedondeado,
      base: baseRedondeada,
      impuesto: totalRedondeado - baseRedondeada,
    );
  }

  /// true cuando hay impuesto que mostrar. Con tasa 0 el desglose no aporta
  /// nada y las pantallas lo ocultan ("cuando corresponda", del requisito).
  bool get aplica => impuesto > 0;
}
