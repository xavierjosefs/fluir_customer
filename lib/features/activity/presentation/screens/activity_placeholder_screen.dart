import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_section_screen.dart';

class ActivityPlaceholderScreen extends StatelessWidget {
  const ActivityPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderSectionScreen(
    title: 'Actividad',
    description: 'Aquí se organizarán tus viajes y envíos cuando esos flujos estén listos.',
    icon: Icons.receipt_long_outlined,
  );
}
