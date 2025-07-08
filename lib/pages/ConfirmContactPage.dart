import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/visit_card.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider

class ConfirmFormPage extends StatefulWidget {
  final String? name;
  final String? org;
  final String? role;
  final String? image; // This will now be the local path or null
  final String? email;
  final List<Contact>? phones;
  final List<Website>? websites;
  final List<SocialNetwork>? socials;
  final int? id;

  const ConfirmFormPage({
    super.key,
    this.name,
    this.org,
    this.role,
    this.image,
    this.email,
    this.phones,
    this.websites,
    this.socials,
    this.id,
  });

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
  late List<Map<String, TextEditingController>> socialControllers;

  File? _profileImage;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name ?? '');
    orgController = TextEditingController(text: widget.org ?? '');
    roleController = TextEditingController(text: widget.role ?? '');
    emailController = TextEditingController(text: widget.email ?? '');

    phoneControllers = (widget.phones != null && widget.phones!.isNotEmpty)
        ? widget.phones!
              .map((p) => TextEditingController(text: p.phoneNumber))
              .toList()
        : [TextEditingController()];

    siteControllers = (widget.websites != null && widget.websites!.isNotEmpty)
        ? widget.websites!
              .map((w) => TextEditingController(text: w.link))
              .toList()
        : [TextEditingController()];

    socialControllers = (widget.socials != null && widget.socials!.isNotEmpty)
        ? widget.socials!
              .map(
                (s) => {
                  'title': TextEditingController(text: s.title),
                  'username': TextEditingController(text: s.userName),
                },
              )
              .toList()
        : [
            {
              'title': TextEditingController(),
              'username': TextEditingController(),
            },
          ];

    // Initialize _profileImage if an image path is provided
    if (widget.image != null && widget.image!.isNotEmpty) {
      _profileImage = File(widget.image!);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    orgController.dispose();
    roleController.dispose();
    emailController.dispose();
    for (var c in phoneControllers) c.dispose();
    for (var c in siteControllers) c.dispose();
    for (var map in socialControllers) {
      map['title']!.dispose();
      map['username']!.dispose();
    }
    super.dispose();
  }

  Widget buildDynamicFieldList(
    String label,
    List<TextEditingController> controllers,
    IconData icon,
    String hint,
    TextInputType keyboardType,
    VoidCallback onAdd, {
    bool required = false,
  }) {
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
                    decoration: InputDecoration(hintText: hint),
                    keyboardType: keyboardType,
                    validator: required
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ce champ est requis';
                            }
                            return null;
                          }
                        : null,
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () =>
                        setState(() => controllers.removeAt(index)),
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18, color: Colors.blue),
          label: Text(
            'Ajouter ${label.toLowerCase()}',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget buildSocialFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Réseaux sociaux",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...socialControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.share, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controller['title'],
                    decoration: const InputDecoration(
                      hintText: 'Nom du réseau',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text("-", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Expanded(
                  child: TextFormField(
                    controller: controller['username'],
                    decoration: const InputDecoration(
                      hintText: "Nom d'utilisateur",
                    ),
                  ),
                ),
                if (socialControllers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () =>
                        setState(() => socialControllers.removeAt(index)),
                  ),
              ],
            ),
          );
        }).toList(),
        TextButton.icon(
          onPressed: () {
            setState(() {
              socialControllers.add({
                'title': TextEditingController(),
                'username': TextEditingController(),
              });
            });
          },
          icon: const Icon(Icons.add, size: 18, color: Colors.blue),
          label: const Text(
            'Ajouter un réseau social',
            style: TextStyle(color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  void saveData() async {
    if (!_formKey.currentState!.validate()) return;

    final savedPhones = phoneControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .map((p) => Contact(phoneNumber: p))
        .toList();

    if (savedPhones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Au moins un numéro de téléphone est requis"),
        ),
      );
      return;
    }

    final savedWebsites = siteControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .map((link) => Website(link: link))
        .toList();

    final savedSocials = socialControllers
        .where(
          (c) =>
              c['title']!.text.trim().isNotEmpty &&
              c['username']!.text.trim().isNotEmpty,
        )
        .map(
          (c) => SocialNetwork(
            title: c['title']!.text.trim(),
            userName: c['username']!.text.trim(),
          ),
        )
        .toList();

    String? imagePathToSave = widget.image; // Start with existing image path

    if (_profileImage != null) {
      // If a new image was picked, save it locally
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final String newPath = '${directory.path}/$fileName';
      final File savedImage = await _profileImage!.copy(newPath);
      imagePathToSave = savedImage.path;
    }

    final visitCard = VisitCard(
      id: widget.id,
      fullName: nameController.text.trim(),
      organisationName: orgController.text.trim(),
      email: emailController.text.trim(),
      profession: roleController.text.trim(),
      contacts: savedPhones,
      websites: savedWebsites,
      socialNetworks: savedSocials,
      imageUrl: imagePathToSave, // Pass the local image path here
    );

    final db = DatabaseService.instance;
    if (visitCard.id != null) {
      await db.updateVisitCard(visitCard);
    } else {
      await db.insertVisitCard(visitCard);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          visitCard.id == null ? 'Contact enregistré' : 'Contact mis à jour',
        ),
      ),
    );
    Navigator.pop(context, visitCard);
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
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: saveData),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null, // Only use FileImage if _profileImage is set
                      child:
                          (_profileImage ==
                              null) // Check if _profileImage is null
                          ? const Icon(Icons.add, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text("Changer la photo"),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ce champ est requis'
                    : null,
              ),
              TextFormField(
                controller: orgController,
                decoration: const InputDecoration(
                  labelText: "Nom de l'organisation",
                ),
              ),
              TextFormField(
                controller: roleController,
                decoration: const InputDecoration(
                  labelText: "Rôle dans l'organisation",
                ),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ce champ est requis';
                  } else if (!RegExp(
                    r'^[\w\.-]+@[\w\.-]+\.\w+$',
                  ).hasMatch(value.trim())) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              buildDynamicFieldList(
                "Téléphone(s)",
                phoneControllers,
                Icons.phone,
                'Numéro de téléphone',
                TextInputType.phone,
                () => setState(
                  () => phoneControllers.add(TextEditingController()),
                ),
                required: true,
              ),
              const SizedBox(height: 16),
              buildDynamicFieldList(
                "Sites webs",
                siteControllers,
                Icons.language,
                'www.exemple.com',
                TextInputType.url,
                () => setState(
                  () => siteControllers.add(TextEditingController()),
                ),
              ),
              const SizedBox(height: 16),
              buildSocialFields(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
