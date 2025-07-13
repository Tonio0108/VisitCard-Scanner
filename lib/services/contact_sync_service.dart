import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../models/visit_card.dart';
import '../models/contact.dart' as app_contact;
import 'database_service.dart';

class ContactSyncService {
  static final ContactSyncService instance = ContactSyncService._();
  ContactSyncService._();

  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<bool> hasContactsPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Save VisitCard to native contacts and mark as synced in DB
  Future<bool> saveToNativeContacts(VisitCard visitCard) async {
    if (!await hasContactsPermission()) {
      final granted = await requestContactsPermission();
      if (!granted) return false;
    }

    try {
      final existingContact = await _findExistingNativeContact(visitCard);
      final nameParts = visitCard.fullName.split(' ');

      Uint8List? avatar;
      if (visitCard.imageUrl != null && visitCard.imageUrl!.isNotEmpty) {
        final file = File(visitCard.imageUrl!);
        if (await file.exists()) {
          avatar = await file.readAsBytes();
        }
      }

      final contactData = Contact(
        name: Name(
          first: nameParts.first,
          last: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        ),
        organizations: visitCard.organisationName.isNotEmpty
            ? [
                Organization(
                  company: visitCard.organisationName,
                  title: visitCard.profession,
                ),
              ]
            : [],
        emails: visitCard.email.isNotEmpty
            ? [Email(visitCard.email, label: EmailLabel.work)]
            : [],
        phones: visitCard.contacts
            .map((c) => Phone(c.phoneNumber, label: PhoneLabel.mobile))
            .toList(),
        photo: avatar,
      );

      if (existingContact != null) {
        contactData.id = existingContact.id;

        // Update photo only if changed or not set in native contact
        final nativePhoto = existingContact.photoOrThumbnail;
        final isPhotoDifferent =
            (nativePhoto == null && avatar != null) ||
            (nativePhoto != null &&
                avatar != null &&
                !_listEquals(nativePhoto, avatar));

        if (isPhotoDifferent) {
          // FlutterContacts.updateContact replaces photo, so just call update
          await FlutterContacts.updateContact(contactData);
        } else {
          // Photo same or both null: update contact without photo (or with same photo)
          await FlutterContacts.updateContact(contactData);
        }
      } else {
        await FlutterContacts.insertContact(contactData);
      }

      // Update VisitCard sync status in DB
      final updatedCard = visitCard.copyWith(isSyncedToNative: true);
      await DatabaseService.instance.updateVisitCard(updatedCard);

      return true;
    } catch (e) {
      print('Error saving to native contacts: $e');
      return false;
    }
  }

  /// Helper to compare two Uint8List for equality
  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Match native contact using email or phone number
  Future<Contact?> _findExistingNativeContact(VisitCard visitCard) async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);

    for (final contact in contacts) {
      final contactEmails = contact.emails
          .map((e) => e.address.toLowerCase())
          .toSet();
      if (visitCard.email.isNotEmpty &&
          contactEmails.contains(visitCard.email.toLowerCase())) {
        return contact;
      }

      final contactPhones = contact.phones.map((p) => p.number).toSet();
      final cardPhones = visitCard.contacts.map((c) => c.phoneNumber).toSet();
      if (cardPhones.any(contactPhones.contains)) {
        return contact;
      }
    }

    return null;
  }

  /// Import native contacts as VisitCards
  Future<List<VisitCard>> importFromNativeContacts() async {
    if (!await hasContactsPermission()) {
      final granted = await requestContactsPermission();
      if (!granted) return [];
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: true,
      );

      final List<VisitCard> visitCards = [];

      for (final contact in contacts) {
        if (contact.displayName.isEmpty) continue;

        String company = '';
        String jobTitle = '';
        if (contact.organizations.isNotEmpty) {
          company = contact.organizations.first.company;
          jobTitle = contact.organizations.first.title;
        }

        String? imagePath;
        if (contact.photoOrThumbnail != null &&
            contact.photoOrThumbnail!.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/${contact.id}.jpg');
          await file.writeAsBytes(contact.photoOrThumbnail!);
          imagePath = file.path;
        }

        final visitCard = VisitCard(
          fullName: contact.displayName,
          organisationName: company,
          email: contact.emails.isNotEmpty ? contact.emails.first.address : '',
          profession: jobTitle,
          contacts: contact.phones
              .map((phone) => app_contact.Contact(phoneNumber: phone.number))
              .toList(),
          imageUrl: imagePath,
          // Set synced = true because imported from native
          isSyncedToNative: true,
        );

        if (visitCard.fullName.isNotEmpty &&
            (visitCard.email.isNotEmpty || visitCard.contacts.isNotEmpty)) {
          visitCards.add(visitCard);
        }
      }

      return visitCards;
    } catch (e) {
      print('Error importing from native contacts: $e');
      return [];
    }
  }

  /// Sync all VisitCards from DB to native contacts, update sync status in DB
  Future<int> syncAllToNativeContacts() async {
    final visitCards = await DatabaseService.instance.getAllVisitCards();
    int successCount = 0;

    for (final visitCard in visitCards) {
      final success = await saveToNativeContacts(visitCard);
      if (success) successCount++;
    }

    return successCount;
  }

  /// Import native contacts and save to app DB, merging existing
  Future<int> importAndSaveNativeContacts() async {
    final importedContacts = await importFromNativeContacts();
    final existingContacts = await DatabaseService.instance.getAllVisitCards();
    int successCount = 0;

    for (final visitCard in importedContacts) {
      try {
        final existingContact = await _findExistingAppContact(
          visitCard,
          existingContacts,
        );

        if (existingContact != null) {
          final hasChanges = _hasSignificantChanges(existingContact, visitCard);
          if (hasChanges) {
            final updatedCard = VisitCard(
              id: existingContact.id,
              fullName: visitCard.fullName,
              organisationName: visitCard.organisationName.isNotEmpty
                  ? visitCard.organisationName
                  : existingContact.organisationName,
              email: visitCard.email.isNotEmpty
                  ? visitCard.email
                  : existingContact.email,
              profession: visitCard.profession.isNotEmpty
                  ? visitCard.profession
                  : existingContact.profession,
              contacts: _mergeContacts(
                existingContact.contacts,
                visitCard.contacts,
              ),
              websites: existingContact.websites,
              socialNetworks: existingContact.socialNetworks,
              imageUrl: existingContact.imageUrl ?? visitCard.imageUrl,
              // Preserve sync status of existing DB contact
              isSyncedToNative:
                  true, // Always true because imported from native
            );

            await DatabaseService.instance.updateVisitCard(updatedCard);
            successCount++;
          }
        } else {
          // New contact imported from native => mark as synced
          final newCard = visitCard.copyWith(isSyncedToNative: true);
          await DatabaseService.instance.insertVisitCard(newCard);
          successCount++;
        }
      } catch (e) {
        print('Error saving imported contact: $e');
      }
    }

    return successCount;
  }

  /// Match app contact using email or phone number
  Future<VisitCard?> _findExistingAppContact(
    VisitCard newCard,
    List<VisitCard> existingContacts,
  ) async {
    for (final existing in existingContacts) {
      if (newCard.email.isNotEmpty &&
          existing.email.toLowerCase() == newCard.email.toLowerCase()) {
        return existing;
      }

      final existingPhones = existing.contacts
          .map((c) => c.phoneNumber)
          .toSet();
      final newPhones = newCard.contacts.map((c) => c.phoneNumber).toSet();

      if (newPhones.any(existingPhones.contains)) {
        return existing;
      }
    }

    return null;
  }

  /// Check for significant changes between existing and new contact
  bool _hasSignificantChanges(VisitCard existing, VisitCard newContact) {
    if (existing.organisationName != newContact.organisationName ||
        existing.email != newContact.email ||
        existing.profession != newContact.profession) {
      return true;
    }

    final existingPhones = existing.contacts.map((c) => c.phoneNumber).toSet();
    final newPhones = newContact.contacts.map((c) => c.phoneNumber).toSet();

    if (!existingPhones.containsAll(newPhones) ||
        !newPhones.containsAll(existingPhones)) {
      return true;
    }

    return false;
  }

  /// Merge contacts lists, avoiding duplicates
  List<app_contact.Contact> _mergeContacts(
    List<app_contact.Contact> existing,
    List<app_contact.Contact> newContacts,
  ) {
    final Set<String> existingPhones = existing
        .map((c) => c.phoneNumber)
        .toSet();
    final List<app_contact.Contact> merged = List.from(existing);

    for (final contact in newContacts) {
      if (!existingPhones.contains(contact.phoneNumber)) {
        merged.add(contact);
      }
    }

    return merged;
  }

  /// Check if VisitCard exists in native contacts (no DB call for sync status)
  Future<bool> existsInNativeContacts(VisitCard visitCard) async {
    if (!await hasContactsPermission()) return false;

    try {
      final existingContact = await _findExistingNativeContact(visitCard);
      return existingContact != null;
    } catch (e) {
      print('Error checking contact existence: $e');
      return false;
    }
  }

  /// Sync single contact to native
  Future<bool> syncContactToNative(VisitCard visitCard) async {
    return await saveToNativeContacts(visitCard);
  }

  /// Get sync status map from DB (persistent), avoid runtime native queries
  Future<Map<int, bool>> getSyncStatusForAllContacts() async {
    final visitCards = await DatabaseService.instance.getAllVisitCards();
    final Map<int, bool> syncStatus = {};

    for (final card in visitCards) {
      if (card.id != null) {
        syncStatus[card.id!] = card.isSyncedToNative;
      }
    }

    return syncStatus;
  }
}
