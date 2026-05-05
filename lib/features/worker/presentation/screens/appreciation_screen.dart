import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers.dart';
import '../../../../services/appreciation_service.dart';
import '../../../../services/user_service.dart';

class AppreciationScreen extends ConsumerStatefulWidget {
  const AppreciationScreen({super.key});

  @override
  ConsumerState<AppreciationScreen> createState() => _AppreciationScreenState();
}

class _AppreciationScreenState extends ConsumerState<AppreciationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  String? _selectedRecipientId;
  String? _selectedRecipientName;
  String _selectedType = 'appreciation';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selectedRecipientId == null || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select recipient and enter message')));
      return;
    }

    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;

    try {
      await AppreciationService().send(
        senderId: user?.id ?? '',
        senderName: user?.name ?? 'Unknown',
        recipientId: _selectedRecipientId!,
        recipientName: _selectedRecipientName!,
        messageType: _selectedType,
        message: _messageController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appreciation sent!'), backgroundColor: AppTheme.accentColor));
        _messageController.clear();
        setState(() => _selectedRecipientId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final sent = ref.watch(sentAppreciationsProvider(user?.id ?? ''));
    final received = ref.watch(receivedAppreciationsProvider(user?.id ?? ''));
    final workers = ref.watch(workersProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/dashboard');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appreciation'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboard')),
          bottom: TabBar(controller: _tabController, labelColor: AppTheme.primaryColor, tabs: const [Tab(text: 'Send'), Tab(text: 'History')]),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send Appreciation', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  workers.when(
                    data: (data) => DropdownButtonFormField<String>(
                      initialValue: _selectedRecipientId,
                      decoration: const InputDecoration(labelText: 'Select Recipient', prefixIcon: Icon(Icons.person)),
                      items: data.where((w) => w.uid != user?.id).map((w) => DropdownMenuItem(value: w.uid, child: Text(w.name))).toList(),
                      onChanged: (v) {
                        final worker = data.firstWhere((w) => w.uid == v);
                        setState(() {
                          _selectedRecipientId = v;
                          _selectedRecipientName = worker.name;
                        });
                      },
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(labelText: 'Message Type', prefixIcon: Icon(Icons.category)),
                    items: const [
                      DropdownMenuItem(value: 'appreciation', child: Text('👏 Appreciation')),
                      DropdownMenuItem(value: 'greeting', child: Text('🎉 Greeting')),
                      DropdownMenuItem(value: 'milestone', child: Text('🏆 Milestone')),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v ?? 'appreciation'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Message', hintText: 'Write your message...', prefixIcon: Icon(Icons.message)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _send,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(labelColor: AppTheme.primaryColor, tabs: const [Tab(text: 'Sent'), Tab(text: 'Received')]),
                  Expanded(
                    child: TabBarView(
                      children: [
                        sent.when(
                          data: (data) => data.isEmpty
                              ? const Center(child: Text('No appreciations sent yet'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: data.length,
                                  itemBuilder: (_, i) => _buildAppreciationCard(data[i]),
                                ),
                          loading: () => const CircularProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                        received.when(
                          data: (data) => data.isEmpty
                              ? const Center(child: Text('No appreciations received yet'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: data.length,
                                  itemBuilder: (_, i) => _buildAppreciationCard(data[i], isReceived: true),
                                ),
                          loading: () => const CircularProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppreciationCard(Appreciation app, {bool isReceived = false}) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(app.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(child: Text(app.messageType.toUpperCase(), style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 8),
          Text(app.message),
          const SizedBox(height: 8),
          Text(
            isReceived ? 'From: ${app.senderName}' : 'To: ${app.recipientName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}