import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/explore_repository.dart';
import '../../domain/wishlist_item_model.dart';

/// The server's `{message}` for a failed call, else [fallback].
String exploreError(Object error, String fallback) {
  if (error is DioException) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) return data['message'] as String;
    if (error.response == null) return 'Could not reach the server. Please try again.';
  }
  return fallback;
}

/// Heart toggle for a place: filled when the place is on the wishlist. Adds with
/// `POST /explore/wishlist`, removes with `DELETE /explore/wishlist/{itemId}`.
class WishlistButton extends ConsumerStatefulWidget {
  final int placeId;

  const WishlistButton({super.key, required this.placeId});

  @override
  ConsumerState<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends ConsumerState<WishlistButton> {
  bool _busy = false;

  Future<void> _toggle(WishlistItemModel? existing) async {
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ExploreRepository repo = ref.read(exploreRepositoryProvider);
    try {
      if (existing == null) {
        await repo.addToWishlist(widget.placeId);
      } else {
        await repo.removeFromWishlist(existing.id);
      }
      ref.invalidate(wishlistProvider);
      await ref.read(wishlistProvider.future);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(exploreError(e, 'Could not update your wishlist.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<WishlistItemModel>> wishlist = ref.watch(wishlistProvider);
    final List<WishlistItemModel> items = wishlist.value ?? const <WishlistItemModel>[];
    WishlistItemModel? existing;
    for (final WishlistItemModel i in items) {
      if (i.place.id == widget.placeId) existing = i;
    }
    final bool saved = existing != null;
    return IconButton(
      tooltip: saved ? 'Remove from wishlist' : 'Add to wishlist',
      icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? Colors.redAccent : null),
      // Until the wishlist is known, a tap could add a duplicate (409), so wait for it.
      onPressed: _busy || !wishlist.hasValue ? null : () => _toggle(existing),
    );
  }
}
