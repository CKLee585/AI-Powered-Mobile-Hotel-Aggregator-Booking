import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../search/domain/hotel_candidate.dart';

class HotelOverviewArguments {
  const HotelOverviewArguments({required this.hotel, required this.source});

  final HotelCandidate hotel;
  final CandidateSource source;
}

class HotelOverviewPage extends StatelessWidget {
  const HotelOverviewPage({super.key, required this.arguments});

  final HotelOverviewArguments arguments;

  @override
  Widget build(BuildContext context) {
    final hotel = arguments.hotel;

    return Scaffold(
      appBar: AppBar(title: const Text('Hotel overview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_city,
                size: 72,
                color: AppTheme.blue,
              ),
            ),
            const SizedBox(height: 20),
            Text(hotel.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(hotel.address, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFE09F1F)),
                const SizedBox(width: 6),
                Text(
                  hotel.rating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Confirmed from ${arguments.source.label}')),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week 1-3 foundation complete',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This confirmed hotel will feed the provider-comparison '
                      'and AI review modules in the next development stage.',
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
