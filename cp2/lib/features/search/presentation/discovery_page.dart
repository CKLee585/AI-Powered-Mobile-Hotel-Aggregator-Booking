import 'package:flutter/material.dart';

import '../../../app/app.dart';
import '../../../core/theme/app_theme.dart';
import '../../candidates/presentation/candidate_confirmation_page.dart';
import '../domain/hotel_repository.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key, required this.repository});

  final HotelRepository repository;

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  static const _filters = <String>[
    'Clean rooms',
    'Quiet rooms',
    'Family-friendly',
    'Non-smoking',
    'Budget-friendly',
  ];

  final _searchController = TextEditingController();
  final _selectedFilters = <String>{};
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a hotel name, destination, or keyword.'),
        ),
      );
      return;
    }

    setState(() => _isSearching = true);
    try {
      final candidates = await widget.repository.searchHotels(
        query,
        requiredTags: _selectedFilters,
      );
      if (!mounted) return;
      setState(() => _isSearching = false);

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hotels match all selected filters. Remove one filter and try again.',
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).pushNamed(
        AppRoutes.candidates,
        arguments: CandidatePageArguments.text(
          query: query,
          candidates: candidates,
        ),
      );
    } on HotelRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The hotel search could not be completed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'herewego',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Saved hotels',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved hotels are planned next.')),
            ),
            icon: const Icon(Icons.bookmark_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Find the right hotel with clearer evidence.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Search by name or destination, or use a hotel signboard, '
              'building, or landmark image.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('hotelSearchField'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Hotel name, destination, or keyword',
                hintText: 'Example: Sunway Resort Hotel',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Open camera-assisted search',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.cameraSearch,
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('searchHotelsButton'),
              onPressed: _isSearching ? null : _search,
              icon: _isSearching
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.manage_search),
              label: Text(_isSearching ? 'Searching...' : 'Search hotels'),
            ),
            const SizedBox(height: 28),
            Text(
              'Stay-quality filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Select the practical needs that matter for this stay.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filters.map((filter) {
                final selected = _selectedFilters.contains(filter);
                return FilterChip(
                  label: Text(filter),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedFilters.add(filter);
                      } else {
                        _selectedFilters.remove(filter);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decision support only',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'herewego compares information and review evidence. '
                            'Booking and payment remain on the provider platform.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
