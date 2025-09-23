import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';

class DriverProfile extends StatefulWidget {
  const DriverProfile({super.key});

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;
  bool _loading = false;
  bool _editing = false;

  final Map<String, TextEditingController> _fieldControllers = {};

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  void dispose() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> fetchProfile() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          profile = null;
        });
        return;
      }

      final data = await supabase
          .from('driver_profiles')
          .select('*')
          .eq('user_id', user.id)
          .single();

      if (!mounted) return;
      setState(() {
        profile = data;
        _initializeControllers();
      });
    } catch (e) {
      print('Exception fetching profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        profile = null;
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
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    _fieldControllers.clear();
    if (profile == null) return;
    profile!.forEach((key, value) {
      _fieldControllers[key] = TextEditingController(
        text: value == null ? '' : value.toString(),
      );
    });
  }

  final Set<String> _nonEditableKeys = {
    'user_id',
    'id',
    'created_at',
    'updated_at',
  };

  final Set<String> _hiddenKeys = {'id', 'user_id'};

  dynamic _coerceToOriginalType(dynamic originalValue, String newText) {
    if (originalValue == null) return newText;
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
      return trimmed;
    }
  }

  Future<void> _saveProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || profile == null) return;
      setState(() {
        _loading = true;
      });

      final Map<String, dynamic> updates = {};
      for (final entry in _fieldControllers.entries) {
        final key = entry.key;
        if (_nonEditableKeys.contains(key)) continue;
        if (profile!.containsKey(key)) {
          final original = profile![key];
          final coerced = _coerceToOriginalType(original, entry.value.text);
          updates[key] = coerced;
        }
      }

      if (updates.isNotEmpty) {
        final updated = await supabase
            .from('driver_profiles')
            .update(updates)
            .eq('user_id', user.id)
            .select();
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _editing = false;
        });
      }
      await fetchProfile();
    } catch (e) {
      print('Exception updating profile: $e');
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
    final username = (profile?['username'] ?? '') as String? ?? 'Driver';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 237, 223),
      body: SafeArea(
        child: _loading && profile == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchProfile,
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
                            backgroundColor: const Color.fromARGB(
                              255,
                              243,
                              105,
                              77,
                            ),
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : 'D',
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 243, 105, 77),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email.isNotEmpty ? email : '-',
                                  style: TextStyle(color: Colors.grey[700]),
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

                      if (profile != null) ..._buildDynamicFields(),

                      const SizedBox(height: 80),

                      if (_editing)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                243,
                                105,
                                77,
                              ),
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
        heroTag: 'driver_profile_edit_fab',
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 243, 105, 77),
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
    final keys = profile!.keys.toList();
    keys.sort((a, b) {
      if (a == 'username') return -1;
      if (b == 'username') return 1;
      return a.compareTo(b);
    });

    for (final key in keys) {
      if (_hiddenKeys.contains(key)) continue;
      final value = profile![key];
      final controller = _fieldControllers[key];
      if (controller == null) continue;

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
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color.fromARGB(255, 243, 105, 77)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 243, 105, 77),
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
        Text(label, style: TextStyle(color: Colors.grey[800])),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 243, 105, 77)),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey[900])),
    );
  }
}
