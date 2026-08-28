import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_section_screen.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderSectionScreen(
    title: 'Inicio',
    description:
        'El punto de partida de Fluir se preparará en una próxima etapa.',
    icon: Icons.home_outlined,
  );
}
