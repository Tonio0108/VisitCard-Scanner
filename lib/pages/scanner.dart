import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visit_card_scanner/pages/confirmContactPage.dart';
class AddContactScreen extends StatelessWidget {
  const AddContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ajouter un contact',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                onPressed: () async {
                  final picker = ImagePicker();
                  final image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    // Traiter l'image scannée 
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image capturée !')),
                    );
                  }
                },
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scanner une carte'),
                backgroundColor: const Color(0xFF7D49FF),
                foregroundColor: Colors.white,
                elevation: 1,
              ),

              const SizedBox(height: 20),
              const Text(
                'ou',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConfirmFormPage()),
                  );
                },
                icon: const Icon(Icons.add, color: Color(0xFF7D49FF)),
                label: const Text(
                  'Ajouter manuellement',
                  style: TextStyle(
                    color: Color(0xFF7D49FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
