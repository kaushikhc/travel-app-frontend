import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/auth_redirect.dart';
import '../../../../core/time/api_time.dart';
import '../../domain/memory_model.dart';
import 'memory_photo.dart';

/// One memory as a grid card: photo (or note), title and date. Opens the memory.
class MemoryGridCard extends StatelessWidget {
  final MemoryModel memory;

  const MemoryGridCard({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? date = memory.date;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.memoryDetail(memory.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: memory.cover == null
                  ? ColoredBox(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(memory.note ?? '', maxLines: 6, overflow: TextOverflow.ellipsis),
                      ),
                    )
                  : MemoryPhoto(media: memory.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(memory.displayTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  if (date != null)
                    Text(ApiTime.formatDate(date),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
