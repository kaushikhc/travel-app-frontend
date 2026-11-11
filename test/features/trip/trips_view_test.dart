import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/auth/domain/user_model.dart';
import 'package:travel_app_frontend/features/auth/presentation/auth_state.dart';
import 'package:travel_app_frontend/features/profile/presentation/profile_state.dart';
import 'package:travel_app_frontend/features/trip/data/trip_repository.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';
import 'package:travel_app_frontend/features/trip/presentation/trips_view.dart';

class SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState.authenticated(UserModel(username: 'ana'));
}

class IdleProfile extends ProfileNotifier {
  @override
  ProfileState build() => ProfileState.idle();
}

Widget _app(HomeOverview home) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith(SignedIn.new),
        profileNotifierProvider.overrideWith(IdleProfile.new),
        homeOverviewProvider.overrideWith((Ref ref) async => home),
        travelStatsProvider.overrideWith(
            (Ref ref) async => const TravelStats(countriesVisited: 3, tripsCompleted: 1234, memories: 9)),
      ],
      child: const MaterialApp(home: Scaffold(body: TripsView())),
    );

void main() {
  testWidgets('shows the current trip, upcoming trips and stats from the API', (WidgetTester tester) async {
    final DateTime today = DateTime.now();
    final DateTime start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 2));
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    final HomeOverview home = HomeOverview(
      current: TripModel.fromJson(<String, dynamic>{
        'id': 1, 'name': 'Kerala', 'status': 'ACTIVE',
        'startDate': d(start), 'endDate': d(start.add(const Duration(days: 9))),
      }),
      upcoming: <TripModel>[const TripModel(id: 2, name: 'Ladakh', status: TripStatus.upcoming)],
      drafts: <TripModel>[const TripModel(id: 3, name: 'Goa', status: TripStatus.draft)],
    );
    await tester.pumpWidget(_app(home));
    await tester.pumpAndSettle();

    expect(find.text('Kerala'), findsOneWidget);
    expect(find.text('Day 3 of 10'), findsOneWidget);
    expect(find.text('Ladakh'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('Japan'), findsNothing);
  });

  testWidgets('shows empty states without trips', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const HomeOverview()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No trip in progress'), findsOneWidget);
    expect(find.text('No upcoming trips yet.'), findsOneWidget);
  });
}
