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
  final List<SocialProfile> socialNetworks;

  OCRResult({
    required this.fullText,
    this.name,
    this.company,
    this.profession,
    required this.phones,
    required this.emails,
    required this.websites,
    required this.socialNetworks,
  });
}

class SocialProfile {
  final String platform;
  final String username;

  SocialProfile({required this.platform, required this.username});
}

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<OCRResult?> scanAndParseVisitCardFromCamera(
    BuildContext context,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return null;

    final imageFile = File(pickedFile.path);
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final text = recognizedText.text;

    // Sépare les lignes non vides, en conservant leur ordre d'apparition (important pour nom/profession)
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Extraction par regex
    final phones = _extractPhones(text);
    final emails = _extractEmails(text);
    final websites = _extractWebsites(text);
    final socialProfiles = _extractSocialProfiles(text);

    // Détection nom, compagnie, profession
    final name = _guessName(recognizedText);
    final profession = _guessProfession(lines, name);
    final company = _guessCompany(lines);

    // Affichage du texte détecté (max 100 caractères)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Texte détecté:\n${text.substring(0, text.length.clamp(0, 100))}...',
        ),
      ),
    );

    return OCRResult(
      fullText: text,
      name: name,
      company: company,
      profession: profession,
      phones: phones,
      emails: emails,
      websites: websites,
      socialNetworks: socialProfiles,
    );
  }

  // --- Extraction regex ---

  List<String> _extractPhones(String text) {
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\(\)]{6,}\d)');
    return phoneRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();
  }

  List<String> _extractEmails(String text) {
    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,}\b');
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

  List<SocialProfile> _extractSocialProfiles(String text) {
    final socialPlatforms = [
      'Facebook',
      'Twitter',
      'Instagram',
      'LinkedIn',
      'X',
      'GitHub',
    ];
    final profiles = <SocialProfile>[];

    for (final platform in socialPlatforms) {
      final regex = RegExp(
        '$platform[:\\s]*([\\w.@/_-]+)',
        caseSensitive: false,
      );
      final matches = regex.allMatches(text);
      for (final m in matches) {
        final username = m.group(1)?.trim() ?? '';
        if (username.isNotEmpty) {
          profiles.add(SocialProfile(platform: platform, username: username));
        }
      }
    }

    return profiles;
  }

  // --- Détection nom, compagnie, profession ---

  String? _guessName(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    // Flatten all lines from all blocks into one list
    final allLines = recognizedText.blocks.expand((block) => block.lines);

    // Find the line with the largest bounding box height
    TextLine? maxHeightLine;
    double maxHeight = 0;

    for (final line in allLines) {
      final height = line.boundingBox.height;
      if (height > maxHeight) {
        maxHeight = height;
        maxHeightLine = line;
      }
    }

    // Return text if it looks like a name (e.g., not an email or website)
    if (maxHeightLine != null) {
      final text = maxHeightLine.text.trim();
      if (!text.contains('@') && !text.toLowerCase().contains('www')) {
        return text;
      }
    }

    return null;
  }

  String? _guessProfession(List<String> lines, String? name) {
    if (name == null) return null;

    final nameIndex = lines.indexOf(name);
    if (nameIndex == -1) return null;

    // Helper function to check if a line looks like a profession line
    bool looksLikeProfession(String line) {
      if (line.trim().isEmpty) return false;
      if (line.contains('@') || line.toLowerCase().contains('www'))
        return false;
      if (RegExp(r'\+?\d').hasMatch(line))
        return false; // exclude phone numbers
      final wordCount = line.trim().split(RegExp(r'\s+')).length;
      if (wordCount < 2 || wordCount > 6) return false; // too short or too long
      return true;
    }

    // Check the line just below the name
    if (nameIndex + 1 < lines.length) {
      final candidate = lines[nameIndex + 1];
      if (looksLikeProfession(candidate)) {
        return candidate;
      }
    }

    // Look at next 2 lines below name for a candidate profession
    for (var i = nameIndex + 2; i <= nameIndex + 3 && i < lines.length; i++) {
      final candidate = lines[i];
      if (looksLikeProfession(candidate)) {
        return candidate;
      }
    }

    // Fallback: if no profession found, return null
    return null;
  }

  String? _guessCompany(List<String> lines) {
    // Cherche en partant du bas, une ligne en majuscule avec mots type SARL, LLC etc ou longue
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      final isUpper = line == line.toUpperCase() && line.length > 2;
      final hasCompanyKeywords = RegExp(
        r'(SARL|LLC|INC|LTD|ENTREPRISE|SAS|CORP|COMPANY|GROUP|SA|BV)',
        caseSensitive: false,
      ).hasMatch(line);

      if (isUpper || hasCompanyKeywords) {
        return line.trim();
      }
    }

    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
