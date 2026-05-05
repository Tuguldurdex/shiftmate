enum MemberRole { admin, member }

class GroupMember {
  final String id;
  final String name;
  final String email;
  final String? department;
  final String? jobTitle;
  final MemberRole role;
  final bool isOnline;

  GroupMember({
    required this.id,
    required this.name,
    required this.email,
    this.department,
    this.jobTitle,
    this.role = MemberRole.member,
    this.isOnline = false,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  GroupMember copyWith({
    String? name,
    String? email,
    String? department,
    String? jobTitle,
    MemberRole? role,
    bool? isOnline,
  }) {
    return GroupMember(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

enum GroupIconType { emoji, color }

class GroupChat {
  final String id;
  final String name;
  final String? description;
  final GroupIconType iconType;
  final String? iconEmoji;
  final String? iconColor;
  final List<GroupMember> members;
  final DateTime createdAt;
  final DateTime lastActivity;
  final bool aiEnabled;
  final String aiModel;
  final double aiTemperature;
  final int aiMaxContextMessages;
  final String? aiSystemPrompt;
  final String? aiBaseUrl;

  GroupChat({
    required this.id,
    required this.name,
    this.description,
    this.iconType = GroupIconType.emoji,
    this.iconEmoji,
    this.iconColor,
    required this.members,
    required this.createdAt,
    required this.lastActivity,
    this.aiEnabled = false,
    this.aiModel = 'llama3',
    this.aiTemperature = 0.7,
    this.aiMaxContextMessages = 15,
    this.aiSystemPrompt,
    this.aiBaseUrl,
  });

  int get memberCount => members.length;

  int get onlineMemberCount => members.where((m) => m.isOnline).length;

  String get effectiveSystemPrompt {
    if (aiSystemPrompt != null && aiSystemPrompt!.isNotEmpty) return aiSystemPrompt!;
    final memberNames = members.map((m) => m.name).join(', ');
    return 'You are a helpful AI assistant in a group chat called \'$name\'. Members: $memberNames. Be concise and professional.';
  }

  GroupMember? getAdmin() {
    return members.firstWhere(
      (m) => m.role == MemberRole.admin,
      orElse: () => members.first,
    );
  }

  bool isAdmin(String userId) {
    final member = members.firstWhere(
      (m) => m.id == userId,
      orElse: () => members.first,
    );
    return member.role == MemberRole.admin;
  }

  GroupChat copyWith({
    String? name,
    String? description,
    GroupIconType? iconType,
    String? iconEmoji,
    String? iconColor,
    List<GroupMember>? members,
    DateTime? lastActivity,
    bool? aiEnabled,
    String? aiModel,
    double? aiTemperature,
    int? aiMaxContextMessages,
    String? aiSystemPrompt,
    String? aiBaseUrl,
  }) {
    return GroupChat(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconType: iconType ?? this.iconType,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      iconColor: iconColor ?? this.iconColor,
      members: members ?? this.members,
      createdAt: createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiModel: aiModel ?? this.aiModel,
      aiTemperature: aiTemperature ?? this.aiTemperature,
      aiMaxContextMessages: aiMaxContextMessages ?? this.aiMaxContextMessages,
      aiSystemPrompt: aiSystemPrompt ?? this.aiSystemPrompt,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
    );
  }
}
