import '../../features/auth/presentation/choose_username_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_view.dart';
import '../../features/navigation/presentation/main_scaffold.dart';
import '../../features/journey/presentation/journey_view.dart';
import '../../features/journey/presentation/trip_memory_view.dart';
import '../../features/community/data/community_repository.dart';
import '../../features/community/presentation/connections_view.dart';
import '../../features/community/presentation/traveler_view.dart';
import '../../features/collections/presentation/collections_view.dart';
import '../../features/trip/presentation/trips_view.dart';
import '../../features/trip/presentation/trip_detail_view.dart';
import '../../features/trip/presentation/trip_itinerary_view.dart';
import '../../features/trip/presentation/create_trip_view.dart';
import '../../features/trip/data/trip_repository.dart';
import '../../features/trip/domain/trip_detail_model.dart';
import '../../features/trip/domain/trip_model.dart';
import '../../features/memories/data/memory_repository.dart';
import '../../features/memories/domain/memory_model.dart';
import '../../features/memories/presentation/memories_view.dart';
import '../../features/memories/presentation/memory_detail_view.dart';
import '../../features/memories/presentation/place_memories_view.dart';
import '../../features/memories/presentation/trip_memories_view.dart';
import '../../features/capture/presentation/capture_view.dart';
import '../../features/explore/presentation/explore_view.dart';
import '../../features/explore/presentation/place_detail_view.dart';
import '../../features/notifications/presentation/notifications_view.dart';
import '../../features/profile/presentation/profile_view.dart';
import '../../features/profile/presentation/profile_setup_view.dart';
import '../../features/profile/presentation/profile_state.dart';
import '../../features/auth/presentation/google_callback_view.dart';
import 'auth_redirect.dart';

/// Tells [GoRouter] to re-run [authRedirect] when auth or profile state changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (AuthState? previous, AuthState next) => notifyListeners());
    _ref.listen<ProfileState>(profileNotifierProvider, (ProfileState? previous, ProfileState next) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    return authRedirect(
      auth: _ref.read(authStateProvider),
      profile: _ref.read(profileNotifierProvider),
      uri: state.uri,
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (BuildContext context, GoRouterState state) {
          final String? code = state.uri.queryParameters['code'];
          return code != null && code.isNotEmpty ? GoogleCallbackView(code: code) : const LoginView();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.chooseUsername,
        builder: (context, state) => const ChooseUsernameView(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupView(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TripsView(),
            ),
          ),
          GoRoute(
            path: AppRoutes.newTrip,
            builder: (BuildContext context, GoRouterState state) => const CreateTripView(),
          ),
          GoRoute(
            path: '/trips/:id',
            builder: (BuildContext context, GoRouterState state) =>
                TripDetailView(tripId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
            routes: <RouteBase>[
              GoRoute(
                path: 'itinerary',
                builder: (BuildContext context, GoRouterState state) =>
                    TripItineraryView(tripId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
              ),
              GoRoute(
                path: 'edit',
                builder: (BuildContext context, GoRouterState state) {
                  final Object? extra = state.extra;
                  return extra is TripModel
                      ? CreateTripView(trip: extra)
                      : _LoadedTripEdit(tripId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.followers,
            builder: (BuildContext context, GoRouterState state) => const ConnectionsView(kind: ConnectionKind.followers),
          ),
          GoRoute(
            path: AppRoutes.following,
            builder: (BuildContext context, GoRouterState state) => const ConnectionsView(kind: ConnectionKind.following),
          ),
          GoRoute(
            path: '/travelers/:id',
            builder: (BuildContext context, GoRouterState state) =>
                TravelerView(travelerId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
          ),
          GoRoute(
            path: AppRoutes.memories,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MemoriesView(),
            ),
            routes: <RouteBase>[
              GoRoute(path: 'journey', builder: (BuildContext context, GoRouterState state) => const JourneyView()),
              GoRoute(
                path: 'trip/:tripId',
                builder: (BuildContext context, GoRouterState state) =>
                    TripMemoryView(tripId: int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0),
              ),
              GoRoute(
                path: 'stack/:tripId',
                builder: (BuildContext context, GoRouterState state) =>
                    TripMemoriesView(tripId: int.tryParse(state.pathParameters['tripId'] ?? '')),
              ),
              GoRoute(
                path: 'place/:placeId',
                builder: (BuildContext context, GoRouterState state) => PlaceMemoriesView(
                  placeId: int.tryParse(state.pathParameters['placeId'] ?? '') ?? 0,
                  tripId: int.tryParse(state.uri.queryParameters['tripId'] ?? '') ?? 0,
                  placeName: state.uri.queryParameters['name'] ?? '',
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    MemoryDetailView(
                      memoryId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (BuildContext context, GoRouterState state) {
                      final Object? extra = state.extra;
                      return extra is MemoryModel
                          ? CaptureView(memory: extra)
                          : _LoadedMemoryEdit(
                              memoryId:
                                  int.tryParse(
                                    state.pathParameters['id'] ?? '',
                                  ) ??
                                  0,
                            );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/capture',
            pageBuilder: (context, state) => NoTransitionPage(
              child: CaptureView(
                initialTripId: int.tryParse(state.uri.queryParameters['tripId'] ?? ''),
                initialPlaceId: int.tryParse(state.uri.queryParameters['placeId'] ?? ''),
                initialPlaceName: state.uri.queryParameters['name'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.explore,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExploreView(),
            ),
            routes: <RouteBase>[
              GoRoute(
                path: 'collections',
                builder: (BuildContext context, GoRouterState state) => const CollectionsView(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    builder: (BuildContext context, GoRouterState state) =>
                        CollectionDetailView(collectionId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
                  ),
                ],
              ),
              GoRoute(
                path: 'places/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    PlaceDetailView(placeId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (BuildContext context, GoRouterState state) => const NotificationsView(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileView(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Full-screen loading indicator shown while profile is being fetched.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C6AF7)),
            SizedBox(height: 20),
            Text(
              'Getting your profile…',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback when `/trips/:id/edit` is opened without the trip (e.g. a web reload): loads it first.
class _LoadedTripEdit extends ConsumerWidget {
  final int tripId;

  const _LoadedTripEdit({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripDetail> detail = ref.watch(tripDetailProvider(tripId));
    return detail.when(
      data: (TripDetail d) => CreateTripView(trip: d.trip),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Could not load this trip.')),
      ),
    );
  }
}

/// Fallback when `/memories/:id/edit` is opened without the memory (e.g. a web reload): loads it first.
class _LoadedMemoryEdit extends ConsumerWidget {
  final int memoryId;

  const _LoadedMemoryEdit({required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MemoryModel> memory = ref.watch(
      memoryDetailProvider(memoryId),
    );
    return memory.when(
      data: (MemoryModel m) => CaptureView(memory: m),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Could not load this memory.')),
      ),
    );
  }
}
