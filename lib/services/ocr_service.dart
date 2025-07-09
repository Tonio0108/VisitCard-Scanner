import 'dart:io';
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

  OCRResult({
    required this.fullText,
    this.name,
    this.company,
    this.profession,
    required this.phones,
    required this.emails,
    required this.websites,
  });
}

class OCRService {
  // Initialize TextRecognizer. For basic Latin script, default is usually fine.
  // If you want to explicitly hint for French, you could use:
  // final TextRecognizer _textRecognizer = TextRecognizer(script: TextScript.latin);
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<OCRResult?> scanAndParseVisitCardFromCamera(
    BuildContext context,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return null;

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

    // Split non-empty lines
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Extract structured info
    final phones = _extractPhones(text);
    final emails = _extractEmails(text);
    final websites = _extractWebsites(text);

    final name = _guessName(recognizedText);
    final profession = _guessProfession(lines, name);
    final company = _guessCompany(recognizedText);

    // Show short preview of detected text
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Carte scannée avec succès!")));

    return OCRResult(
      fullText: text,
      name: name,
      company: company,
      profession: profession,
      phones: phones,
      emails: emails,
      websites: websites,
    );
  }

  // --- Extraction regex ---

  List<String> _extractPhones(String text) {
    // This regex is designed to capture common phone number formats including
    // international prefixes, spaces, hyphens, and parentheses.
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\(\)]{6,}\d)');
    return phoneRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
  }

  List<String> _extractEmails(String text) {
    // Match any word containing '@' and a known domain keyword
    final emailRegex = RegExp(
      r'\b\S*@(?:gmail|yahoo|hotmail|outlook|icloud|protonmail|live|aol)\S*\b',
      caseSensitive: false,
    );

    return emailRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
  }

  List<String> _extractWebsites(String text) {
    // This regex matches common website formats, including optional http/https, www,
    // and various top-level domains, excluding patterns that look like emails.
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

  // --- Détection nom, compagnie, profession ---

  bool looksLikeName(String text, Rect boundingBox, Size imageSize) {
    // 1. Exclude URLs, emails, phones, digits
    if (text.contains('@') || text.toLowerCase().contains('www')) return false;
    if (RegExp(r'\d').hasMatch(text)) return false;
    if (RegExp(r'(\+?\d[\d\s\-\(\)]{6,}\d)').hasMatch(text)) return false;

    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length < 1 || words.length > 4) return false;

    // 2. Capitalization check - allow for relaxed scenario
    // At least 40% of words should start with an uppercase letter.
    final capitalizedCount = words.where((w) {
      if (w.isEmpty) return false;
      final firstChar = w[0];
      return firstChar.toUpperCase() == firstChar &&
          RegExp(r'[A-ZÉÈÀÂÊÎÔÛÇ]').hasMatch(firstChar);
    }).length;

    if (capitalizedCount < words.length * 0.4) return false;

    // 3. Exclude trademark/brand symbols
    final lowerText = text.toLowerCase();
    if (lowerText.contains('®') || lowerText.contains('™')) return false;

    // 4. Exclude common brand/company words
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

    // 5. Relax bounding box position check:
    //    Exclude if in top-left 15% x 15% of image, where logos or general info might be.
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

      // Exclude if the text matches the detected company name
      if (companyName != null &&
          companyName.toLowerCase() == text.toLowerCase()) {
        print('Exclude "$text": matches company name');
        continue;
      }

      // Use the looksLikeName heuristic to filter candidates
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

    // Choose candidate with the largest bounding box height (heuristic for prominent text/name)
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

    // Helper function to check if a line looks like a profession/title
    bool looksLikeProfession(String line) {
      if (line.trim().isEmpty) return false;
      // Exclude lines that look like contact info
      if (line.contains('@') ||
          line.toLowerCase().contains('www') ||
          RegExp(r'\+?\d').hasMatch(line))
        return false;
      final wordCount = line.trim().split(RegExp(r'\s+')).length;
      // Profession titles are usually between 1 and 6 words.
      if (wordCount < 1 || wordCount > 6) return false;
      // Common keywords for professions (can be expanded)
      final professionKeywords = [
        // English
        'manager', 'director', 'engineer', 'developer', 'consultant', 'expert',
        'realtor',
        'agent',
        'specialist',
        'analyst',
        'president',
        'vice',
        'sales',
        'marketing', 'ceo', 'cto',

        // French
        'directeur', 'directrice', 'ingénieur', 'développeur', 'consultant',
        'experte', 'gestionnaire', 'président', 'présidente', 'commercial',
        'technicien', 'technicienne', 'vendeur', 'vendeuse', 'analyste',
        'responsable', 'représentant', 'designer', 'chef', 'comptable',
      ];
      // Check if any word in the line is a recognized profession keyword (case-insensitive)
      return professionKeywords.any((kw) => line.toLowerCase().contains(kw));
    }

    // Look at lines immediately following the name
    // We check the next 3 lines as profession might not be directly adjacent.
    for (var i = nameIndex + 1; i <= nameIndex + 3 && i < lines.length; i++) {
      final candidate = lines[i];
      if (looksLikeProfession(candidate)) {
        return candidate;
      }
    }

    // Fallback: if no clear profession found
    return null;
  }

  String? _guessCompany(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    final allLines = recognizedText.blocks
        .expand((block) => block.lines)
        .toList();
    if (allLines.isEmpty) return null;

    final imageHeight = recognizedText.blocks.first.boundingBox.bottom;

    // Keywords commonly found in company names or legal forms.
    final companyKeywords = [
      'SARL', 'SAS', 'EURL', 'SNC', 'SA', 'SCI', 'ASSOCIATION', 'ENTREPRISE',
      'Société', 'Groupe', 'SASU', 'AUTO-ENTREPRENEUR', 'CIE', 'CO.',

      // English equivalents kept
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

    // Less formal words that often indicate a company name, used as fallbacks.

    bool looksLikeCompany(String text) {
      final trimmed = text.trim();

      if (trimmed.isEmpty || trimmed.length < 2) {
        print('Reject company candidate (too short or empty): "$trimmed"');
        return false;
      }

      // Check if the text contains any of the explicit company keywords (case-insensitive)
      final hasKeyword = companyKeywords.any(
        (kw) => RegExp(
          r'\b' + RegExp.escape(kw) + r'\b',
          caseSensitive: false,
        ).hasMatch(trimmed),
      );

      // Check if a significant portion of the text is in uppercase (e.g., acronyms)
      final uppercaseLettersCount = trimmed
          .replaceAll(RegExp(r'[^A-Z]'), '')
          .length;
      final isAllUppercase =
          trimmed.isNotEmpty &&
          (uppercaseLettersCount / trimmed.length) >=
              0.6; // At least 60% uppercase

      // Check if the first letter is capitalized (common for company names)
      final isCapitalized =
          trimmed.length > 0 && trimmed[0] == trimmed[0].toUpperCase();

      // Determine if the text block is in the lower half of the card (where company logos/names often appear)
      final line = allLines.firstWhere(
        (l) => l.text.trim() == trimmed,
        orElse: () => allLines.first,
      ); // Fallback to first line if not found
      final isNearBottom = line.boundingBox.top > imageHeight / 2;

      // Check if the text is one of the less formal fallback words
      final isFallbackWord = fallbackCompanyWords.any(
        (word) => word.toLowerCase() == trimmed.toLowerCase(),
      );

      print(
        'Evaluating company candidate: "$trimmed" | hasKeyword: $hasKeyword | isAllUppercase: $isAllUppercase | isCapitalized: $isCapitalized | isNearBottom: $isNearBottom | isFallbackWord: $isFallbackWord',
      );

      // A candidate is considered a company name if:
      // 1. It contains a strong company keyword AND is in the bottom half of the card, OR
      // 2. It is mostly uppercase AND is in the bottom half of the card, OR
      // 3. It is capitalized AND is in the bottom half AND matches a fallback company word.
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

    // Prioritize longer company names as they might be more complete.
    candidates.sort((a, b) => b.length.compareTo(a.length));

    print('Final chosen company name: "${candidates.first}"');

    return candidates.first;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
