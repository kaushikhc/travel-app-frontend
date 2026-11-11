import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/place_model.dart';

final placesProvider = Provider<List<PlaceModel>>((ref) {
  return const [
    PlaceModel(
      id: 'p1',
      name: 'Fushimi Inari Shrine',
      country: 'Japan',
      category: 'Culture',
      rating: 4.9,
      imageUrl: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=800&q=80',
      description: 'Iconic Shinto shrine known for its thousands of vermilion torii gates winding up Mt. Inari.',
    ),
    PlaceModel(
      id: 'p2',
      name: 'Matterhorn Peak',
      country: 'Switzerland',
      category: 'Mountain',
      rating: 4.95,
      imageUrl: 'https://images.unsplash.com/photo-1530122037265-a5f1f91d3b99?auto=format&fit=crop&w=800&q=80',
      description: 'One of the highest peaks in the Alps and Europe, offering breathtaking alpine landscapes.',
    ),
    PlaceModel(
      id: 'p3',
      name: 'Santorini Sunset Viewpoint',
      country: 'Greece',
      category: 'Beach',
      rating: 4.85,
      imageUrl: 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?auto=format&fit=crop&w=800&q=80',
      description: 'Famous whitewashed buildings overlooking the Aegean Sea with world-renowned sunsets.',
    ),
    PlaceModel(
      id: 'p4',
      name: 'Machu Picchu Ancient Citadel',
      country: 'Peru',
      category: 'History',
      rating: 4.98,
      imageUrl: 'https://images.unsplash.com/photo-1526392060635-9d6019884377?auto=format&fit=crop&w=800&q=80',
      description: '15th-century Inca citadel located in the Eastern Cordillera of southern Peru on a mountain ridge.',
    ),
  ];
});

class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  String _selectedCategory = 'ALL';

  @override
  Widget build(BuildContext context) {
    final places = ref.watch(placesProvider);
    final theme = Theme.of(context);

    final filtered = _selectedCategory == 'ALL'
        ? places
        : places.where((p) => p.category.toUpperCase() == _selectedCategory.toUpperCase()).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore Destinations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Discover New Wonders',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Find places, save memories, and plan your next adventure.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Category Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('ALL', 'All'),
                    _buildCategoryChip('Culture', 'Culture'),
                    _buildCategoryChip('Mountain', 'Mountains'),
                    _buildCategoryChip('Beach', 'Beaches'),
                    _buildCategoryChip('History', 'History'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Places Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 800 ? 2 : 1,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final place = filtered[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            place.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade800),
                          ),
                        ),
                        // Dark Gradient Overlay for readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Top Rating Badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  place.rating.toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bottom Content
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                place.country,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                place.description,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => setState(() => _selectedCategory = value),
      ),
    );
  }
}
