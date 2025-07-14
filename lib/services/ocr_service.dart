import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/material.dart';

class OCRResult {
  final String fullText;
  final String? name;
  final String? company;
  final String? profession;
  final List<String> phones;
  final List<String> emails;
  final List<String> websites;
  final bool processedWithAI;

  OCRResult({
    required this.fullText,
    this.name,
    this.company,
    this.profession,
    required this.phones,
    required this.emails,
    required this.websites,
    this.processedWithAI = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullText': fullText,
      'name': name,
      'company': company,
      'profession': profession,
      'phones': phones,
      'emails': emails,
      'websites': websites,
      'processedWithAI': processedWithAI,
    };
  }
}

class GroqService {
  final String apiKey;
  final String baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  GroqService({required this.apiKey});

  Future<Map<String, dynamic>?> extractBusinessCardFields(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama3-8b-8192',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '''You are an expert at extracting structured information from business cards. 
Extract the following fields from the business card text and return ONLY a valid JSON object with these exact keys:
- "name": Full name of the person (string or null)
- "company": Company name (string or null)  
- "profession": Job title or profession (string or null)
- "phones": List of phone numbers (array of strings)
- "emails": List of email addresses (array of strings)
- "websites": List of websites/URLs (array of strings)

Rules:
1. Return ONLY the JSON object, no additional text
2. If a field is not found, use null for strings or empty array for lists
3. Clean and format the extracted data appropriately
4. For phones, include country codes only if present
5. For emails, ensure they are valid email addresses
6. For websites, include full URLs when possible

Example output:
{"name": "John Doe", "company": "Tech Corp", "profession": "Software Engineer", "phones": ["+1-555-123-4567"], "emails": ["john@techcorp.com"], "websites": ["www.techcorp.com"]}
Give only the JSON object, no additional text or explanations.
''',
                },
                {
                  'role': 'user',
                  'content':
                      'Extract information from this business card text:\n\n$text',
                },
              ],
              'temperature': 0.1,
              'max_tokens': 500,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Parse the JSON response
        try {
          final extractedData = jsonDecode(content);
          return extractedData;
        } catch (e) {
          print('Error parsing Groq JSON response: $e');
          return null;
        }
      } else {
        print('Groq API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling Groq API: $e');
      return null;
    }
  }
}

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final GroqService? _groqService;

  OCRService({String? groqApiKey})
    : _groqService = groqApiKey != null
          ? GroqService(apiKey: groqApiKey)
          : null;

  Future<OCRResult?> scanAndParseVisitCardFromCamera(
    BuildContext context,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Traitement en cours ..."),
        backgroundColor: Colors.orange,
        duration: Duration(days: 1),
      ),
    );

    final imageFile = File(pickedFile.path);
    final inputImage = InputImage.fromFile(imageFile);

    // Process OCR
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final text = recognizedText.text;

    // Delete image file after processing
    try {
      if (await imageFile.exists()) {
        await imageFile.delete();
        print('Temporary image file deleted.');
      }
    } catch (e) {
      print('Failed to delete image file: $e');
    }

    // Check connectivity with proper error handling
    bool isOnline = false;
    try {
      isOnline = await _checkInternetConnectivity();
      print('Connectivity check successful: $isOnline');
    } catch (e) {
      print('Connectivity check failed: $e');
      // Assume offline if connectivity check fails
      isOnline = false;

      // Show a warning to the user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Impossible de vérifier la connectivité. Mode heuristique utilisé.",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    OCRResult? result;

    if (isOnline && _groqService != null) {
      result = await _tryGroqExtraction(text, recognizedText, context);
    }

    // Fall back to heuristic extraction if AI fails or offline
    if (result == null) {
      result = await _heuristicExtraction(text, recognizedText, context);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    return result;
  }

  Future<OCRResult?> _tryGroqExtraction(
    String text,
    RecognizedText recognizedText,
    BuildContext context,
  ) async {
    try {
      print('Attempting Groq extraction...');
      final extractedData = await _groqService!.extractBusinessCardFields(text);

      if (extractedData != null) {
        print('Groq extraction successful');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Carte scannée avec succès! (AI enrichi)"),
              backgroundColor: Colors.green,
            ),
          );
        }

        return OCRResult(
          fullText: text,
          name: extractedData['name'],
          company: extractedData['company'],
          profession: extractedData['profession'],
          phones: List<String>.from(extractedData['phones'] ?? []),
          emails: List<String>.from(extractedData['emails'] ?? []),
          websites: List<String>.from(extractedData['websites'] ?? []),
          processedWithAI: true,
        );
      }
    } catch (e) {
      print('Groq extraction failed: $e');
    }
    return null;
  }

  Future<OCRResult> _heuristicExtraction(
    String text,
    RecognizedText recognizedText,
    BuildContext context,
  ) async {
    print('Using heuristic extraction...');

    // Split non-empty lines
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Extract structured info using existing heuristics
    final phones = _extractPhones(text);
    final emails = _extractEmails(text);
    final websites = _extractWebsites(text);

    final name = _guessName(recognizedText);
    final profession = _guessProfession(lines, name);
    final company = _guessCompany(recognizedText);

    // Show notification
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Carte scannée avec succès! (Mode heuristique)"),
          backgroundColor: Colors.orange,
        ),
      );
    }

    return OCRResult(
      fullText: text,
      name: name,
      company: company,
      profession: profession,
      phones: phones,
      emails: emails,
      websites: websites,
      processedWithAI: false,
    );
  }

  // --- Alternative connectivity check method ---
  Future<bool> _checkInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('Internet connectivity check failed: $e');
      return false;
    }
  }

  // --- Extraction regex (unchanged) ---

  List<String> _extractPhones(String text) {
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\(\)]{6,}\d)');
    return phoneRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
  }

  List<String> _extractEmails(String text) {
    final emailRegex = RegExp(
      r'\b\S*@(?:gmail|yahoo|hotmail|outlook|icloud|protonmail|live|aol)\S*\b',
      caseSensitive: false,
    );
    return emailRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
  }

  List<String> _extractWebsites(String text) {
    final websiteRegex = RegExp(
      r'(?<!@)\b((https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-z]{2,}(\/\S*)?)\b',
      caseSensitive: false,
    );
    return websiteRegex
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();
  }

  // --- Heuristic detection methods (unchanged) ---

  bool looksLikeName(String text, Rect boundingBox, Size imageSize) {
    if (text.contains('@') || text.toLowerCase().contains('www')) return false;
    if (RegExp(r'\d').hasMatch(text)) return false;
    if (RegExp(r'(\+?\d[\d\s\-\(\)]{6,}\d)').hasMatch(text)) return false;

    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length < 1 || words.length > 4) return false;

    final capitalizedCount = words.where((w) {
      if (w.isEmpty) return false;
      final firstChar = w[0];
      return firstChar.toUpperCase() == firstChar &&
          RegExp(r'[A-ZÉÈÀÂÊÎÔÛÇ]').hasMatch(firstChar);
    }).length;

    if (capitalizedCount < words.length * 0.4) return false;

    final lowerText = text.toLowerCase();
    if (lowerText.contains('®') || lowerText.contains('™')) return false;

    final brandWords = [
      'real',
      'living',
      'estate',
      'inc',
      'llc',
      'corp',
      'group',
      'company',
      'société',
      'entreprise',
      'groupe',
      'compagnie',
      'associés',
      'commerce',
      'immobilier',
      'industries',
    ];

    if (brandWords.any((bw) => lowerText.contains(bw))) return false;

    if (boundingBox.left < imageSize.width * 0.15 &&
        boundingBox.top < imageSize.height * 0.15) {
      return false;
    }

    return true;
  }

  String? _guessName(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    final allLines = recognizedText.blocks
        .expand((block) => block.lines)
        .toList();
    if (allLines.isEmpty) return null;

    final imageHeight = recognizedText.blocks.first.boundingBox.bottom;
    final imageWidth = recognizedText.blocks.first.boundingBox.right;

    final companyName = _guessCompany(recognizedText);
    print('Company detected for exclusion in name guessing: $companyName');

    final candidates = <TextLine>[];

    for (final line in allLines) {
      final text = line.text.trim();
      final box = line.boundingBox;

      if (companyName != null &&
          companyName.toLowerCase() == text.toLowerCase()) {
        print('Exclude "$text": matches company name');
        continue;
      }

      if (!looksLikeName(text, box, Size(imageWidth, imageHeight))) {
        print('Exclude "$text": failed looksLikeName criteria');
        continue;
      }

      candidates.add(line);
      print('Accepted name candidate: "$text"');
    }

    if (candidates.isEmpty) {
      print('No valid name candidates found.');
      return null;
    }

    candidates.sort(
      (a, b) => b.boundingBox.height.compareTo(a.boundingBox.height),
    );
    print('Chosen name: "${candidates.first.text.trim()}"');

    return candidates.first.text.trim();
  }

  String? _guessProfession(List<String> lines, String? name) {
    if (name == null) return null;

    final nameIndex = lines.indexOf(name);
    if (nameIndex == -1) return null;

    bool looksLikeProfession(String line) {
      if (line.trim().isEmpty) return false;
      if (line.contains('@') ||
          line.toLowerCase().contains('www') ||
          RegExp(r'\+?\d').hasMatch(line))
        return false;
      final wordCount = line.trim().split(RegExp(r'\s+')).length;
      if (wordCount < 1 || wordCount > 6) return false;
      final professionKeywords = [
        'manager',
        'director',
        'engineer',
        'developer',
        'consultant',
        'expert',
        'realtor',
        'agent',
        'specialist',
        'analyst',
        'president',
        'vice',
        'sales',
        'marketing',
        'ceo',
        'cto',
        'directeur',
        'directrice',
        'ingénieur',
        'développeur',
        'consultant',
        'experte',
        'gestionnaire',
        'président',
        'présidente',
        'commercial',
        'technicien',
        'technicienne',
        'vendeur',
        'vendeuse',
        'analyste',
        'responsable',
        'représentant',
        'designer',
        'chef',
        'comptable',
      ];
      return professionKeywords.any((kw) => line.toLowerCase().contains(kw));
    }

    for (var i = nameIndex + 1; i <= nameIndex + 3 && i < lines.length; i++) {
      final candidate = lines[i];
      if (looksLikeProfession(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  String? _guessCompany(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    final allLines = recognizedText.blocks
        .expand((block) => block.lines)
        .toList();
    if (allLines.isEmpty) return null;

    final imageHeight = recognizedText.blocks.first.boundingBox.bottom;

    final companyKeywords = [
      'SARL',
      'SAS',
      'EURL',
      'SNC',
      'SA',
      'SCI',
      'ASSOCIATION',
      'ENTREPRISE',
      'Société',
      'Groupe',
      'SASU',
      'AUTO-ENTREPRENEUR',
      'CIE',
      'CO.',
      'LLC',
      'INC',
      'LTD',
      'BV',
      'CO',
      'PLC',
      'LLP',
      'GMBH',
      'PVT',
      'LIMITED',
      'CORP',
      'COMPANY',
      'GROUP',
    ];

    final fallbackCompanyWords = [
      'Entreprise',
      'Société',
      'Commerce',
      'Groupe',
      'Firme',
      'Logo',
      'Business',
      'Company',
    ];

    bool looksLikeCompany(String text) {
      final trimmed = text.trim();

      if (trimmed.isEmpty || trimmed.length < 2) {
        print('Reject company candidate (too short or empty): "$trimmed"');
        return false;
      }

      final hasKeyword = companyKeywords.any(
        (kw) => RegExp(
          r'\b' + RegExp.escape(kw) + r'\b',
          caseSensitive: false,
        ).hasMatch(trimmed),
      );

      final uppercaseLettersCount = trimmed
          .replaceAll(RegExp(r'[^A-Z]'), '')
          .length;
      final isAllUppercase =
          trimmed.isNotEmpty && (uppercaseLettersCount / trimmed.length) >= 0.6;

      final isCapitalized =
          trimmed.length > 0 && trimmed[0] == trimmed[0].toUpperCase();

      final line = allLines.firstWhere(
        (l) => l.text.trim() == trimmed,
        orElse: () => allLines.first,
      );
      final isNearBottom = line.boundingBox.top > imageHeight / 2;

      final isFallbackWord = fallbackCompanyWords.any(
        (word) => word.toLowerCase() == trimmed.toLowerCase(),
      );

      print(
        'Evaluating company candidate: "$trimmed" | hasKeyword: $hasKeyword | isAllUppercase: $isAllUppercase | isCapitalized: $isCapitalized | isNearBottom: $isNearBottom | isFallbackWord: $isFallbackWord',
      );

      return (hasKeyword && isNearBottom) ||
          (isAllUppercase && isNearBottom) ||
          (isCapitalized && isNearBottom && isFallbackWord);
    }

    final candidates = <String>[];

    for (final line in allLines) {
      final text = line.text.trim();
      if (looksLikeCompany(text)) {
        candidates.add(text);
        print('Accepted company candidate: "$text"');
      } else {
        print('Rejected company candidate: "$text"');
      }
    }

    if (candidates.isEmpty) {
      print('No company candidates found.');
      return null;
    }

    candidates.sort((a, b) => b.length.compareTo(a.length));

    print('Final chosen company name: "${candidates.first}"');

    return candidates.first;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
