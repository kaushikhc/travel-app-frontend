import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../profile/presentation/widgets/profile_photo_upload.dart';
import '../data/trip_repository.dart';

/// Same limits as the backend's `Tags` rules.
const int maxTagsPerTrip = 30;
const int maxTagLength = 100;

/// Splits comma-separated input into trimmed tags: blanks dropped, duplicates
/// (case-insensitive) dropped keeping the first spelling.
List<String> parseTags(String input) {
  final Set<String> seen = <String>{};
  final List<String> tags = <String>[];
  for (final String raw in input.split(',')) {
    final String tag = raw.trim();
    if (tag.isNotEmpty && seen.add(tag.toLowerCase())) tags.add(tag);
  }
  return tags;
}

/// The server's `{message}` for a failed call, else a generic text.
String createTripError(Object error) {
  if (error is DioException) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) return data['message'] as String;
    if (error.response == null) return 'Could not reach the server. Please try again.';
  }
  return 'Could not create the trip. Please try again.';
}

class CreateTripView extends ConsumerStatefulWidget {
  const CreateTripView({super.key});

  @override
  ConsumerState<CreateTripView> createState() => _CreateTripViewState();
}

class _CreateTripViewState extends ConsumerState<CreateTripView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  UploadedPhoto? _cover;
  bool _uploading = false;
  bool _saving = false;
  String? _dateError;

  static final DateFormat _fmt = DateFormat.yMMMd();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final DateTime now = DateTime.now();
    final DateTime? initial = start ? _start : (_end ?? _start);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _dateError = _validateDates();
    });
  }

  /// Backend rules: an end date needs a start date, and cannot be before it.
  String? _validateDates() {
    if (_end != null && _start == null) return 'Add a start date for the end date.';
    if (_start != null && _end != null && _end!.isBefore(_start!)) return 'End date is before the start date.';
    return null;
  }

  Future<void> _pickCover() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final UploadedPhoto? photo = await pickAndUploadPhoto(ref);
      if (photo != null && mounted) setState(() => _cover = photo);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(photoUploadError(e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final bool formOk = _formKey.currentState!.validate();
    final String? dateError = _validateDates();
    setState(() => _dateError = dateError);
    if (!formOk || dateError != null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).createTrip(
            name: _name.text,
            description: _description.text,
            startDate: _start,
            endDate: _end,
            coverMediaId: _cover?.mediaId,
            tags: parseTags(_tags.text),
          );
      ref.invalidate(homeOverviewProvider);
      ref.invalidate(travelStatsProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createTripError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Uint8List? coverBytes = _cover?.bytes;
    return Scaffold(
      appBar: AppBar(title: const Text('New trip')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Trip name', border: OutlineInputBorder()),
                      validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Trip name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(child: _dateButton('Start date', _start, () => _pickDate(start: true), () => setState(() { _start = null; _dateError = _validateDates(); }))),
                        const SizedBox(width: 12),
                        Expanded(child: _dateButton('End date', _end, () => _pickDate(start: false), () => setState(() { _end = null; _dateError = _validateDates(); }))),
                      ],
                    ),
                    if (_dateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_dateError!, style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Leave the dates empty to save the trip as a draft.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: 'Tags (optional)',
                        helperText: 'Separate with commas, e.g. food, beach',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? v) {
                        final List<String> tags = parseTags(v ?? '');
                        if (tags.length > maxTagsPerTrip) return 'At most $maxTagsPerTrip tags';
                        if (tags.any((String t) => t.length > maxTagLength)) {
                          return 'A tag is longer than $maxTagLength characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (coverBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.memory(coverBytes, fit: BoxFit.cover),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickCover,
                      icon: _uploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_outlined),
                      label: Text(_cover == null ? 'Add cover photo (optional)' : 'Change cover photo'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: (_saving || _uploading) ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create trip'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton(String label, DateTime? value, VoidCallback onPick, VoidCallback onClear) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text(value == null ? label : _fmt.format(value), overflow: TextOverflow.ellipsis),
      onLongPress: value == null ? null : onClear,
    );
  }
}
