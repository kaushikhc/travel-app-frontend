import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/auth_redirect.dart';
import '../../auth/presentation/auth_state.dart';
import '../../profile/presentation/profile_state.dart';
import '../../../core/time/api_time.dart';
import '../data/trip_repository.dart';
import '../../media/data/media_repository.dart';
import '../domain/trip_model.dart';

class TripsView extends ConsumerWidget {
  const TripsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileNotifierProvider);
    final user = authState.user;
    final profile = profileState.profile;
    final AsyncValue<HomeOverview> homeAsync = ref.watch(homeOverviewProvider);
    final AsyncValue<TravelStats> statsAsync = ref.watch(travelStatsProvider);
    final DateTime today = DateTime.now();

    // No photo: show an icon instead of a stock stranger's face.
    ImageProvider? avatarImage;
    final String? photoUrl = profile?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:')) {
        try {
          avatarImage = MemoryImage(base64Decode(photoUrl.split(',').last));
        } catch (_) {
          avatarImage = null;
        }
      } else {
        avatarImage = NetworkImage(photoUrl);
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newTrip),
        icon: const Icon(Icons.add),
        label: const Text('New trip'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Extra bottom room so the floating "New trip" button never hides the stats card.
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(today),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.displayName.isNotEmpty == true 
                                ? profile!.displayName 
                                : (user?.username ?? 'Traveler'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Notification Bell Button
                          IconButton(
                            key: const Key('home-notifications'),
                            tooltip: 'Notifications',
                            onPressed: () => context.push(AppRoutes.notifications),
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            ),
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // User Profile Avatar: opens the Profile tab.
                          Tooltip(
                            message: 'Profile',
                            child: InkWell(
                              key: const Key('home-profile'),
                              customBorder: const CircleBorder(),
                              onTap: () => context.go(AppRoutes.profile),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                backgroundImage: avatarImage,
                                child: avatarImage == null ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 2. CURRENT TRIP Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CURRENT TRIP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  homeAsync.when(
                    loading: () => const _Placeholder(height: 280),
                    error: (Object e, StackTrace _) => _Placeholder(
                      height: 120,
                      text: 'Could not load your trips. Tap to retry.',
                      onTap: () => ref.invalidate(homeOverviewProvider),
                    ),
                    data: (HomeOverview home) => home.current == null
                        ? const _Placeholder(height: 120, text: 'No trip in progress. Your next trip shows here once it starts.')
                        : Consumer(
                            builder: (BuildContext context, WidgetRef ref, Widget? _) => GestureDetector(
                              onTap: () => context.push('/trips/${home.current!.id}'),
                              child: _buildCurrentTripCard(theme, home.current!, today, _coverUrl(ref, home.current!)),
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),

                  // 3. UPCOMING Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'UPCOMING',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horizontal List of Upcoming Trips
                  SizedBox(
                    height: 200,
                    child: homeAsync.when(
                      loading: () => const _Placeholder(height: 200),
                      error: (Object e, StackTrace _) => const SizedBox.shrink(),
                      data: (HomeOverview home) {
                        final List<TripModel> trips = <TripModel>[...home.upcoming, ...home.drafts];
                        if (trips.isEmpty) {
                          return const _Placeholder(height: 200, text: 'No upcoming trips yet. Tap "New trip" to plan one.');
                        }
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: trips.length,
                          separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 16),
                          itemBuilder: (BuildContext context, int i) {
                            final TripModel trip = trips[i];
                            return Consumer(
                              builder: (BuildContext context, WidgetRef ref, Widget? _) => GestureDetector(
                                onTap: () => context.push('/trips/${trip.id}'),
                                child: _buildUpcomingCard(
                                  context,
                                  trip.name,
                                  trip.startDate == null ? 'No dates yet' : ApiTime.formatMonthYear(trip.startDate!),
                                  _upcomingBadge(trip, today),
                                  _coverUrl(ref, trip),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 4. LIFETIME TRAVEL Section
                  Text(
                    'LIFETIME TRAVEL',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Statistics Panel Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(count: _count(statsAsync, (TravelStats t) => t.countriesVisited), label: 'Countries'),
                          const _VerticalSeparator(),
                          _StatColumn(count: _count(statsAsync, (TravelStats t) => t.tripsCompleted), label: 'Trips'),
                          const _VerticalSeparator(),
                          _StatColumn(count: _count(statsAsync, (TravelStats t) => t.memories), label: 'Memories'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTripCard(ThemeData theme, TripModel trip, DateTime today, String? coverUrl) {
    final int? day = trip.dayOfTrip(today);
    final int? total = trip.totalDays;
    final String badge = total == null ? 'Active' : '$total days';
    final double progress = (day != null && total != null && total > 0) ? day / total : 0;
    final String progressLabel = (day != null && total != null) ? 'Day $day of $total' : 'In progress';
    final String subtitle = trip.description?.isNotEmpty == true
        ? trip.description!
        : trip.tags.join(' · ');
    return Container(
                    width: double.infinity,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: theme.colorScheme.primary,
                      image: _cover(coverUrl),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Row (Badge/Days Left)
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flight_takeoff, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    badge,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom Content Area
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Region text
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Title with Serif/Italic feel
                              Text(
                                trip.name,
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Dates
                              Text(
                                _dateRange(trip),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Progress bar row
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 4,
                                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    progressLabel,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Action Pills
                              Row(
                                children: [
                                  _buildActionPill(Icons.flight_outlined, 'Flights'),
                                  const SizedBox(width: 8),
                                  _buildActionPill(Icons.hotel_outlined, 'Hotels'),
                                  const SizedBox(width: 8),
                                  _buildActionPill(Icons.camera_alt_outlined, 'Memories'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
  }

  /// The trip's cover link once loaded; null while loading, on error or without a cover.
  static String? _coverUrl(WidgetRef ref, TripModel trip) {
    final int? id = trip.coverMediaId;
    return id == null ? null : ref.watch(mediaUrlProvider(id)).value;
  }

  /// Cover as a background behind the card's dark gradient; the plain colour shows until then.
  static DecorationImage? _cover(String? url) => url == null
      ? null
      : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover, onError: (Object _, StackTrace? _) {});

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _dateRange(TripModel trip) {
    if (trip.startDate == null) return 'No dates yet';
    final String start = DateFormat.MMMd().format(trip.startDate!);
    if (trip.endDate == null) return start;
    return '$start – ${DateFormat.yMMMd().format(trip.endDate!)}';
  }

  static String _upcomingBadge(TripModel trip, DateTime today) {
    if (trip.status == TripStatus.draft) return 'Draft';
    final int? days = trip.daysUntilStart(today);
    if (days == null) return 'Soon';
    return days <= 0 ? 'Today' : '${days}d';
  }

  static String _count(AsyncValue<TravelStats> stats, int Function(TravelStats) pick) {
    final TravelStats? value = stats.value;
    return value == null ? '–' : NumberFormat.decimalPattern().format(pick(value));
  }

  Widget _buildActionPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(
    BuildContext context,
    String country,
    String date,
    String daysLeft,
    String? coverUrl,
  ) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.secondary,
        image: _cover(coverUrl),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.05),
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Days Left Badge
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  daysLeft,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String count;
  final String label;

  const _StatColumn({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VerticalSeparator extends StatelessWidget {
  const _VerticalSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Colors.grey[300],
    );
  }
}

/// A card-sized box for loading, empty and error states.
class _Placeholder extends StatelessWidget {
  final double height;
  final String? text;
  final VoidCallback? onTap;

  const _Placeholder({required this.height, this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        child: text == null
            ? const CircularProgressIndicator()
            : Text(text!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
      ),
    );
  }
}
