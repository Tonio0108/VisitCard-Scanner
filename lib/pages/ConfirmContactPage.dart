import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/visit_card.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/services/database_service.dart';

class ConfirmFormPage extends StatefulWidget {
  final String? name;
  final String? org;
  final String? role;
  final String? image;
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
        ? widget.socials!.map((s) {
            return {
              'title': TextEditingController(text: s.title),
              'username': TextEditingController(text: s.userName),
            };
          }).toList()
        : [
            {
              'title': TextEditingController(),
              'username': TextEditingController(),
            },
          ];
  }

  @override
  void dispose() {
    nameController.dispose();
    orgController.dispose();
    roleController.dispose();
    emailController.dispose();
    for (var c in phoneControllers) c.dispose();
    for (var c in siteControllers) c.dispose();
    for (var pair in socialControllers) {
      pair['title']!.dispose();
      pair['username']!.dispose();
    }
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
    VoidCallback onAdd,
  ) {
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
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
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
          final controllers = entry.value;

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.share, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controllers['title'],
                    decoration: const InputDecoration(
                      hintText: 'Nom du réseau',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text("-", style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controllers['username'],
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
                    onPressed: () {
                      setState(() => socialControllers.removeAt(index));
                    },
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

  void saveData() async {
    if (_formKey.currentState!.validate()) {
      final savedName = nameController.text.trim();
      final savedOrg = orgController.text.trim();
      final savedRole = roleController.text.trim();
      final savedEmail = emailController.text.trim();

      final savedPhones = phoneControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .map((p) => Contact(phoneNumber: p))
          .toList();

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

      final visitCard = VisitCard(
        id: widget.id,
        fullName: savedName,
        organisationName: savedOrg,
        email: savedEmail,
        profession: savedRole,
        contacts: savedPhones,
        websites: savedWebsites,
        socialNetworks: savedSocials,
      );

      final db = DatabaseService.instance;

      if (visitCard.id != null) {
        await db.updateVisitCard(visitCard);
      } else {
        await db.insertVisitCard(visitCard);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact enregistré')));
      Navigator.pop(context);
    }
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
              // Photo
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
                                ? NetworkImage(widget.image!) as ImageProvider
                                : null),
                      child:
                          (_profileImage == null &&
                              (widget.image == null || widget.image!.isEmpty))
                          ? const Icon(Icons.add, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text("Changer la photo"),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Inputs
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom complet'),
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
              ),
              const SizedBox(height: 24),

              // Phones
              buildDynamicFieldList(
                "Téléphone(s)",
                phoneControllers,
                Icons.phone,
                'Numéro de téléphone',
                () => setState(
                  () => phoneControllers.add(TextEditingController()),
                ),
              ),
              const SizedBox(height: 16),

              // Sites
              buildDynamicFieldList(
                "Sites webs",
                siteControllers,
                Icons.language,
                'www.exemple.com',
                () => setState(
                  () => siteControllers.add(TextEditingController()),
                ),
              ),
              const SizedBox(height: 16),

              // Socials
              buildSocialFields(),
              const SizedBox(height: 32),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7D49FF),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
