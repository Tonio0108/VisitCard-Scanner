import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ConfirmFormPage extends StatefulWidget {
  final String? name;
  final String? org;
  final String? role;
  final String? image;
  final String? email;
  final String? phone;
  final String? website;
  final String? social;

  const ConfirmFormPage({
    Key? key,
    this.name,
    this.org,
    this.role,
    this.image,
    this.email,
    this.phone,
    this.website,
    this.social,
  }) : super(key: key);

  @override
  State<ConfirmFormPage> createState() => _ConfirmFormPageState();
}


class _ConfirmFormPageState extends State<ConfirmFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController orgController;
  late TextEditingController roleController;
  late TextEditingController emailController;

  late List<TextEditingController> phoneControllers;
  late List<TextEditingController> siteControllers;
  late List<TextEditingController> socialControllers;

  File? _profileImage;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name ?? '');
    orgController = TextEditingController(text: widget.org ?? '');
    roleController = TextEditingController(text: widget.role ?? '');
    emailController = TextEditingController(text: widget.email ?? '');
    phoneControllers = [TextEditingController(text: widget.phone ?? '')];
    siteControllers = [TextEditingController(text: widget.website ?? '')];
    socialControllers = [TextEditingController(text: widget.social ?? '')];
  }

  @override
  void dispose() {
    nameController.dispose();
    orgController.dispose();
    roleController.dispose();
    emailController.dispose();
    for (var c in phoneControllers) { c.dispose(); }
    for (var c in siteControllers) { c.dispose(); }
    for (var c in socialControllers) { c.dispose(); }
    super.dispose();
  }

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
        title: const Text('Confirmer les données'),
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
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (widget.image != null && widget.image!.isNotEmpty
                              ? NetworkImage(widget.image!)
                              : null),
                      child: (_profileImage == null && (widget.image == null || widget.image!.isEmpty))
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
