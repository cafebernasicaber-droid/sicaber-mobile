# El paquete google_mlkit_text_recognition (usado para leer el texto de un
# comprobante de pago, ver lib/data/services/ocr_service.dart) referencia en
# su código las opciones de reconocimiento para chino/devanagari/japonés/
# coreano, aunque esta app solo declaró la dependencia del script Latin
# (pubspec.yaml). R8 en el build "release" (minifyReleaseWithR8) no
# encuentra esas clases —nunca se descargan porque no se usan— y antes
# fallaba la compilación entera por eso, no por faltar código real. Estas
# líneas son EXACTAMENTE las que el propio R8 generó en
# build/app/outputs/mapping/release/missing_rules.txt al fallar; silenciar
# el warning es seguro porque esos recognizers nunca se invocan desde esta
# app (solo se usa TextRecognitionScript.latin en ocr_service.dart).
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
