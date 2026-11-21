# google_mlkit_text_recognition references the Chinese, Devanagari,
# Japanese and Korean recognizers as compile-only dependencies. The app uses
# the Latin recognizer only (lib/ai/ocr_service.dart) and does not ship those
# models, so R8 must not expect their classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
