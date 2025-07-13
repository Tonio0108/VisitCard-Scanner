import 'package:flutter/material.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/visit_card.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'package:visit_card_scanner/services/contact_sync_service.dart';
import 'ConfirmContactPage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

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
  });

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  bool _phonesExpanded = false;
  bool _websitesExpanded = false;
  bool _socialsExpanded = false;
  bool _isSavedToNative = false;
  bool _isCheckingNativeStatus = true;

  @override
  void initState() {
    super.initState();
    _checkNativeContactStatus();
  }

  Future<void> _checkNativeContactStatus() async {
    final visitCard = VisitCard(
      id: widget.id,
      fullName: widget.name,
      organisationName: widget.org,
      email: widget.email ?? '',
      profession: widget.role,
      contacts: widget.phones,
      websites: widget.websites ?? [],
      socialNetworks: widget.socials ?? [],
      imageUrl: widget.image,
    );
    final exists = await ContactSyncService.instance.existsInNativeContacts(
      visitCard,
    );
    setState(() {
      _isSavedToNative = exists;
      _isCheckingNativeStatus = false;
    });
  }

  Future<void> _saveToNativeContacts() async {
    // Create VisitCard object from widget data
    final visitCard = VisitCard(
      id: widget.id,
      fullName: widget.name,
      organisationName: widget.org,
      email: widget.email ?? '',
      profession: widget.role,
      contacts: widget.phones,
      websites: widget.websites ?? [],
      socialNetworks: widget.socials ?? [],
      imageUrl: widget.image,
    );

    final success = await ContactSyncService.instance.saveToNativeContacts(
      visitCard,
    );

    if (success) {
      setState(() => _isSavedToNative = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact sauvegardé dans les contacts natifs'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde')),
        );
      }
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
        content: const Text('Êtes-vous sûr de vouloir supprimer ce contact ?'),
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
      if (mounted) {
        Navigator.of(context).pop(true);
      }
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
          // Native contacts sync button
          if (!_isCheckingNativeStatus)
            IconButton(
              icon: Icon(
                _isSavedToNative
                    ? Icons.contacts
                    : Icons.contact_phone_outlined,
                color: _isSavedToNative ? Colors.green : Colors.grey,
              ),
              onPressed: _isSavedToNative ? null : _saveToNativeContacts,
              tooltip: _isSavedToNative
                  ? 'Déjà dans les contacts'
                  : 'Sauvegarder dans les contacts',
            ),
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

            // Show native contact status
            if (!_isCheckingNativeStatus)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSavedToNative
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 16,
                      color: _isSavedToNative ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSavedToNative
                          ? 'Dans les contacts natifs'
                          : 'Pas encore dans les contacts',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isSavedToNative ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
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
