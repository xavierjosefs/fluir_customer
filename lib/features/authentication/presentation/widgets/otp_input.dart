import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class OtpInput extends StatefulWidget {
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
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final activeIndex = widget.value.length.clamp(0, 5);
    return Semantics(
      label: 'Código de verificación de 6 dígitos',
      textField: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: Row(
              children: List.generate(
                6,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == 5 ? 0 : AppSpacing.xs,
                    ),
                    child: _OtpCell(
                      value: index < widget.value.length
                          ? widget.value[index]
                          : '',
                      isActive:
                          _focusNode.hasFocus &&
                          !widget.hasError &&
                          index == activeIndex,
                      isCompleted: index < widget.value.length,
                      hasError: widget.hasError,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: widget.onChanged,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.value,
    required this.isActive,
    required this.isCompleted,
    required this.hasError,
  });

  final String value;
  final bool isActive;
  final bool isCompleted;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = hasError
        ? AppColors.error
        : isActive
        ? AppColors.brandBlue
        : isCompleted
        ? AppColors.brandBlue.withValues(alpha: .45)
        : colors.outline;
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
      ),
      child: Text(value, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
