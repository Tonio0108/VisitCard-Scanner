import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'ConfirmContactPage.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as native;

Future<void> _launchPhone(String number) async {
  final uri = Uri.parse('tel:$number');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _sendEmail(String email) async {
  final uri = Uri(scheme: 'mailto', path: email);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    print("Could not launch email client");
  }
}

class ContactDetailPage extends StatefulWidget {
  final String name;
  final String org;
  final String role;
  final String? image;
  final String? email;
  final List<Contact> phones;
  final List<Website>? websites;
  final List<SocialNetwork>? socials;
  final int id;
  final String? nativeId;

  const ContactDetailPage({
    super.key,
    required this.name,
    required this.org,
    required this.role,
    this.image,
    this.email,
    required this.phones,
    this.websites,
    this.socials,
    required this.id,
    this.nativeId,
  });

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  bool _phonesExpanded = false;
  bool _websitesExpanded = false;
  bool _socialsExpanded = false;
  bool _isInNativeContacts = true;

  @override
  void initState() {
    super.initState();
    _checkIfInNative();
  }

  Future<void> _checkIfInNative() async {
    final granted = await native.FlutterContacts.requestPermission();
    if (!granted) return;

    if (widget.nativeId != null) {
      final contact = await native.FlutterContacts.getContact(
        widget.nativeId!,
        withProperties: true,
      );
      setState(() => _isInNativeContacts = contact != null);
      return;
    }

    // fallback match if no nativeId
    final contacts = await native.FlutterContacts.getContacts(
      withProperties: true,
    );
    final exists = contacts.any(
      (c) =>
          c.name.first.toLowerCase() == widget.name.toLowerCase() &&
          (c.emails.any((e) => e.address == widget.email) ||
              c.phones.any(
                (p) =>
                    widget.phones.any((local) => local.phoneNumber == p.number),
              )),
    );
    setState(() => _isInNativeContacts = exists);
  }

  Future<void> _addToNativeContacts() async {
    final newContact = native.Contact()
      ..name = native.Name(first: widget.name)
      ..phones = widget.phones.map((p) => native.Phone(p.phoneNumber)).toList()
      ..emails = (widget.email?.isNotEmpty ?? false)
          ? [native.Email(widget.email!)]
          : []
      ..organizations = widget.org.isNotEmpty
          ? [native.Organization(company: widget.org, title: widget.role)]
          : [];

    if (widget.image != null && widget.image!.isNotEmpty) {
      final file = File(widget.image!);
      if (await file.exists()) {
        newContact.photo = await file.readAsBytes();
      }
    }

    await newContact.insert();

    if (mounted) {
      setState(() => _isInNativeContacts = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact ajouté aux contacts natifs")),
      );
    }
  }

  Widget _buildListCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
    required String seeAllText,
    required bool expanded,
    required VoidCallback onToggleExpanded,
    void Function(String)? onTapItem,
  }) {
    final displayItems = expanded ? items : items.take(1).toList();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD7D7D7)),
      ),
      child: Column(
        children: [
          ...displayItems.map(
            (item) => ListTile(
              leading: Icon(icon, color: iconColor),
              title: Text(
                item,
                style: icon == Icons.language
                    ? const TextStyle(color: Colors.blue)
                    : null,
              ),
              onTap: onTapItem != null ? () => onTapItem(item) : null,
            ),
          ),
          if (items.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onToggleExpanded,
                child: Text(
                  expanded ? 'Voir moins' : seeAllText,
                  style: TextStyle(
                    color: Colors.purple[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Etes-vous sûr de vouloir supprimer ce contact ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteVisitCard(widget.id);

      final granted = await native.FlutterContacts.requestPermission();
      if (granted) {
        final contacts = await native.FlutterContacts.getContacts(
          withProperties: true,
        );

        if (widget.nativeId != null) {
          final contact = await native.FlutterContacts.getContact(
            widget.nativeId!,
          );
          if (contact != null) await contact.delete();
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updatedCard = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConfirmFormPage(
                    id: widget.id,
                    name: widget.name,
                    org: widget.org,
                    role: widget.role,
                    image: widget.image,
                    email: widget.email,
                    phones: widget.phones,
                    websites: widget.websites,
                    socials: widget.socials,
                  ),
                ),
              );

              if (updatedCard != null && context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactDetailPage(
                      id: updatedCard.id!,
                      name: updatedCard.fullName,
                      org: updatedCard.organisationName,
                      role: updatedCard.profession,
                      image: updatedCard.imageUrl,
                      email: updatedCard.email,
                      phones: updatedCard.contacts,
                      websites: updatedCard.websites,
                      socials: updatedCard.socialNetworks,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color.fromARGB(255, 231, 231, 231),
              backgroundImage: widget.image != null && widget.image!.isNotEmpty
                  ? FileImage(File(widget.image!))
                  : null,
              child: (widget.image == null || widget.image!.isEmpty)
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              '${widget.org} - ${widget.role}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (!_isInNativeContacts)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.contact_phone, color: Colors.white),
                  label: const Text(
                    "Ajouter aux contacts natifs",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: _addToNativeContacts,
                ),
              ),
            const SizedBox(height: 24),
            if (widget.email != null && widget.email!.isNotEmpty)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.email, color: Colors.deepOrange),
                  title: Text(widget.email!),
                  trailing: IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepOrange),
                    onPressed: () => _sendEmail(widget.email!),
                  ),
                ),
              ),
            if (widget.phones.isNotEmpty)
              _buildListCard(
                icon: Icons.phone,
                iconColor: Colors.green,
                title: 'Téléphone(s)',
                items: widget.phones.map((c) => c.phoneNumber).toList(),
                seeAllText: 'Voir tous les numéros',
                expanded: _phonesExpanded,
                onToggleExpanded: () {
                  setState(() => _phonesExpanded = !_phonesExpanded);
                },
                onTapItem: _launchPhone,
              ),
            if (widget.websites != null && widget.websites!.isNotEmpty)
              _buildListCard(
                icon: Icons.language,
                iconColor: Colors.blue,
                title: 'Sites web',
                items: widget.websites!.map((w) => w.link).toList(),
                seeAllText: 'Voir tous les sites',
                expanded: _websitesExpanded,
                onToggleExpanded: () {
                  setState(() => _websitesExpanded = !_websitesExpanded);
                },
                onTapItem: _launchUrl,
              ),
            if (widget.socials != null && widget.socials!.isNotEmpty)
              _buildListCard(
                icon: Icons.alternate_email,
                iconColor: Colors.purple,
                title: 'Réseaux sociaux',
                items: widget.socials!
                    .map((s) => '${s.title} - ${s.userName}')
                    .toList(),
                seeAllText: 'Voir tous les réseaux',
                expanded: _socialsExpanded,
                onToggleExpanded: () {
                  setState(() => _socialsExpanded = !_socialsExpanded);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _confirmDelete,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
    );
  }
}
