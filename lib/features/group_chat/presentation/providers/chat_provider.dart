import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../providers.dart';
import '../../../../services/ollama_service.dart';
import '../../domain/chat_message.dart';
import '../../domain/group_chat_model.dart';

GroupMember aiBotMember = GroupMember(
  id: 'ai_assistant',
  name: 'AI Assistant',
  email: 'ai@shiftmate.com',
  department: 'AI',
  jobTitle: 'LlamaBot',
  role: MemberRole.member,
  isOnline: true,
);

final ollamaServiceProvider = Provider<OllamaService>((ref) {
  return OllamaService(baseUrl: ref.watch(ollamaBaseUrlProvider));
});

final ollamaBaseUrlProvider = StateProvider<String>((ref) => '');

final ollamaConnectionProvider = StateProvider<bool>((ref) => false);

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
    _checkOllamaConnection();
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
          role: (data['role'] ?? 'worker') == 'admin' ? MemberRole.admin : MemberRole.member,
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
    state = state.copyWith(groups: [
      GroupChat(
        id: 'group_all',
        name: 'All Employees',
        description: 'Company-wide announcements and discussions',
        iconType: GroupIconType.emoji,
        iconEmoji: '\u{1F465}',
        members: [...state.allEmployees, aiBotMember],
        createdAt: now.subtract(const Duration(days: 30)),
        lastActivity: now,
        aiEnabled: true,
      ),
    ]);
  }

  void _checkOllamaConnection() async {
    final baseUrl = _ref.read(ollamaBaseUrlProvider);
    final ollama = OllamaService(baseUrl: baseUrl);
    final connected = await ollama.checkConnection();
    if (mounted) {
      _ref.read(ollamaConnectionProvider.notifier).state = connected;
    }
  }

  String get _currentUserId {
    return _ref.read(authProvider).user?.id ?? 'emp1';
  }

  String get _currentUserName {
    return _ref.read(authProvider).user?.name ?? 'You';
  }

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
      type: hasMentions && mentionedIds.isNotEmpty ? MessageType.mention : MessageType.text,
      mentionedUserIds: mentionedIds,
      readBy: {_currentUserId: true},
    );

    final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
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

    _simulateReadReceipts(groupId, newMessage.id);

    if (trimmed.startsWith('@AI ') || trimmed.startsWith('@ai ') || trimmed.startsWith('@llama ') || trimmed.startsWith('@Llama ')) {
      final query = trimmed.replaceFirst(RegExp(r'^@AI|^@ai|^@llama|^@Llama', caseSensitive: false), '').trim();
      if (query.isNotEmpty) {
        _triggerAiResponse(groupId, query);
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
        if (args.isNotEmpty) _triggerAiResponse(groupId, args);
        break;
      case 'summarize':
        _triggerAiSummary(groupId);
        break;
      case 'translate':
        if (args.isNotEmpty) _triggerAiTranslate(groupId, args);
        break;
      case 'draft':
        if (args.isNotEmpty) _triggerAiDraft(groupId, args);
        break;
      case 'action-items':
        _triggerAiActionItems(groupId);
        break;
      default:
        _triggerAiResponse(groupId, command);
    }
  }

  void _triggerAiResponse(String groupId, String query) {
    if (_isRateLimited()) {
      final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
      messages.add(ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: 'Please wait a moment before sending another AI request.',
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: state.groups.firstWhere((g) => g.id == groupId).aiModel,
      ));
      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
      );
      return;
    }

    final group = state.groups.firstWhere((g) => g.id == groupId);
    if (!group.aiEnabled) return;

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final baseUrl = group.aiBaseUrl ?? _ref.read(ollamaBaseUrlProvider);
    final ollama = OllamaService(baseUrl: baseUrl);

    final contextMessages = state.messagesByGroup[groupId] ?? [];
    final recentMessages = contextMessages.takeLast(group.aiMaxContextMessages);
    final chatHistory = recentMessages.map((m) {
      return OllamaMessage(
        role: m.senderName == 'AI Assistant' ? 'assistant' : 'user',
        content: '${m.senderName}: ${m.messageText}',
      );
    }).toList();

    ollama.chat(
      model: group.aiModel,
      messages: chatHistory,
      systemPrompt: group.effectiveSystemPrompt,
      temperature: group.aiTemperature,
    ).then((response) {
      final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
      messages.add(ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: response.content,
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: response.model,
        responseTimeMs: response.responseTimeMs,
        tokenCount: response.tokenCount,
        readBy: {_currentUserId: true},
      ));

      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
        aiIsThinking: false,
        lastAiCallTime: DateTime.now(),
      );
    }).catchError((e) {
      final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
      messages.add(ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: 'AI is unavailable. Please check your Ollama connection.',
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: group.aiModel,
        readBy: {_currentUserId: true},
      ));

      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
        aiIsThinking: false,
      );
    });
  }

  void _triggerAiSummary(String groupId) {
    final group = state.groups.firstWhere((g) => g.id == groupId);
    if (!group.aiEnabled) return;

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final baseUrl = group.aiBaseUrl ?? _ref.read(ollamaBaseUrlProvider);
    final ollama = OllamaService(baseUrl: baseUrl);

    final contextMessages = state.messagesByGroup[groupId] ?? [];
    final recentMessages = contextMessages.takeLast(group.aiMaxContextMessages);

    ollama.summarizeMessages(
      model: group.aiModel,
      messages: recentMessages,
      temperature: group.aiTemperature,
    ).then((content) {
      final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
      messages.add(ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: '📋 **Chat Summary**\n\n$content',
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: group.aiModel,
        readBy: {_currentUserId: true},
      ));
      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
        aiIsThinking: false,
        lastAiCallTime: DateTime.now(),
      );
    }).catchError((_) {
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerAiTranslate(String groupId, String targetLanguage) {
    final group = state.groups.firstWhere((g) => g.id == groupId);
    if (!group.aiEnabled) return;

    final messages = state.messagesByGroup[groupId] ?? [];
    if (messages.isEmpty) return;

    final lastMessage = messages.last;
    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final baseUrl = group.aiBaseUrl ?? _ref.read(ollamaBaseUrlProvider);
    final ollama = OllamaService(baseUrl: baseUrl);

    ollama.translateMessage(
      model: group.aiModel,
      text: lastMessage.messageText,
      targetLanguage: targetLanguage,
    ).then((content) {
      final updatedMessages = List<ChatMessage>.from(messages);
      updatedMessages.add(ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: '🌐 **Translation to $targetLanguage**\n\n"${lastMessage.messageText}"\n\n➡️ $content',
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: group.aiModel,
        readBy: {_currentUserId: true},
      ));

      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = updatedMessages,
        aiIsThinking: false,
        lastAiCallTime: DateTime.now(),
      );
    }).catchError((_) {
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerAiDraft(String groupId, String topic) {
    final group = state.groups.firstWhere((g) => g.id == groupId);
    if (!group.aiEnabled) return;

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final baseUrl = group.aiBaseUrl ?? _ref.read(ollamaBaseUrlProvider);
    final ollama = OllamaService(baseUrl: baseUrl);

    ollama.draftContent(
      model: group.aiModel,
      topic: topic,
      temperature: group.aiTemperature,
    ).then((content) {
      final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
      messages.add(ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: '✍️ **Draft: $topic**\n\n$content',
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: group.aiModel,
        readBy: {_currentUserId: true},
      ));
      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
        aiIsThinking: false,
        lastAiCallTime: DateTime.now(),
      );
    }).catchError((_) {
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void _triggerAiActionItems(String groupId) {
    final group = state.groups.firstWhere((g) => g.id == groupId);
    if (!group.aiEnabled) return;

    state = state.copyWith(aiIsThinking: true, aiThinkingGroupId: groupId);

    final baseUrl = group.aiBaseUrl ?? _ref.read(ollamaBaseUrlProvider);
    final ollama = OllamaService(baseUrl: baseUrl);

    final contextMessages = state.messagesByGroup[groupId] ?? [];
    final recentMessages = contextMessages.takeLast(group.aiMaxContextMessages);

    ollama.extractActionItems(
      model: group.aiModel,
      messages: recentMessages,
    ).then((content) {
      final messages = List<ChatMessage>.from(state.messagesByGroup[groupId] ?? []);
      messages.add(ChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        senderId: 'ai_assistant',
        senderName: 'AI Assistant',
        messageText: '✅ **Action Items**\n\n$content',
        timestamp: DateTime.now(),
        type: MessageType.ai,
        aiModel: group.aiModel,
        readBy: {_currentUserId: true},
      ));
      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = messages,
        aiIsThinking: false,
        lastAiCallTime: DateTime.now(),
      );
    }).catchError((_) {
      state = state.copyWith(aiIsThinking: false);
    });
  }

  void updateAiSettings(String groupId, {
    bool? aiEnabled,
    String? aiModel,
    double? aiTemperature,
    int? aiMaxContextMessages,
    String? aiSystemPrompt,
    String? aiBaseUrl,
  }) {
    final updatedGroups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          aiEnabled: aiEnabled,
          aiModel: aiModel,
          aiTemperature: aiTemperature,
          aiMaxContextMessages: aiMaxContextMessages,
          aiSystemPrompt: aiSystemPrompt,
          aiBaseUrl: aiBaseUrl,
        );
      }
      return g;
    }).toList();
    state = state.copyWith(groups: updatedGroups);
  }

  void updateAiFeedback(String groupId, String messageId, bool positive) {
    final messages = state.messagesByGroup[groupId] ?? [];
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final updatedMessages = List<ChatMessage>.from(messages);
      updatedMessages[index] = messages[index].copyWith(feedbackPositive: positive);
      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = updatedMessages,
      );
    }
  }

  void _simulateReadReceipts(String groupId, String messageId) {
    Future.delayed(const Duration(seconds: 2), () {
      final messages = state.messagesByGroup[groupId];
      if (messages == null || messages.isEmpty) return;
      final msgIndex = messages.indexWhere((m) => m.id == messageId);
      if (msgIndex == -1) return;

      final group = state.groups.firstWhere((g) => g.id == groupId);
      final updatedReadBy = Map<String, bool>.from(messages[msgIndex].readBy);
      for (final member in group.members) {
        if (member.id != _currentUserId && member.isOnline) {
          updatedReadBy[member.id] = true;
        }
      }

      final updatedMessages = List<ChatMessage>.from(messages);
      updatedMessages[msgIndex] = messages[msgIndex].copyWith(readBy: updatedReadBy);

      state = state.copyWith(
        messagesByGroup: Map.from(state.messagesByGroup)..[groupId] = updatedMessages,
      );
    });
  }

  void createGroup({
    required String name,
    String? description,
    required List<GroupMember> members,
    String? emoji,
    String? color,
  }) {
    final now = DateTime.now();
    final currentUser = GroupMember(
      id: _ref.read(authProvider).user?.id ?? 'unknown',
      name: _ref.read(authProvider).user?.name ?? 'You',
      email: _ref.read(authProvider).user?.email ?? 'user@shiftmate.com',
      role: MemberRole.admin,
      isOnline: true,
    );

    final newGroup = GroupChat(
      id: 'group_${now.millisecondsSinceEpoch}',
      name: name,
      description: description,
      iconType: color != null ? GroupIconType.color : GroupIconType.emoji,
      iconEmoji: emoji,
      iconColor: color,
      members: [currentUser, ...members, aiBotMember],
      createdAt: now,
      lastActivity: now,
      aiEnabled: true,
    );

    state = state.copyWith(
      groups: [...state.groups, newGroup],
      messagesByGroup: Map.from(state.messagesByGroup)..[newGroup.id] = [],
    );
  }

  void addMember(String groupId, GroupMember member) {
    final updatedGroups = state.groups.map((g) {
      if (g.id == groupId && !g.members.any((m) => m.id == member.id)) {
        return g.copyWith(
          members: [...g.members, member],
          lastActivity: DateTime.now(),
        );
      }
      return g;
    }).toList();

    state = state.copyWith(groups: updatedGroups);
  }

  void removeMember(String groupId, String memberId) {
    if (memberId == 'ai_assistant') return;
    final updatedGroups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          members: g.members.where((m) => m.id != memberId).toList(),
          lastActivity: DateTime.now(),
        );
      }
      return g;
    }).toList();

    state = state.copyWith(groups: updatedGroups);
  }

  void updateGroupInfo(String groupId, {String? name, String? description, String? emoji, String? color}) {
    final updatedGroups = state.groups.map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          name: name,
          description: description,
          iconType: color != null ? GroupIconType.color : (emoji != null ? GroupIconType.emoji : null),
          iconEmoji: emoji,
          iconColor: color,
        );
      }
      return g;
    }).toList();

    state = state.copyWith(groups: updatedGroups);
  }

  void changeMemberRole(String groupId, String memberId, MemberRole newRole) {
    if (memberId == 'ai_assistant') return;
    final updatedGroups = state.groups.map((g) {
      if (g.id == groupId) {
        final updatedMembers = g.members.map((m) {
          if (m.id == memberId) {
            return m.copyWith(role: newRole);
          }
          return m;
        }).toList();
        return g.copyWith(members: updatedMembers);
      }
      return g;
    }).toList();

    state = state.copyWith(groups: updatedGroups);
  }

  void deleteGroup(String groupId) {
    state = state.copyWith(
      groups: state.groups.where((g) => g.id != groupId).toList(),
      messagesByGroup: Map.from(state.messagesByGroup)..remove(groupId),
      activeGroupId: state.activeGroupId == groupId ? null : state.activeGroupId,
    );
  }

  void leaveGroup(String groupId) {
    removeMember(groupId, _currentUserId);
    deleteGroup(groupId);
  }

  void incrementUnread(String groupId) {
    if (state.activeGroupId == groupId) return;
    final current = state.getUnreadCount(groupId);
    state = state.copyWith(
      unreadCounts: Map.from(state.unreadCounts)..[groupId] = current + 1,
    );
  }

  void simulateTyping(String groupId, String userName) {
    final typing = List<String>.from(state.typingUsersByGroup[groupId] ?? []);
    if (!typing.contains(userName)) {
      typing.add(userName);
      state = state.copyWith(
        typingUsersByGroup: Map.from(state.typingUsersByGroup)..[groupId] = typing,
      );

      Future.delayed(const Duration(seconds: 3), () {
        final currentTyping = state.typingUsersByGroup[groupId] ?? [];
        if (currentTyping.contains(userName)) {
          state = state.copyWith(
            typingUsersByGroup: Map.from(state.typingUsersByGroup)..[groupId] = currentTyping.where((u) => u != userName).toList(),
          );
        }
      });
    }
  }
}

final employeeSearchProvider = StateProvider<String>((ref) => '');

final filteredEmployeesProvider = Provider<List<GroupMember>>((ref) {
  final search = ref.watch(employeeSearchProvider).toLowerCase();
  final allEmployees = ref.watch(chatProvider.select((s) => s.allEmployees));
  
  if (search.isEmpty) return allEmployees;
  
  return allEmployees.where((e) {
    return e.name.toLowerCase().contains(search) ||
           e.email.toLowerCase().contains(search) ||
           e.role.toString().toLowerCase().contains(search);
  }).toList();
});

extension ListExt<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
