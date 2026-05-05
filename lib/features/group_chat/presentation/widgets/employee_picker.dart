import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/group_chat_model.dart';

class EmployeePicker extends ConsumerStatefulWidget {
  final List<GroupMember> preselected;
  final Function(List<GroupMember>) onConfirm;
  final List<String>? excludeIds;

  const EmployeePicker({
    super.key,
    this.preselected = const [],
    required this.onConfirm,
    this.excludeIds,
  });

  @override
  ConsumerState<EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends ConsumerState<EmployeePicker> {
  late List<GroupMember> _selected;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.preselected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(GroupMember employee) {
    setState(() {
      if (_selected.any((e) => e.id == employee.id)) {
        _selected.removeWhere((e) => e.id == employee.id);
      } else {
        _selected.add(employee);
      }
    });
  }

  void _removeSelection(GroupMember employee) {
    setState(() {
      _selected.removeWhere((e) => e.id == employee.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.error, size: 48, color: AppTheme.errorColor),
                  const SizedBox(height: 12),
                  Text('Error loading users: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final allUsers = snapshot.data?.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Unknown';
          final email = data['email'] ?? '';
          final role = data['role'] ?? 'worker';

          return GroupMember(
            id: doc.id,
            name: name,
            email: email,
            role: role == 'admin' ? MemberRole.admin : MemberRole.member,
            isOnline: false,
          );
        }).toList() ?? [];

        // Filter excluded IDs
        var availableEmployees = widget.excludeIds != null
            ? allUsers.where((e) => !widget.excludeIds!.contains(e.id)).toList()
            : allUsers;

        // Apply search filter
        final search = _searchController.text.toLowerCase();
        if (search.isNotEmpty) {
          availableEmployees = availableEmployees.where((e) {
            return e.name.toLowerCase().contains(search) ||
                   e.email.toLowerCase().contains(search) ||
                   e.role.toString().toLowerCase().contains(search);
          }).toList();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selected.map((member) => _buildAvatarChip(member)).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textLight),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textLight),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_selected.length} selected',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: availableEmployees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: AppTheme.textLight),
                          const SizedBox(height: 12),
                          Text(
                            search.isEmpty ? 'No users found in Firestore' : 'No users match your search',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: availableEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = availableEmployees[index];
                        final isSelected = _selected.any((e) => e.id == employee.id);
                        return _buildEmployeeTile(employee, isSelected);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              widget.onConfirm(_selected);
                              Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarChip(GroupMember member) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColorForMember(member).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _getColorForMember(member),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            member.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _getColorForMember(member),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeSelection(member),
            child: const Icon(Icons.close, size: 16, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTile(GroupMember employee, bool isSelected) {
    final initials = employee.initials;

    return InkWell(
      onTap: () => _toggleSelection(employee),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getColorForMember(employee),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (employee.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${employee.email}${employee.role == MemberRole.admin ? ' • Admin' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForMember(GroupMember member) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
    ];
    return colors[member.id.hashCode.abs() % colors.length];
  }
}
