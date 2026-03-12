class CollabMember {
  const CollabMember({
    required this.email,
    required this.name,
  });

  final String email;
  final String name;

  factory CollabMember.fromJson(Map<String, dynamic> json) {
    return CollabMember(
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class CollabRoom {
  const CollabRoom({
    required this.id,
    required this.name,
    required this.ownerEmail,
    required this.ownerName,
    required this.isPublic,
    required this.createdAt,
    required this.memberCount,
    required this.members,
    required this.meetLink,
  });

  final String id;
  final String name;
  final String ownerEmail;
  final String ownerName;
  final bool isPublic;
  final String createdAt;
  final int memberCount;
  final List<CollabMember> members;
  final String meetLink;

  factory CollabRoom.fromJson(Map<String, dynamic> json) {
    return CollabRoom(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerEmail: json['owner_email'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      members: (json['members'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CollabMember.fromJson)
          .toList(),
      meetLink: json['meet_link'] as String? ?? '',
    );
  }
}
