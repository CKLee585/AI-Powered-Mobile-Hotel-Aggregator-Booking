import 'package:flutter/material.dart';

import '../../../app/app.dart';
import '../../../core/theme/app_theme.dart';
import '../../hotel/presentation/hotel_overview_page.dart';
import '../../search/domain/hotel_candidate.dart';

class CandidatePageArguments {
  const CandidatePageArguments({
    required this.source,
    required this.candidates,
    required this.inputDescription,
  });

  factory CandidatePageArguments.text({
    required String query,
    required List<HotelCandidate> candidates,
  }) {
    return CandidatePageArguments(
      source: CandidateSource.text,
      candidates: candidates,
      inputDescription: 'Search: "$query"',
    );
  }

  factory CandidatePageArguments.image({
    required CandidateSource source,
    required List<HotelCandidate> candidates,
  }) {
    return CandidatePageArguments(
      source: source,
      candidates: candidates,
      inputDescription: 'Ranked from the selected ${source.label}',
    );
  }

  final CandidateSource source;
  final List<HotelCandidate> candidates;
  final String inputDescription;
}

class CandidateConfirmationPage extends StatelessWidget {
  const CandidateConfirmationPage({super.key, required this.arguments});

  final CandidatePageArguments arguments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm hotel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Top 3 ranked candidates',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              arguments.inputDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Confirm the intended hotel before provider and review data are loaded.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            for (var index = 0;
                index < arguments.candidates.length;
                index++) ...[
              _CandidateCard(
                rank: index + 1,
                candidate: arguments.candidates[index],
                onConfirm: () => Navigator.of(context).pushNamed(
                  AppRoutes.hotelOverview,
                  arguments: HotelOverviewArguments(
                    hotel: arguments.candidates[index],
                    source: arguments.source,
                  ),
                ),
              ),
              if (index < arguments.candidates.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.rank,
    required this.candidate,
    required this.onConfirm,
  });

  final int rank;
  final HotelCandidate candidate;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final percentage = (candidate.matchConfidence * 100).round();
    final confidenceColor = percentage >= 85
        ? AppTheme.green
        : percentage >= 70
            ? const Color(0xFF9A6700)
            : const Color(0xFF627D98);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    size: 34,
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$rank. ${candidate.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        candidate.address,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 18,
                            color: Color(0xFFE09F1F),
                          ),
                          const SizedBox(width: 4),
                          Text(candidate.rating.toStringAsFixed(1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percentage% match',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm hotel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
