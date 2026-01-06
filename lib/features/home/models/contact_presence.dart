enum ContactPresence { onHeylo, invite }

class ContactItem {
  final String name;
  final String phone;
  final ContactPresence presence;
  final String? uid;
  final String? avatarUrl;

  const ContactItem({
    required this.name,
    required this.phone,
    required this.presence,
    this.uid,
    this.avatarUrl,
  });
}
