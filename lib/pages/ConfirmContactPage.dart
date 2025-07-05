import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ConfirmFormPage extends StatefulWidget {
  const ConfirmFormPage({super.key});

  @override
  State<ConfirmFormPage> createState() => _ConfirmFormPageState();
}

class _ConfirmFormPageState extends State<ConfirmFormPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final orgController = TextEditingController();
  final roleController = TextEditingController();
  final emailController = TextEditingController();

  List<TextEditingController> phoneControllers = [TextEditingController()];
  List<TextEditingController> siteControllers = [TextEditingController()];
  List<TextEditingController> socialControllers = [TextEditingController()];

  File? _profileImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Widget buildDynamicFieldList(
      String label,
      List<TextEditingController> controllers,
      IconData icon,
      String hint,
      VoidCallback onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: hint,
                    ),
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        controllers.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18, color: Colors.blue),
          label: Text('Ajouter ${label.toLowerCase()}', style: const TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau contact'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Photo de profil
              GestureDetector(
                onTap: _pickImage,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? const Icon(Icons.add, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text("Changer la photo"),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Champs de base
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom complet'),
              ),
              TextFormField(
                controller: orgController,
                decoration: const InputDecoration(labelText: "Nom de l'organisation"),
              ),
              TextFormField(
                controller: roleController,
                decoration: const InputDecoration(labelText: "Rôle dans l'organisation"),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 24),

              // Téléphones dynamiques
              buildDynamicFieldList(
                "Téléphone(s)",
                phoneControllers,
                Icons.phone,
                'Numéro de téléphone',
                () => setState(() => phoneControllers.add(TextEditingController())),
              ),

              const SizedBox(height: 16),

              // Sites web dynamiques
              buildDynamicFieldList(
                "Sites webs",
                siteControllers,
                Icons.language,
                'www.exemple.com',
                () => setState(() => siteControllers.add(TextEditingController())),
              ),

              const SizedBox(height: 16),

              // Réseaux sociaux dynamiques
              buildDynamicFieldList(
                "Réseaux sociaux",
                socialControllers,
                Icons.share,
                'facebook - nom',
                () => setState(() => socialControllers.add(TextEditingController())),
              ),

              const SizedBox(height: 32),

              // Boutons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // TODO: Sauvegarder les données
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact enregistré')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7D49FF),
                      foregroundColor: Colors.white
                    ),
                    child: const Text('Confirmer'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
