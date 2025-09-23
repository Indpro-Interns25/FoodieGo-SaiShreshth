import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final supabase = Supabase.instance.client;
  bool _loading = false;
  bool _editing = false;
  Map<String, dynamic>? _profile;

  // Dynamic controllers for profile fields
  final Map<String, TextEditingController> _fieldControllers = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _profile = null;
        });
        return;
      }
      final data = await supabase
          .from('customer_profiles')
          .select('*')
          .eq('user_id', user.id)
          .single();
      debugPrint('Profile loaded: $data');

      setState(() {
        _profile = data;
        _initializeControllers();
      });
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException: ${e.code} ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile (${e.message})'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _profile = null;
      });
    } catch (e) {
      debugPrint('Unknown error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _profile = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _initializeControllers() {
    // Dispose old
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    _fieldControllers.clear();
    if (_profile == null) return;
    _profile!.forEach((key, value) {
      _fieldControllers[key] = TextEditingController(
        text: value == null ? '' : value.toString(),
      );
    });
  }

  // Keys not editable
  final Set<String> _nonEditableKeys = {
    'username',
    'email',
    'user_id',
    'id',
    'created_at',
    'updated_at',
  };

  // Keys not shown
  final Set<String> _hiddenKeys = {'id', 'user_id'};

  dynamic _coerceToOriginalType(dynamic originalValue, String newText) {
    if (originalValue == null) return newText; // default to string
    final trimmed = newText.trim();
    if (originalValue is int) {
      return int.tryParse(trimmed) ?? originalValue;
    } else if (originalValue is double) {
      return double.tryParse(trimmed) ?? originalValue;
    } else if (originalValue is num) {
      return num.tryParse(trimmed) ?? originalValue;
    } else if (originalValue is bool) {
      final lower = trimmed.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
      return originalValue;
    } else {
      // treat as string/date/json text
      return trimmed;
    }
  }

  Future<void> _saveProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || _profile == null) return;
      setState(() {
        _loading = true;
      });

      final Map<String, dynamic> updates = {};
      for (final entry in _fieldControllers.entries) {
        final key = entry.key;
        if (_nonEditableKeys.contains(key)) continue;
        // Only include keys that already exist in the row
        if (_profile!.containsKey(key)) {
          final original = _profile![key];
          final coerced = _coerceToOriginalType(original, entry.value.text);
          updates[key] = coerced;
        }
      }

      debugPrint('Updating profile for user_id=${user.id} with: $updates');

      if (updates.isNotEmpty) {
        final updated = await supabase
            .from('customer_profiles')
            .update(updates)
            .eq('user_id', user.id)
            .select();
        debugPrint('Update result rows: ${updated.length}');
        if (updated.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No profile row was updated (check RLS/policies).',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Nothing to update')));
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Colors.green,
        ),
      );
      if (mounted) {
        setState(() {
          _editing = false;
        });
      }
      // Reload to reflect server values
      await _loadProfile();
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException on save: ${e.code} ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile (${e.message})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Unknown error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatCreatedAt(dynamic value) {
    if (value == null) return '-';
    try {
      final dt = DateTime.tryParse(value.toString())?.toLocal();
      if (dt == null) return value.toString();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final mon = months[dt.month - 1];
      final year = dt.year;
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $mon $year, $hour12:$minute $ampm';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    final username = (_profile?['username'] ?? '') as String? ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading && _profile == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email.isNotEmpty ? email : '-',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Your Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Render only columns present in the DB row
                      if (_profile != null) ..._buildDynamicFields(),

                      const SizedBox(height: 80), // space for FAB

                      if (_editing)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _loading ? null : _saveProfile,
                            icon: const Icon(Icons.save_outlined),
                            label: _loading
                                ? const Text('Saving...')
                                : const Text('Save changes'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'profile_edit_fab',
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        onPressed: _loading
            ? null
            : () {
                setState(() {
                  _editing = !_editing;
                });
              },
        child: Icon(_editing ? Icons.close : Icons.edit_outlined),
        tooltip: _editing ? 'Cancel edit' : 'Edit profile',
      ),
    );
  }

  List<Widget> _buildDynamicFields() {
    final widgets = <Widget>[];
    // Optional: order keys with username first
    final keys = _profile!.keys.toList();
    keys.sort((a, b) {
      if (a == 'username') return -1;
      if (b == 'username') return 1;
      return a.compareTo(b);
    });

    for (final key in keys) {
      if (_hiddenKeys.contains(key)) continue; // hide ids
      final value = _profile![key];
      final controller = _fieldControllers[key];
      if (controller == null) continue;

      // pretty display for created_at
      final displayValue = key == 'created_at'
          ? _formatCreatedAt(value)
          : (controller.text.isEmpty ? '-' : controller.text);

      widgets.add(
        _LabeledField(
          label: key,
          child: _nonEditableKeys.contains(key)
              ? _ReadOnlyMultiLine(text: displayValue)
              : (_editing
                    ? TextField(
                        controller: controller,
                        decoration: _inputDecoration('Edit $key'),
                        maxLines: value is String && value.length > 60 ? 3 : 1,
                      )
                    : _ReadOnlyMultiLine(text: displayValue)),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ReadOnlyMultiLine extends StatelessWidget {
  final String text;
  const _ReadOnlyMultiLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: TextStyle(color: AppColors.textPrimary)),
    );
  }
}
