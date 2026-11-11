import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media/data/media_repository.dart';
import '../../domain/memory_model.dart';

/// One memory photo: the signed link from the memory response, else a fresh link from
/// [mediaUrlProvider]. Shows a placeholder while loading, on errors and for videos.
class MemoryPhoto extends ConsumerWidget {
  final MemoryMedia? media;
  final BoxFit fit;

  const MemoryPhoto({super.key, required this.media, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget placeholder = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Icon((media?.isVideo ?? false) ? Icons.videocam_outlined : Icons.photo_outlined,
            color: colors.onPrimaryContainer),
      ),
    );
    final MemoryMedia? m = media;
    if (m == null || m.isVideo) return placeholder;
    final String? url = (m.url != null && m.url!.isNotEmpty) ? m.url : ref.watch(mediaUrlProvider(m.id)).value;
    if (url == null) return placeholder;
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (BuildContext c, Object e, StackTrace? s) => placeholder,
    );
  }
}
