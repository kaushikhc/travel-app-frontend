import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'profile_state.dart';
import '../../../core/time/api_time.dart';
import '../../places/presentation/country_picker.dart';
import '../../auth/presentation/auth_state.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  int? _homeCountryId;
  late TextEditingController _ageController;
  late TextEditingController _birthdayController;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _ageController = TextEditingController();
    _birthdayController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _initializeFields(ProfileState profileState) {
    if (profileState.profile != null) {
      final p = profileState.profile!;
      _displayNameController.text = p.displayName;
      _bioController.text = p.bio ?? '';
      _homeCountryId = p.homeCountryId;
      _ageController.text = p.age?.toString() ?? '';
      _birthdayController.text = p.birthday ?? '';
      _photoUrl = p.photoUrl;
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      setState(() {
        _photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageController.text);
    final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
          displayName: _displayNameController.text.trim(),
          bio: _bioController.text.trim(),
          homeCountryId: _homeCountryId,
          photoUrl: _photoUrl,
          age: age,
          birthday: _birthdayController.text.trim(),
        );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileState = ref.watch(profileNotifierProvider);

    // Populate input fields if not already editing and profile loaded
    if (!_isEditing && profileState.profile != null) {
      _initializeFields(profileState);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile & Achievements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isEditing && profileState.profile != null)
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(Icons.edit_note_outlined, size: 28),
              onPressed: () {
                setState(() {
                  _initializeFields(profileState);
                  _isEditing = true;
                });
              },
            ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: profileState.isLoading && profileState.profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // Error display if failed to load
                      if (profileState.errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            profileState.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),

                      // Profile Card Container
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _isEditing ? _buildEditForm(theme, profileState) : _buildProfileView(theme, profileState),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Achievements Grid Section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Achievements & Badges',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildBadgeCard(Icons.landscape_rounded, 'Mountain Explorer', 'Visited 5 Alpine peaks', Colors.orange),
                          _buildBadgeCard(Icons.museum_outlined, 'Culture Guide', 'Explored 10 local shrines', Colors.purple),
                          _buildBadgeCard(Icons.beach_access_rounded, 'Beach Wanderer', 'Sunbathed at 3 coastlines', Colors.cyan),
                          _buildBadgeCard(Icons.flight_takeoff_rounded, 'Globe Trotter', 'Travelled across continents', Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar(ThemeData theme, {bool isEditingMode = false}) {
    ImageProvider? imageProvider;
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      try {
        if (_photoUrl!.startsWith('data:')) {
          final base64Data = _photoUrl!.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64Data));
        } else {
          imageProvider = NetworkImage(_photoUrl!);
        }
      } catch (_) {}
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 54,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Icon(Icons.person_rounded, size: 58, color: theme.colorScheme.primary)
              : null,
        ),
        if (isEditingMode)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileView(ThemeData theme, ProfileState profileState) {
    final profile = profileState.profile;
    if (profile == null) return const Text('No profile details found.');

    final memberSince = profile.createdAt != null
        ? ApiTime.formatMonthYear(profile.createdAt!)
        : 'Unknown';

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(theme, isEditingMode: false),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName.isNotEmpty ? profile.displayName : profile.username,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '@${profile.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile.email,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _buildDetailRow(Icons.description_outlined, 'Bio', profile.bio ?? 'No bio written yet.'),
        _buildDetailRow(Icons.public_rounded, 'Home country', countryName(ref, profile.homeCountryId) ?? 'Not specified'),
        _buildDetailRow(Icons.cake_outlined, 'Birthday', profile.birthday ?? 'Not specified'),
        _buildDetailRow(Icons.calendar_today_rounded, 'Age', profile.age?.toString() ?? 'Not specified'),
        _buildDetailRow(Icons.card_membership_rounded, 'Member Since', memberSince),
      ],
    );
  }

  Widget _buildEditForm(ThemeData theme, ProfileState profileState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Profile Details',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: profileState.isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: profileState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: _buildAvatar(theme, isEditingMode: true),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: 'Display Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Display name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Bio',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          CountryPicker(
            selectedId: _homeCountryId,
            onSelected: (country) => setState(() => _homeCountryId = country.id),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (int.tryParse(value) == null) {
                        return 'Must be valid age';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _birthdayController,
                  decoration: InputDecoration(
                    labelText: 'Birthday',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(IconData icon, String title, String desc, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 26,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
