import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';

class OtpInput extends StatelessWidget {
  const OtpInput({
    required this.value,
    required this.onChanged,
    required this.hasError,
    super.key,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Código de verificación de 6 dígitos',
    textField: true,
    child: Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (index) => _OtpCell(
                value: index < value.length ? value[index] : '',
                hasError: hasError,
              ),
            ),
          ),
        ),
        TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: onChanged,
          style: const TextStyle(color: Colors.transparent, fontSize: 1),
          cursorColor: AppColors.navy,
          decoration: const InputDecoration(
            border: InputBorder.none,
            fillColor: Colors.transparent,
            filled: false,
            counterText: '',
          ),
        ),
      ],
    ),
  );
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({required this.value, required this.hasError});
  final String value;
  final bool hasError;
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(
        color: hasError ? AppColors.error : AppColors.outline,
        width: hasError ? 1.5 : 1,
      ),
    ),
    child: Text(value, style: Theme.of(context).textTheme.titleLarge),
  );
}
