import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../../infrastructure/models/api_models.g.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// "Choose country" sheet (Figma 71:2129): search box and the list of countries from /config.
/// [showDialCode] is off where the country is not about a phone number (M07 company country).
class KnCountryPickerSheet extends StatefulWidget {
  const KnCountryPickerSheet({
    super.key,
    required this.countries,
    required this.selected,
    required this.onSelected,
    this.showDialCode = true,
  });

  final List<CountryOutModel> countries;
  final CountryOutModel selected;
  final ValueChanged<CountryOutModel> onSelected;
  final bool showDialCode;

  @override
  State<KnCountryPickerSheet> createState() => _KnCountryPickerSheetState();
}

class _KnCountryPickerSheetState extends State<KnCountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final q = _query.trim().toLowerCase();
    final list = widget.countries
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.dialCode.contains(q))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: context.knText.body,
          decoration: InputDecoration(
            hintText: LangKeys.authSearchCountry.tr,
            prefixIcon: Icon(LucideIcons.search, color: kn.textSecondary),
            filled: true,
            fillColor: kn.bgSurface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              borderSide: BorderSide(color: kn.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              borderSide: BorderSide(color: kn.focusRing, width: 2),
            ),
          ),
        ),
        const SizedBox(height: KnSize.space12),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              final selected = c.code == widget.selected.code;
              final radius = BorderRadius.circular(KnSize.radiusLg);
              return CustomInkWell(
                key: ValueKey('country-${c.code}'),
                onTap: () => widget.onSelected(c),
                borderRadius: radius,
                child: Ink(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: KnSize.space12),
                  decoration: BoxDecoration(
                    color: selected ? kn.bgSubtle : Colors.transparent,
                    borderRadius: radius,
                    border: selected ? Border.all(color: kn.actionPrimary, width: 2) : null,
                  ),
                  child: Row(
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: KnSize.space12),
                      Expanded(child: CustomBaseTextWidget(c.name, style: context.knText.label)),
                      if (widget.showDialCode)
                        CustomBaseTextWidget(c.dialCode, style: context.knText.body, color: kn.textSecondary),
                      if (selected) ...[
                        const SizedBox(width: KnSize.space12),
                        Icon(LucideIcons.check, size: 22, color: kn.textPrimary),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
