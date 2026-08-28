import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_section_screen.dart';

class PaymentsPlaceholderScreen extends StatelessWidget {
  const PaymentsPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderSectionScreen(
    title: 'Pagos',
    description:
        'La gestión de métodos de pago se incorporará en una próxima etapa.',
    icon: Icons.account_balance_wallet_outlined,
  );
}
