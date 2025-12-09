// lib/services/ocr_service.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrService {
  // Inicializamos el reconocedor de texto para alfabeto latino
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Función principal: Recibe la imagen y devuelve un Mapa con los datos encontrados
  Future<Map<String, String>> scanPaymentVoucher(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    // ¡Aquí ocurre la magia! Lee todo el texto de la imagen
    final recognizedText = await _textRecognizer.processImage(inputImage);

    String fullText = recognizedText.text;

    String amountFound = "";
    String operationCodeFound = "";

    // --- LÓGICA DE BÚSQUEDA (PARSING) ---
    // Dividimos el texto por líneas para analizar una por una
    List<String> lines = fullText.split('\n');

    for (String line in lines) {
      // 1. BUSCAR MONTO: Busca líneas que tengan "S/" o "S/."
      // Ej: "Monto: S/ 2.50"
      if (line.contains("S/") || line.contains("S/.")) {
        // Usamos Expresiones Regulares (Regex) para extraer solo los números y el punto
        // Busca: digitos + punto/coma opcional + dos digitos decimales
        RegExp regExp = RegExp(r'(\d+[\.,]?\d{0,2})');
        var match = regExp.firstMatch(line);
        if (match != null) {
          // Reemplazamos coma por punto para que sea un double válido
          amountFound = match.group(0)?.replaceAll(',', '.') ?? "";
        }
      }

      // 2. BUSCAR NÚMERO DE OPERACIÓN
      // Yape suele poner "N° de operación", "Num operación", etc.
      String lowerLine = line.toLowerCase();
      if (lowerLine.contains("operación") ||
          lowerLine.contains("operacion") ||
          lowerLine.contains("ref:")) {
        // Buscamos una secuencia de números de 4 a 8 dígitos en esa misma línea
        RegExp regExp = RegExp(r'\d{4,8}');
        var match = regExp.firstMatch(line);
        if (match != null) {
          operationCodeFound = match.group(0) ?? "";
        }
      }
    }

    // INTENTO SECUNDARIO PARA CÓDIGO DE OPERACIÓN:
    // A veces el número está solo en una línea aparte, usualmente al final.
    // Si no lo encontramos arriba, buscamos cualquier número de 6 a 8 dígitos aislado.
    if (operationCodeFound.isEmpty) {
      RegExp regExp = RegExp(r'^\d{6,8}$', multiLine: true);
      // Buscamos en todo el texto, no solo línea por línea
      var matches = regExp.allMatches(fullText);
      if (matches.isNotEmpty) {
        // Tomamos el último que suele ser el código principal en Yape
        operationCodeFound = matches.last.group(0)!;
      }
    }

    return {
      "amount": amountFound,
      "code": operationCodeFound,
    };
  }

  // Importante: Cerrar el reconocedor cuando ya no se use para liberar memoria
  void dispose() {
    _textRecognizer.close();
  }
}
