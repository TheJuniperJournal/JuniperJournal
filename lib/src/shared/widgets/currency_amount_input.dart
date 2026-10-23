import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

String currencySymbol(String code) => switch (code) {
  'EUR' => '€',
  'GBP' => '£',
  _ => r'$',
};
String currencyFlag(String code) => switch (code) {
  'EUR' => '🇪🇺',
  'GBP' => '🇬🇧',
  'CAD' => '🇨🇦',
  'AUD' => '🇦🇺',
  _ => '🇺🇸',
};

class CurrencyAmountInput extends StatelessWidget {
  const CurrencyAmountInput({
    super.key,
    required this.controller,
    required this.currency,
    this.onCurrencyChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String currency;
  final ValueChanged<String>? onCurrencyChanged;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.primary),
      borderRadius: BorderRadius.circular(12),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.right,
              textAlignVertical: TextAlignVertical.center,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              validator: validator,
              style: AppTypography.inputText,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: '${currencySymbol(currency)}   ',
                hintText: '0.00',
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
          Container(
            width: 116,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.borderLight)),
            ),
            alignment: Alignment.center,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currency,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: AppTypography.body,
                icon: const Icon(
                  Icons.unfold_more,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                items: [
                  for (final code in ['USD', 'EUR', 'GBP', 'CAD', 'AUD'])
                    DropdownMenuItem(
                      value: code,
                      child: Text('${currencyFlag(code)} $code'),
                    ),
                ],
                onChanged: onCurrencyChanged == null
                    ? null
                    : (value) {
                        if (value != null) onCurrencyChanged!(value);
                      },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
