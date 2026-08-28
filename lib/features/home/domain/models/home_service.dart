enum HomeServiceAvailability { available, comingSoon }

class HomeService {
  const HomeService({
    required this.title,
    required this.subtitle,
    required this.availability,
  });

  final String title;
  final String subtitle;
  final HomeServiceAvailability availability;
}
