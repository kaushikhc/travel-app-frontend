import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/time/api_time.dart';
import '../../media/data/media_repository.dart';
import '../../media/data/photo_metadata.dart';
import '../../memories/data/memory_repository.dart';
import '../../memories/domain/memory_model.dart';
import '../../memories/presentation/widgets/memory_photo.dart';
import '../../explore/data/explore_repository.dart';
import '../../explore/domain/place_model.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/domain/trip_detail_model.dart';
import '../../trip/presentation/widgets/place_picker.dart';
import '../../trip/domain/trip_model.dart';
import '../../trip/presentation/create_trip_view.dart' show parseTags, maxTagsPerTrip, maxTagLength;

/// The server's `{message}` for a failed call, else a generic text.
String captureError(Object error) {
  if (error is DioException) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) return data['message'] as String;
    if (error.response == null) return 'Could not reach the server. Please try again.';
  }
  if (error is FormatException) return error.message;
  return 'Could not save the memory. Please try again.';
}

/// Whether this build can open the camera through `image_picker`: Android only. Web has no
/// camera delegate, and iOS is on hold (it would also need an Info.plist usage text).
bool get cameraPickerSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// A photo picked on the form. It is uploaded when the memory is saved, once: [mediaId]
/// is kept so a retry after a failed save does not upload it again.
class _PickedPhoto {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  /// When the photo was taken, from its EXIF metadata (null if it has none).
  final DateTime? takenAt;
  int? mediaId;

  _PickedPhoto(this.name, this.bytes, this.mimeType) : takenAt = photoCaptureTime(bytes, mimeType);
}

/// The capture form. With [memory] it is the edit form for that saved memory (prefilled, existing
/// photos removable, saved with `PATCH /memories/{id}`); without it, the new-memory form.
class CaptureView extends ConsumerStatefulWidget {
  final MemoryModel? memory;

  const CaptureView({super.key, this.memory});

  @override
  ConsumerState<CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends ConsumerState<CaptureView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final List<_PickedPhoto> _photos = <_PickedPhoto>[];
  late List<MemoryMedia> _existing;
  int? _tripId;
  bool _tripTouched = false;

  /// The place tagged on the memory (must be planned or visited on the trip). When editing it
  /// starts as the memory's place and is sent only if changed.
  int? _placeId;
  String? _placeName;
  bool _placeTouched = false;
  /// True when [_placeId] came from the search and is not yet on the trip; it is planned on save.
  bool _placeNeedsPlanning = false;
  MemoryVisibility _visibility = MemoryVisibility.private;

  /// The time the traveler chose, which memories sort by. Null means automatic: the earliest photo
  /// time, else when it is saved. When editing, it starts as the memory's time and is sent only if changed.
  DateTime? _capturedAt;
  bool _timeTouched = false;
  bool _saving = false;

  bool get _isEdit => widget.memory != null;

  @override
  void initState() {
    super.initState();
    final MemoryModel? m = widget.memory;
    _existing = m == null ? <MemoryMedia>[] : List<MemoryMedia>.of(m.media);
    if (m != null) {
      _title.text = m.title ?? '';
      _note.text = m.note ?? '';
      _tags.text = m.tags.join(', ');
      _visibility = m.visibility;
      _capturedAt = m.capturedAt;
      _tripId = m.tripId;
      _tripTouched = true;
      _placeId = m.placeId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final FilePickerResult? result =
          // compressionQuality 0 = original files; the default re-encodes at quality 30 and loses the rotation.
          await FilePicker.platform.pickFiles(
              type: FileType.image, allowMultiple: true, withData: true, compressionQuality: 0);
      if (result == null) return;
      int skipped = 0;
      final List<_PickedPhoto> added = <_PickedPhoto>[];
      for (final PlatformFile f in result.files) {
        final Uint8List? bytes = f.bytes;
        final String? mime = photoMimeType(f.name);
        if (bytes == null || mime == null) {
          skipped++;
        } else {
          added.add(_PickedPhoto(f.name, bytes, mime));
        }
      }
      if (!mounted) return;
      setState(() => _photos.addAll(added));
      if (skipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Some files were skipped: pick JPEG, PNG, WebP or HEIC photos.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the photo picker.')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (shot == null) return;
      final Uint8List bytes = await shot.readAsBytes();
      final String mime =
          photoMimeType(shot.name) ?? photoMimeType(shot.path) ?? 'image/jpeg';
      if (!mounted) return;
      setState(() => _photos.add(_PickedPhoto(shot.name, bytes, mime)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the camera.')),
        );
      }
    }
  }

  /// The traveler's choice, else their ACTIVE trip (what the backend would use without a tripId).
  int? _effectiveTrip(List<TripModel> trips) {
    if (_tripTouched) return _tripId;
    for (final TripModel t in trips) {
      if (t.status == TripStatus.active) return t.id;
    }
    return null;
  }

  Future<void> _save(List<TripModel> trips) async {
    final bool formOk = _formKey.currentState!.validate();
    if (!formOk || _saving) return;
    setState(() => _saving = true);
    try {
      final MediaRepository media = ref.read(mediaRepositoryProvider);
      for (final _PickedPhoto p in _photos) {
        p.mediaId ??= await media.uploadPhoto(p.bytes, p.mimeType, capturedAt: p.takenAt);
      }
      final List<int> mediaIds = <int>[
        for (final MemoryMedia m in _existing) m.id,
        for (final _PickedPhoto p in _photos) p.mediaId!,
      ];
      final MemoryModel? editing = widget.memory;
      final int? saveTrip = editing?.tripId ?? _effectiveTrip(trips);
      if (_placeNeedsPlanning && _placeId != null && saveTrip != null) {
        try {
          await ref.read(tripRepositoryProvider).addTripPlace(saveTrip, placeId: _placeId!);
        } on DioException catch (e) {
          if (e.response?.statusCode != 409) rethrow; // already planned on the trip
        }
        _placeNeedsPlanning = false;
        ref.invalidate(tripDetailProvider(saveTrip));
      }
      if (editing != null) {
        await ref
            .read(memoryRepositoryProvider)
            .updateMemory(
              editing.id,
              title: _title.text,
              note: _note.text,
              visibility: _visibility,
              tags: parseTags(_tags.text),
              mediaIds: mediaIds,
              capturedAt: _timeTouched ? _capturedAt : null,
              placeChanged: _placeTouched,
              placeId: _placeId,
            );
        ref.invalidate(memoryDetailProvider(editing.id));
        ref.invalidate(memoriesProvider);
        if (!mounted) return;
        context.pop();
        return;
      }
      await ref
          .read(memoryRepositoryProvider)
          .createMemory(
            tripId: _effectiveTrip(trips),
            placeId: _placeId,
            title: _title.text,
            note: _note.text,
            visibility: _visibility,
            capturedAt: _capturedAt,
            tags: parseTags(_tags.text),
            mediaIds: mediaIds,
          );
      ref.invalidate(memoriesProvider);
      ref.invalidate(homeOverviewProvider);
      ref.invalidate(travelStatsProvider);
      if (!mounted) return;
      _title.clear();
      _note.clear();
      _tags.clear();
      setState(() {
        _photos.clear();
        _saving = false;
        _visibility = MemoryVisibility.private;
        _tripTouched = false;
        _tripId = null;
        _clearPlace();
        _capturedAt = null;
        _timeTouched = false;
      });
      context.go(AppRoutes.memories);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(captureError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TripModel>> tripsAsync = ref.watch(tripsProvider);
    final List<TripModel> trips = tripsAsync.value ?? const <TripModel>[];
    final int? tripId = _effectiveTrip(trips);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit memory' : 'New memory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
                    _photoStrip(),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickPhotos,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(
                              _photos.isEmpty && _existing.isEmpty
                                  ? 'Add photos'
                                  : 'Add more photos',
                            ),
                          ),
                        ),
                        if (cameraPickerSupported) ...<Widget>[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _takePhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Take photo'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Title (optional)', border: OutlineInputBorder()),
                      validator: (String? v) {
                        if (_photos.isEmpty &&
                            _existing.isEmpty &&
                            (v ?? '').trim().isEmpty &&
                            _note.text.trim().isEmpty) {
                          return 'Add a title, a note or a photo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    _tripPicker(tripsAsync, trips, tripId),
                    const SizedBox(height: 16),
                    if (tripId != null) ...<Widget>[_placePicker(tripId), const SizedBox(height: 16)],
                    _timePicker(),
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
                    DropdownButtonFormField<MemoryVisibility>(
                      initialValue: _visibility,
                      decoration: const InputDecoration(labelText: 'Visibility', border: OutlineInputBorder()),
                      items: <DropdownMenuItem<MemoryVisibility>>[
                        for (final MemoryVisibility v in MemoryVisibility.values)
                          DropdownMenuItem<MemoryVisibility>(value: v, child: Text(v.label)),
                      ],
                      onChanged: (MemoryVisibility? v) => setState(() => _visibility = v ?? _visibility),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(trips),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEdit ? 'Save' : 'Save memory'),
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

  /// The time memories sort by. Left automatic it is the earliest photo time, else when saved.
  Widget _timePicker() {
    final DateTime? chosen = _capturedAt;
    // A saved memory always has a time, and PATCH cannot clear it, so only a new memory can go back to automatic.
    final bool canClear = chosen != null && !_isEdit;
    return InkWell(
      onTap: _saving ? null : _pickTime,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date and time',
          helperText: _isEdit ? 'Memories are sorted by this.' : 'Memories are sorted by this. Left automatic, the photo date is used.',
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: canClear
              ? IconButton(
                  tooltip: 'Use the photo date',
                  icon: const Icon(Icons.clear),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _capturedAt = null;
                          _timeTouched = true;
                        }),
                )
              : null,
        ),
        child: Text(chosen == null ? 'Automatic' : ApiTime.formatDateTime(chosen)),
      ),
    );
  }

  Future<void> _pickTime() async {
    final DateTime now = DateTime.now();
    final DateTime initial = (_capturedAt ?? now).toLocal();
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1970),
      lastDate: now,
    );
    if (day == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    setState(() {
      _capturedAt = DateTime(day.year, day.month, day.day, time.hour, time.minute).toUtc();
      _timeTouched = true;
    });
  }

  Widget _photoStrip() {
    final int total = _existing.length + _photos.length;
    if (total == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (BuildContext c, int i) => const SizedBox(width: 8),
        itemBuilder: (BuildContext c, int i) {
          final bool saved = i < _existing.length;
          return Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: saved
                      ? MemoryPhoto(media: _existing[i])
                      : Image.memory(
                          _photos[i - _existing.length].bytes,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton.filledTonal(
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove photo',
                  icon: const Icon(Icons.close),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          if (saved) {
                            _existing.removeAt(i);
                          } else {
                            _photos.removeAt(i - _existing.length);
                          }
                        }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tripPicker(AsyncValue<List<TripModel>> async, List<TripModel> trips, int? tripId) {
    if (async.isLoading && trips.isEmpty) return const LinearProgressIndicator();
    if (trips.isEmpty) {
      return Row(
        children: <Widget>[
          const Expanded(child: Text('Memories belong to a trip. Create a trip first.')),
          TextButton(onPressed: () => context.push(AppRoutes.newTrip), child: const Text('New trip')),
        ],
      );
    }
    return DropdownButtonFormField<int>(
      key: ValueKey<int?>(tripId),
      initialValue: tripId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Trip', border: OutlineInputBorder()),
      items: <DropdownMenuItem<int>>[
        for (final TripModel t in trips) DropdownMenuItem<int>(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)),
      ],
      validator: (int? v) => v == null ? 'Pick a trip' : null,
      // PATCH cannot move a memory to another trip, so the trip is shown but locked when editing.
      onChanged: _isEdit
          ? null
          : (int? v) => setState(() {
              _tripTouched = true;
              _tripId = v;
              _clearPlace(); // places belong to a trip
            }),
    );
  }

  void _clearPlace() {
    _placeId = null;
    _placeName = null;
    _placeNeedsPlanning = false;
    _placeTouched = _isEdit;
  }

  static const int _otherPlace = -1;

  /// Tags the memory with a place of the trip's itinerary, or any other place found by search
  /// (which is then added to the trip's itinerary when the memory is saved).
  Widget _placePicker(int tripId) {
    final List<TripPlaceItem> planned = (ref.watch(tripDetailProvider(tripId)).value?.places ?? const <TripPlaceItem>[])
        .where((TripPlaceItem p) => p.placeId != null)
        .toList(growable: false);
    final int? current = _placeId;
    String? currentName = _placeName;
    for (final TripPlaceItem p in planned) {
      if (p.placeId == current) currentName = p.name;
    }
    if (current != null && currentName == null) {
      currentName = ref.watch(placeDetailProvider(current)).value?.name;
    }
    final bool inList = planned.any((TripPlaceItem p) => p.placeId == current);
    return DropdownButtonFormField<int?>(
      key: ValueKey<String>('place-$tripId-$current'),
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Place (optional)',
        helperMaxLines: 3,
        helperText: 'Only this trip\'s places are listed. Skip it for a stop on the way, or search for another place (it is added to the trip).',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.place_outlined),
      ),
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('No specific place (on the way)')),
        for (final TripPlaceItem p in planned)
          DropdownMenuItem<int?>(value: p.placeId, child: Text(p.name, overflow: TextOverflow.ellipsis)),
        if (current != null && !inList)
          DropdownMenuItem<int?>(value: current, child: Text(currentName ?? 'Selected place', overflow: TextOverflow.ellipsis)),
        const DropdownMenuItem<int?>(value: _otherPlace, child: Text('Search for another place…')),
      ],
      onChanged: _saving
          ? null
          : (int? v) async {
              if (v == _otherPlace) {
                final PlaceModel? picked = await pickPlace(context);
                if (picked == null || !mounted) {
                  setState(() {});
                  return;
                }
                setState(() {
                  _placeId = picked.id;
                  _placeName = picked.name;
                  _placeTouched = true;
                  _placeNeedsPlanning = !planned.any((TripPlaceItem p) => p.placeId == picked.id);
                });
                return;
              }
              setState(() {
                _placeId = v;
                _placeName = null;
                _placeTouched = true;
                _placeNeedsPlanning = false;
              });
            },
    );
  }
}
