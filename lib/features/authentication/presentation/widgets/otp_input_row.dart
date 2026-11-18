import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Six-digit OTP verification code input with individual bordered digit boxes,
/// auto-advance focus, backspace stepping, and paste support.
class OtpInputRow extends StatefulWidget {
  const OtpInputRow({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;

  @override
  State<OtpInputRow> createState() => OtpInputRowState();
}

class OtpInputRowState extends State<OtpInputRow> {
  static const int _length = AppConstants.otpLength;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get currentCode => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    widget.onChanged('');
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
  }

  void _handleTextChanged(int index, String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    // Handle full 6-digit paste into any box.
    if (digitsOnly.length > 1) {
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = i < digitsOnly.length ? digitsOnly[i] : '';
      }
      final nextIndex =
          digitsOnly.length >= _length ? _length - 1 : digitsOnly.length;
      _focusNodes[nextIndex].requestFocus();
      _emitChange();
      return;
    }

    if (digitsOnly.length == 1) {
      if (_controllers[index].text != digitsOnly) {
        _controllers[index].text = digitsOnly;
        _controllers[index].selection =
            const TextSelection.collapsed(offset: 1);
      }
      if (index < _length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    _emitChange();
  }

  void _emitChange() {
    final code = currentCode;
    widget.onChanged(code);
    if (code.length == _length) {
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: index == 0 || index == _length - 1 ? 2 : 4,
            ),
            child: SizedBox(
              height: AppSpacing.inputHeight,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: _length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: BorderSide(
                      color: widget.hasError
                          ? AppColors.dangerous
                          : colorScheme.outline,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: BorderSide(
                      color: widget.hasError
                          ? AppColors.dangerous
                          : colorScheme.primary,
                      width: 1.8,
                    ),
                  ),
                ),
                onChanged: (value) => _handleTextChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}
