import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_state.dart';

/// Full-screen onboarding wizard shown when mandatory profile fields are empty.
/// The user cannot navigate past this screen until all required fields are saved.
class ProfileSetupView extends ConsumerStatefulWidget {
  const ProfileSetupView({super.key});

  @override
  ConsumerState<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends ConsumerState<ProfileSetupView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Step tracking
  int _step = 0;
  static const int _totalSteps = 3;

  // Form fields
  late TextEditingController _displayNameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _birthdayCtrl;
  String? _photoUrl;
  bool _isSaving = false;

  // Country list (subset for MVP)
  static const List<Map<String, dynamic>> _countries = [
    {'id': 1, 'name': 'India', 'flag': '🇮🇳'},
    {'id': 2, 'name': 'United States', 'flag': '🇺🇸'},
    {'id': 3, 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'id': 4, 'name': 'Germany', 'flag': '🇩🇪'},
    {'id': 5, 'name': 'France', 'flag': '🇫🇷'},
    {'id': 6, 'name': 'Japan', 'flag': '🇯🇵'},
    {'id': 7, 'name': 'Australia', 'flag': '🇦🇺'},
    {'id': 8, 'name': 'Canada', 'flag': '🇨🇦'},
    {'id': 9, 'name': 'Brazil', 'flag': '🇧🇷'},
    {'id': 10, 'name': 'Italy', 'flag': '🇮🇹'},
    {'id': 11, 'name': 'Spain', 'flag': '🇪🇸'},
    {'id': 12, 'name': 'South Korea', 'flag': '🇰🇷'},
    {'id': 13, 'name': 'Mexico', 'flag': '🇲🇽'},
    {'id': 14, 'name': 'Netherlands', 'flag': '🇳🇱'},
    {'id': 15, 'name': 'Singapore', 'flag': '🇸🇬'},
  ];

  Map<String, dynamic>? _selectedCountry;

  static const Color _primary = Color(0xFF7C6AF7);
  static const Color _secondary = Color(0xFF3B82F6);
  static const Color _bg = Color(0xFF0D0D1A);

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _birthdayCtrl = TextEditingController();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    // Pre-fill from already-loaded profile if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileNotifierProvider).profile;
      if (profile != null) {
        _displayNameCtrl.text = profile.displayName;
        _bioCtrl.text = profile.bio ?? '';
        _ageCtrl.text = profile.age?.toString() ?? '';
        _birthdayCtrl.text = profile.birthday ?? '';
        _photoUrl = profile.photoUrl;
        if (profile.homeCountryId != null) {
          _selectedCountry = _countries.where((c) => c['id'] == profile.homeCountryId).firstOrNull;
        }
      }
      _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _ageCtrl.dispose();
    _birthdayCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _photoUrl = 'data:image/jpeg;base64,${base64Encode(result.files.single.bytes!)}';
      });
    }
  }

  void _goToStep(int step) {
    _animCtrl.reset();
    setState(() => _step = step);
    _animCtrl.forward();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null) {
      _showError('Please select your home country.');
      return;
    }
    setState(() => _isSaving = true);
    final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
          displayName: _displayNameCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
          homeCountryId: _selectedCountry!['id'] as int,
          photoUrl: _photoUrl,
          age: int.tryParse(_ageCtrl.text),
          birthday: _birthdayCtrl.text.trim().isEmpty ? null : _birthdayCtrl.text.trim(),
        );
    setState(() => _isSaving = false);
    if (!success && mounted) {
      final err = ref.read(profileNotifierProvider).errorMessage ?? 'Failed to save.';
      _showError(err);
    }
    // On success, router redirect logic fires automatically via ProfileState listener.
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -100,
            right: -80,
            child: _buildBlob(_primary, 300),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _buildBlob(_secondary, 260),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStepIndicator(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _buildCurrentStep(),
                      ),
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(30),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _primary.withAlpha(38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withAlpha(76)),
            ),
            child: Text(
              '✈️  Almost there!',
              style: GoogleFonts.inter(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _stepTitle(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _stepSubtitle(),
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDone
                    ? _primary
                    : isActive
                        ? _primary.withAlpha(178)
                        : Colors.white12,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: switch (_step) {
        0 => _buildStep1Identity(),
        1 => _buildStep2Hometown(),
        _ => _buildStep3About(),
      },
    );
  }

  // ─── Step 1: Identity (photo + display name) ──────────────────────────────

  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar picker
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_primary, _secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withAlpha(102),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _photoUrl != null
                      ? ClipOval(
                          child: _photoUrl!.startsWith('data:')
                              ? Image.memory(
                                  base64Decode(_photoUrl!.split(',').last),
                                  fit: BoxFit.cover,
                                )
                              : Image.network(_photoUrl!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 50),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A2E),
                      border: Border.all(color: _primary, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: _primary, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tap to upload photo',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildLabel('Display Name *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _displayNameCtrl,
          hint: 'How should we call you?',
          icon: Icons.badge_outlined,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Display name is required' : null,
        ),
      ],
    );
  }

  // ─── Step 2: Hometown ─────────────────────────────────────────────────────

  Widget _buildStep2Hometown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Home Country *'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _countries.length,
          itemBuilder: (context, i) {
            final country = _countries[i];
            final isSelected = _selectedCountry?['id'] == country['id'];
            return GestureDetector(
              onTap: () => setState(() => _selectedCountry = country),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? _primary.withAlpha(64)
                      : Colors.white.withAlpha(13),
                  border: Border.all(
                    color: isSelected ? _primary : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text(country['flag'] as String, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            country['name'] as String,
                            style: GoogleFonts.inter(
                              color: isSelected ? _primary : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_selectedCountry == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select a country to continue',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ─── Step 3: About ────────────────────────────────────────────────────────

  Widget _buildStep3About() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Bio *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _bioCtrl,
          hint: 'Tell the world who you are…',
          icon: Icons.auto_stories_outlined,
          maxLines: 4,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'A short bio is required' : null,
        ),
        const SizedBox(height: 24),
        _buildLabel('Age (optional)'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _ageCtrl,
          hint: 'Your age',
          icon: Icons.cake_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildLabel('Birthday (optional)'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _birthdayCtrl,
          hint: 'e.g. 14 Jan 1995',
          icon: Icons.celebration_outlined,
        ),
      ],
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 15),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: Colors.white.withAlpha(15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53E3E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _step == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(_step - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [_primary, _secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withAlpha(89),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _handleNext(isLastStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isLastStep ? "Let's Go! 🚀" : 'Continue →',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext(bool isLastStep) {
    if (isLastStep) {
      _save();
    } else if (_step == 0) {
      if (_formKey.currentState!.validate()) _goToStep(_step + 1);
    } else if (_step == 1) {
      if (_selectedCountry == null) {
        _showError('Please select your home country.');
      } else {
        _goToStep(_step + 1);
      }
    } else {
      _goToStep(_step + 1);
    }
  }

  String _stepTitle() => switch (_step) {
        0 => 'Your Identity',
        1 => "Where's Home?",
        _ => 'Tell Your Story',
      };

  String _stepSubtitle() => switch (_step) {
        0 => 'Add a face to your adventures.',
        1 => 'Select the country you call home.',
        _ => 'A short bio that defines the traveler in you.',
      };
}
