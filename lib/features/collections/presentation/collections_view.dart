import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/router/auth_redirect.dart';
import '../../trip/presentation/widgets/place_picker.dart';
import '../../explore/domain/place_model.dart';
import '../data/collection_repository.dart';
import '../domain/collection_models.dart';

/// Name and optional description of a personal collection. Returns true when saved.
Future<bool> showCollectionDialog(BuildContext context, WidgetRef ref, {CollectionSummary? existing}) async {
  final TextEditingController name = TextEditingController(text: existing?.name ?? '');
  final TextEditingController description = TextEditingController(text: existing?.description ?? '');
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext c) => StatefulBuilder(
      builder: (BuildContext c, void Function(void Function()) set) => AlertDialog(
        title: Text(existing == null ? 'New collection' : 'Edit collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: name, autofocus: true, maxLength: 100, decoration: const InputDecoration(labelText: 'Name'), onChanged: (String _) => set(() {})),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 3, minLines: 1),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    ),
  );
  final String n = name.text;
  final String d = description.text;
  name.dispose();
  description.dispose();
  if (ok != true || !context.mounted) return false;
  try {
    final CollectionRepository repo = ref.read(collectionRepositoryProvider);
    if (existing == null) {
      await repo.create(name: n, description: d);
    } else {
      await repo.update(existing.id, name: n, description: d);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not save the collection. Please try again.'))));
    }
    return false;
  }
}

/// The shared (global) collections and the traveler's own, each with progress.
class CollectionsView extends ConsumerWidget {
  const CollectionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CollectionSummary>> list = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New collection'),
        onPressed: () async {
          if (await showCollectionDialog(context, ref)) ref.invalidate(collectionsProvider);
        },
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load collections.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(collectionsProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (List<CollectionSummary> items) => items.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No collections yet. Create one to track places you want to see.', textAlign: TextAlign.center)))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(collectionsProvider);
                  await ref.read(collectionsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: <Widget>[
                    for (final CollectionSummary c in items)
                      Card(
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (c.description?.isNotEmpty == true) Text(c.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: c.total == 0 ? 0 : c.visited / c.total),
                              const SizedBox(height: 4),
                              Text('${c.visited} of ${c.total} visited${c.global ? ' · shared' : ''}'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(AppRoutes.collection(c.id)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// One collection: its places with visited marks. Personal collections can be edited, added to and deleted.
class CollectionDetailView extends ConsumerWidget {
  final int collectionId;

  const CollectionDetailView({super.key, required this.collectionId});

  void _refresh(WidgetRef ref) {
    ref.invalidate(collectionDetailProvider(collectionId));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String failure) async {
    try {
      await action();
      _refresh(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, failure))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CollectionDetail> detail = ref.watch(collectionDetailProvider(collectionId));
    final CollectionDetail? d = detail.value;
    final bool own = d != null && !d.collection.global;
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.collection.name ?? 'Collection'),
        actions: <Widget>[
          if (own) ...<Widget>[
            IconButton(
              tooltip: 'Edit collection',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                if (await showCollectionDialog(context, ref, existing: d.collection)) _refresh(ref);
              },
            ),
            IconButton(
              tooltip: 'Delete collection',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext c) => AlertDialog(
                    title: const Text('Delete this collection?'),
                    content: const Text('The places themselves are not deleted.'),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                try {
                  await ref.read(collectionRepositoryProvider).delete(collectionId);
                  ref.invalidate(collectionsProvider);
                  if (context.mounted) context.pop();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not delete. Please try again.'))));
                }
              },
            ),
          ],
        ],
      ),
      floatingActionButton: own
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add place'),
              onPressed: () async {
                final PlaceModel? p = await pickPlace(context);
                if (p == null || !context.mounted) return;
                await _run(context, ref, () => ref.read(collectionRepositoryProvider).addPlace(collectionId, p.id), 'Could not add the place. Please try again.');
              },
            )
          : null,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load this collection.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(collectionDetailProvider(collectionId)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (CollectionDetail data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: <Widget>[
            if (data.collection.description?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(data.collection.description!)),
            LinearProgressIndicator(value: data.collection.total == 0 ? 0 : data.collection.visited / data.collection.total),
            const SizedBox(height: 4),
            Text('${data.collection.visited} of ${data.collection.total} visited'),
            const SizedBox(height: 8),
            if (data.items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No places in this collection yet.')),
            for (final CollectionItem i in data.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(i.visited ? Icons.check_circle : Icons.radio_button_unchecked, color: i.visited ? Colors.green : null),
                title: Text(i.name),
                subtitle: i.type == null ? null : Text(i.type!),
                onTap: i.placeId == 0 ? null : () => context.push(AppRoutes.placeDetail(i.placeId)),
                trailing: own
                    ? IconButton(
                        tooltip: 'Remove from collection',
                        icon: const Icon(Icons.close),
                        onPressed: () => _run(context, ref, () => ref.read(collectionRepositoryProvider).removePlace(collectionId, i.placeId), 'Could not remove the place. Please try again.'),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
