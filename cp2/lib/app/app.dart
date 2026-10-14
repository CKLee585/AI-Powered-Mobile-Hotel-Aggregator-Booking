import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/camera/presentation/camera_search_page.dart';
import '../features/candidates/presentation/candidate_confirmation_page.dart';
import '../features/hotel/presentation/hotel_overview_page.dart';
import '../features/search/data/mock_hotel_repository.dart';
import '../features/search/data/remote_hotel_repository.dart';
import '../features/search/domain/hotel_repository.dart';
import '../features/search/presentation/discovery_page.dart';

abstract final class AppRoutes {
  static const discovery = '/';
  static const cameraSearch = '/camera-search';
  static const candidates = '/candidates';
  static const hotelOverview = '/hotel-overview';
}

class HereWeGoApp extends StatelessWidget {
  const HereWeGoApp({super.key, this.repository});

  final HotelRepository? repository;

  @override
  Widget build(BuildContext context) {
    final hotelRepository = repository ??
        (AppConfig.usesRemoteApi
            ? RemoteHotelRepository(baseUrl: AppConfig.apiBaseUrl)
            : MockHotelRepository());

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'herewego',
      theme: AppTheme.light(),
      initialRoute: AppRoutes.discovery,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.discovery:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => DiscoveryPage(repository: hotelRepository),
            );
          case AppRoutes.cameraSearch:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CameraSearchPage(repository: hotelRepository),
            );
          case AppRoutes.candidates:
            final arguments = settings.arguments;
            if (arguments is! CandidatePageArguments) {
              return _invalidRoute(settings, 'Candidate data is unavailable.');
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CandidateConfirmationPage(arguments: arguments),
            );
          case AppRoutes.hotelOverview:
            final arguments = settings.arguments;
            if (arguments is! HotelOverviewArguments) {
              return _invalidRoute(settings, 'Hotel data is unavailable.');
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => HotelOverviewPage(arguments: arguments),
            );
          default:
            return _invalidRoute(settings, 'This screen is not available.');
        }
      },
    );
  }

  MaterialPageRoute<void> _invalidRoute(
      RouteSettings settings, String message) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('herewego')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
