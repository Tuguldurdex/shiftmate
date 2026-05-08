import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../providers.dart';
import '../../../../services/groq_service.dart';
import '../../domain/chat_message.dart';
import '../../domain/group_chat_model.dart';

GroupMember aiBotMember = GroupMember(
  id: 'ai_assistant',
  name: 'ShiftMate AI',
  email: 'ai@shiftmate.com',
  department: 'AI',
  jobTitle: 'LlamaBot',
  role: MemberRole.member,
  isOnline: true,
);

final groqServiceProvider = Provider<GroqService>((ref) {
  return GroqService();
});

final groqConnectionProvider = StateProvider<bool>((ref) => false);

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

class ChatState {
  final List<GroupChat> groups;
  final Map<String, List<ChatMessage>> messagesByGroup;
  final String? activeGroupId;
  final Map<String, List<String>> typingUsersByGroup;
  final Map<String, int> unreadCounts;
  final List<GroupMember> allEmployees;
  final bool aiIsThinking;
  final String aiThinkingGroupId;
  final DateTime? lastAiCallTime;

  ChatState({
    this.groups = const [],
    this.messagesByGroup = const {},
    this.activeGroupId,
    this.typingUsersByGroup = const {},
    this.unreadCounts = const {},
    this.allEmployees = const [],
    this.aiIsThinking = false,
    this.aiThinkingGroupId = '',
    this.lastAiCallTime,
  });

  ChatState copyWith({
    List<GroupChat>? groups,
    Map<String, List<ChatMessage>>? messagesByGroup,
    String? activeGroupId,
    Map<String, List<String>>? typingUsersByGroup,
    Map<String, int>? unreadCounts,
    List<GroupMember>? allEmployees,
    bool? aiIsThinking,
    String? aiThinkingGroupId,
    DateTime? lastAiCallTime,
  }) {
    return ChatState(
      groups: groups ?? this.groups,
      messagesByGroup: messagesByGroup ?? this.messagesByGroup,
      activeGroupId: activeGroupId ?? this.activeGroupId,
      typingUsersByGroup: typingUsersByGroup ?? this.typingUsersByGroup,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      allEmployees: allEmployees ?? this.allEmployees,
      aiIsThinking: aiIsThinking ?? this.aiIsThinking,
      aiThinkingGroupId: aiThinkingGroupId ?? this.aiThinkingGroupId,
      lastAiCallTime: lastAiCallTime ?? this.lastAiCallTime,
    );
  }

  GroupChat? getActiveGroup() {
    if (activeGroupId == null) return null;
    return groups.firstWhere(
      (g) => g.id == activeGroupId,
      orElse: () => groups.first,
    );
  }

  List<ChatMessage> getActiveMessages() {
    if (activeGroupId == null) return [];
    return messagesByGroup[activeGroupId] ?? [];
  }

  int getUnreadCount(String groupId) => unreadCounts[groupId] ?? 0;
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  static const _aiRateLimit = Duration(seconds: 3);

  ChatNotifier(this._ref) : super(ChatState(allEmployees: [])) {
    _initFromFirestore();
    _checkGroqConnection();
  }

  void _initFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final employees = snapshot.docs.map((doc) {
        final data = doc.data();
        return GroupMember(
          id: doc.id,
          name: data['name'] ?? 'Unknown',
          email: data['email'] ?? '',
          department: data['department'],
          jobTitle: data['jobTitle'],
          role: (data['role'] ?? 'worker') == 'admin'
              ? MemberRole.admin
              : MemberRole.member,
          isOnline: data['isOnline'] ?? false,
        );
      }).toList();

      state = state.copyWith(allEmployees: employees);
      _initGroups();
    } catch (e) {
      debugPrint('Error loading users from Firestore: $e');
    }
  }

  void _initGroups() {
    final now = DateTime.now();
    state = state.copyWith(
      groups: [
        GroupChat(
          id: 'group_all',
          name: 'All Employees',
          description: 'Company-wide announcements and discussions',
          iconType: GroupIconType.emoji,
          iconEmoji: '🎵',
          members: [...state.allEmployees, aiBotMember],
          createdAt: now.subtract(const Duration(days: 30)),
          lastActivity: now,
          aiEnabled: true,
        ),
      ],
    );
  }

  void _checkGroqConnection() async {
    final groq = _ref.read(groqServiceProvider);
    final response = await groq.chat(
      messages: [GroqMessage(role: 'user', content: 'Hi')],
    );
    if (mounted) {
      _ref.read(groqConnectionProvider.notifier).state = response.success;
    }
  }

  String get _currentUserId => _ref.read(authProvider).user?.id ?? 'emp1';
  String get _currentUserName => _ref.read(authProvider).user?.name ?? 'You';

  void selectGroup(String groupId) {
    state = state.copyWith(
      activeGroupId: groupId,
      unreadCounts: Map.from(state.unreadCounts)..[groupId] = 0,
    );
  }

  bool _isRateLimited() {
    if (state.lastAiCallTime == null) return false;
    return DateTime.now().difference(state.lastAiCallTime!) < _aiRateLimit;
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty || state.activeGroupId == null) return;

    final groupId = state.activeGroupId!;
    final trimmed = text.trim();
    final hasMentions = trimmed.contains('@');
    final mentionedIds = <String>[];

    if (hasMentions) {
      for (final member in state.groups.firstWhere((g) => g.id == groupId).members) {
        if (trimmed.contains('@${member.name.split(' ')[0]}')) {
          mentionedIds.add(member.id);
        }
      }
    }

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      messageText: trimmed,
      timestamp: DateTime.now(),
      type: hasMentions && mentionedIds.isNotEmpty
          ? MessageType.mention
          : MessageType.text,
      mentionedUserIds: mentionedIds,
      readBy: {_currentUserId: true},
    );

    final messages = List<ChatMessage>.from(
      state.messagesByGroup[groupId] ?? [],
    );
    messages.add(newMessage);

    final updatedGroups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(lastActivity: DateTime.now());
      }
      return g;
    }).toList();

    state = state.copyWith(
      messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
      groups: updatedGroups,
    );

    if (trimmed.startsWith('@ai ') ||
        trimmed.startsWith('@AI ') ||
        trimmed.startsWith('@shiftmate ') ||
        trimmed.startsWith('@ShiftMate ')) {
      final query = trimmed
          .replaceFirst(
            RegExp(r'^@ai|^@AI|^@shiftmate|^@ShiftMate', caseSensitive: false),
            '',
          )
          .trim();
      if (query.isNotEmpty) {
        _triggerGroqResponse(groupId, query);
      }
    } else if (trimmed.startsWith('/ai ')) {
      _handleSlashCommand(groupId, trimmed.substring(4));
    }
  }

  void _handleSlashCommand(String groupId, String command) {
    final parts = command.split(' ');
    final action = parts.first.toLowerCase();
    final args = parts.skip(1).join(' ');

    switch (action) {
      case 'ask':
        if (args.isNotEmpty) _triggerGroqResponse(groupId, args);
        break;
      case 'summarize':
        _triggerGroqSummary(groupId);
        break;
      case 'translate':
        if (args.isNotEmpty) _triggerGroqTranslate(groupId, args);
        break;
      case 'draft':
        if (args.isNotEmpty) _triggerGroqDraft(groupId, args);
        break;
      case 'action-items':
        _triggerGroqActionItems(groupId);
        break;
      default:
        _triggerGroqResponse(groupId, command);
    }
  }

  void _triggerGroqResponse(String groupId, String query) {
    if (_isRateLimited()) {
      _addAiMessage(groupId, 'Please wait a moment before sending another AI request.');
      return;
    }

    final group = state.groups.firstWhere((g) => g.id == groupId);
    if (!group.aiEnabled) return;

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final groq = _ref.read(groqServiceProvider);

    // Build context from last 8 messages
    final contextMessages = state.messagesByGroup[groupId] ?? [];
    final recentMessages = contextMessages.length > 8
        ? contextMessages.sublist(contextMessages.length - 8)
        : contextMessages;

    final groqMessages = <GroqMessage>[
      GroqMessage(
        role: 'system',
        content:
            'You are ShiftMate AI, an assistant built into a shift scheduling app. You help workers and managers with shift-related questions, scheduling conflicts, and workplace communication. Be concise and friendly. Always respond in 2-3 sentences max.',
      ),
      ...recentMessages.map((m) {
        final role = m.senderName == 'ShiftMate AI' ? 'assistant' : 'user';
        return GroqMessage(
          role: role,
          content: '${m.senderName}: ${m.messageText}',
        );
      }),
      GroqMessage(role: 'user', content: query),
    ];

    groq.chat(messages: groqMessages).then((response) {
      _addAiMessage(
        groupId,
        response.success ? response.content : 'AI is unavailable right now.',
        model: response.model,
        responseTimeMs: response.responseTimeMs,
      );
      state = state.copyWith(
        aiIsThinking: false,
        lastAiCallTime: DateTime.now(),
      );
    }).catchError((e) {
      _addAiMessage(groupId, 'AI is unavailable right now.');
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerGroqSummary(String groupId) {
    final messages = state.messagesByGroup[groupId] ?? [];
    if (messages.isEmpty) return;

    final chatHistory = messages
        .map((m) => '${m.senderName}: ${m.messageText}')
        .join('\n');

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final groq = _ref.read(groqServiceProvider);
    groq
        .chat(
          messages: [
            GroqMessage(
              role: 'system',
              content:
                  'You are ShiftMate AI. Summarize the following group chat conversation concisely. Highlight key points and decisions made. Keep it to 2-3 sentences.',
            ),
            GroqMessage(role: 'user', content: chatHistory),
          ],
        )
        .then((response) {
      _addAiMessage(
        groupId,
        response.success ? response.content : 'Failed to generate summary.',
        model: response.model,
        responseTimeMs: response.responseTimeMs,
      );
      state = state.copyWith(aiIsThinking: false, lastAiCallTime: DateTime.now());
    }).catchError((e) {
      _addAiMessage(groupId, 'AI is unavailable right now.');
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerGroqTranslate(String groupId, String targetLanguage) {
    final messages = state.messagesByGroup[groupId] ?? [];
    if (messages.isEmpty) return;

    final lastMessage = messages.last;
    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final groq = _ref.read(groqServiceProvider);
    groq
        .chat(
          messages: [
            GroqMessage(
              role: 'system',
              content:
                  'You are ShiftMate AI. Translate the following text to $targetLanguage. Only output the translation.',
            ),
            GroqMessage(role: 'user', content: lastMessage.messageText),
          ],
        )
        .then((response) {
      _addAiMessage(
        groupId,
        response.success ? response.content : 'Failed to translate.',
        model: response.model,
        responseTimeMs: response.responseTimeMs,
      );
      state = state.copyWith(aiIsThinking: false, lastAiCallTime: DateTime.now());
    }).catchError((e) {
      _addAiMessage(groupId, 'AI is unavailable right now.');
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerGroqDraft(String groupId, String topic) {
    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final groq = _ref.read(groqServiceProvider);
    groq
        .chat(
          messages: [
            GroqMessage(
              role: 'system',
              content:
                  'You are ShiftMate AI. Draft a professional, clear message about: $topic. Keep it to 2-3 sentences.',
            ),
            GroqMessage(role: 'user', content: 'Draft a message'),
          ],
        )
        .then((response) {
      _addAiMessage(
        groupId,
        response.success ? response.content : 'Failed to draft message.',
        model: response.model,
        responseTimeMs: response.responseTimeMs,
      );
      state = state.copyWith(aiIsThinking: false, lastAiCallTime: DateTime.now());
    }).catchError((e) {
      _addAiMessage(groupId, 'AI is unavailable right now.');
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerGroqActionItems(String groupId) {
    final messages = state.messagesByGroup[groupId] ?? [];
    if (messages.isEmpty) return;

    final chatHistory = messages
        .map((m) => '${m.senderName}: ${m.messageText}')
        .join('\n');

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final groq = _ref.read(groqServiceProvider);
    groq
        .chat(
          messages: [
            GroqMessage(
              role: 'system',
              content:
                  'You are ShiftMate AI. Extract all action items from the following conversation. Format each as a bullet point with the responsible person if mentioned. Keep it concise.',
            ),
            GroqMessage(role: 'user', content: chatHistory),
          ],
        )
        .then((response) {
      _addAiMessage(
        groupId,
        response.success ? response.content : 'Failed to extract action items.',
        model: response.model,
        responseTimeMs: response.responseTimeMs,
      );
      state = state.copyWith(aiIsThinking: false, lastAiCallTime: DateTime.now());
    }).catchError((e) {
      _addAiMessage(groupId, 'AI is unavailable right now.');
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _addAiMessage(
    String groupId,
    String text, {
    String? model,
    int? responseTimeMs,
  }) {
    final messages = List<ChatMessage>.from(
      state.messagesByGroup[groupId] ?? [],
    );
    messages.add(
      ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'ShiftMate AI',
        messageText: text,
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: model,
        responseTimeMs: responseTimeMs,
        readBy: {_currentUserId: true},
      ),
    );
    state = state.copyWith(
      messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
    );
  }

  void updateAiFeedback(String groupId, String messageId, bool? positive) {
    final messages = state.messagesByGroup[groupId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    messages[index] = messages[index].copyWith(feedbackPositive: positive);
    state = state.copyWith(
      messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
    );
  }

  void updateGroupInfo(String groupId, {
    bool? aiEnabled,
    double? aiTemperature,
    int? aiMaxContextMessages,
    String? aiSystemPrompt,
    String? name,
    String? description,
    String? iconColor,
    GroupIconType? iconType,
    String? iconEmoji,
  }) {
    final groups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          aiEnabled: aiEnabled ?? g.aiEnabled,
          aiTemperature: aiTemperature ?? g.aiTemperature,
          aiMaxContextMessages: aiMaxContextMessages ?? g.aiMaxContextMessages,
          aiSystemPrompt: aiSystemPrompt ?? g.aiSystemPrompt,
          name: name ?? g.name,
          description: description ?? g.description,
          iconColor: iconColor ?? g.iconColor,
          iconType: iconType ?? g.iconType,
          iconEmoji: iconEmoji ?? g.iconEmoji,
        );
      }
      return g;
    }).toList();
    state = state.copyWith(groups: groups);
  }

  void changeMemberRole(String groupId, String memberId, MemberRole newRole) {
    final groups = state.groups.map((g) {
      if (g.id == groupId) {
        final members = g.members.map((m) {
          if (m.id == memberId) {
            return GroupMember(
              id: m.id,
              name: m.name,
              email: m.email,
              department: m.department,
              jobTitle: m.jobTitle,
              role: newRole,
              isOnline: m.isOnline,
            );
          }
          return m;
        }).toList();
        return g.copyWith(members: members);
      }
      return g;
    }).toList();
    state = state.copyWith(groups: groups);
  }

  void addMember(String groupId, GroupMember member) {
    final groups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(members: [...g.members, member]);
      }
      return g;
    }).toList();
    state = state.copyWith(groups: groups);
  }

  void removeMember(String groupId, String memberId) {
    final groups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          members: g.members.where((m) => m.id != memberId).toList(),
        );
      }
      return g;
    }).toList();
    state = state.copyWith(groups: groups);
  }

  void leaveGroup(String groupId, String userId) {
    removeMember(groupId, userId);
  }

  void deleteGroup(String groupId) {
    final groups = state.groups.where((g) => g.id != groupId).toList();
    state = state.copyWith(groups: groups);
  }

  void createGroup({
    required String name,
    String? description,
    required List<GroupMember> members,
    String? emoji,
    String? color,
  }) {
    final newGroup = GroupChat(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      iconType: GroupIconType.emoji,
      iconEmoji: emoji ?? '🎵',
      members: [...members, aiBotMember],
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      aiEnabled: true,
    );
    state = state.copyWith(groups: [...state.groups, newGroup]);
  }
}
