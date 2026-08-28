import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_section_screen.dart';

class AccountPlaceholderScreen extends StatelessWidget {
  const AccountPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderSectionScreen(
    title: 'Cuenta',
    description:
        'Tu perfil y preferencias se configurarán en una próxima etapa.',
    icon: Icons.person_outline,
  );
}
