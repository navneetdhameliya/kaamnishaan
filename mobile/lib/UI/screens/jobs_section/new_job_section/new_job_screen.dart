import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_dropdown_field.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/new_job_parts.dart';
import 'new_job_controller.dart';

/// M16 New job (Figma 44:1064; missing fields 44:1144).
class NewJobScreen extends GetView<NewJobController> {
  const NewJobScreen({super.key});

  void _openCustomers() {
    controller.prepareSearch();
    showKnBottomSheet<void>(
      title: LangKeys.newjobSearchCustomers.tr,
      child: _CustomerSearch(controller: controller),
    );
  }

  void _openChecklists() {
    showKnBottomSheet<void>(
      title: LangKeys.newjobChecklist.tr,
      child: Obx(
        () => ListView(
          shrinkWrap: true,
          children: [
            PickRow(
              key: const ValueKey('checklist-none'),
              title: LangKeys.newjobChecklistNone.tr,
              selected: controller.checklist.value == null,
              onTap: () => controller.onChecklistPicked(null),
            ),
            for (final t in controller.templates) ...[
              const SizedBox(height: KnSize.space8),
              PickRow(
                key: ValueKey('checklist-${t.id}'),
                title: controller.checklistLabel(t),
                selected: controller.checklist.value?.id == t.id,
                onTap: () => controller.onChecklistPicked(t),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: controller.day.value,
      firstDate: controller.firstDay,
      lastDate: controller.firstDay.add(const Duration(days: 365)),
    );
    controller.onDatePicked(d);
  }

  Future<void> _pickTime(BuildContext context) async {
    final t = await showTimePicker(
      context: context,
      initialTime: controller.time.value ?? const TimeOfDay(hour: 10, minute: 0),
    );
    controller.onTimePicked(t);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('newjob-create'),
              text: LangKeys.newjobCreate.tr,
              loading: controller.saving.value,
              onTap: controller.onCreateTap,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final banner = controller.missingBanner;
          final tech = controller.technician.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space16),
                child: KnTitleBar(
                  buttonKey: const ValueKey('newjob-close'),
                  title: LangKeys.newjobTitle.tr,
                  subtitle: controller.company,
                  icon: LucideIcons.x,
                ),
              ),
              if (banner != null) ...[MissingBanner(text: banner), const SizedBox(height: KnSize.space12)],
              Expanded(
                child: ScrollConfiguration(
                  behavior: const KnScrollBehavior(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(KnSize.space16, 0, KnSize.space16, KnSize.space24),
                    children: [
                      KnDropdownField(
                        key: const ValueKey('newjob-customer'),
                        label: LangKeys.newjobCustomer.tr,
                        value: controller.customerName,
                        placeholder: LangKeys.newjobCustomerHint.tr,
                        showChevron: false,
                        errorText: controller.customerMissing ? LangKeys.newjobCustomerMissing.tr : null,
                        onTap: _openCustomers,
                      ),
                      const SizedBox(height: KnSize.space12),
                      KnCustomTextFormField(
                        fieldKey: const ValueKey('newjob-address'),
                        label: LangKeys.newjobAddress.tr,
                        controller: controller.address,
                        hintText: LangKeys.newjobAddressHint.tr,
                        keyboardType: TextInputType.streetAddress,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: KnSize.space12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: KnDropdownField(
                              key: const ValueKey('newjob-date'),
                              label: LangKeys.newjobDate.tr,
                              value: controller.dayLabel,
                              onTap: () => _pickDate(context),
                            ),
                          ),
                          const SizedBox(width: KnSize.space12),
                          Expanded(
                            child: KnDropdownField(
                              key: const ValueKey('newjob-time'),
                              label: LangKeys.newjobTime.tr,
                              value: controller.timeLabel,
                              placeholder: LangKeys.newjobTimeHint.tr,
                              errorText: controller.timeMissing ? LangKeys.newjobTimeMissing.tr : null,
                              onTap: () => _pickTime(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KnSize.space12),
                      KnCustomTextFormField(
                        fieldKey: const ValueKey('newjob-work'),
                        label: LangKeys.newjobWork.tr,
                        controller: controller.work,
                        focusNode: controller.workFocus,
                        hintText: LangKeys.newjobWorkHint.tr,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: controller.onWorkChanged,
                        errorText: controller.workMissing ? LangKeys.newjobWorkMissing.tr : null,
                        trailing: CustomInkWell(
                          key: const ValueKey('newjob-work-mic'),
                          onTap: controller.onWorkMicTap,
                          borderRadius: BorderRadius.circular(20),
                          child: Ink(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(20)),
                            child: Icon(LucideIcons.mic, size: 22, color: kn.textPrimary),
                          ),
                        ),
                      ),
                      if (controller.templates.isNotEmpty) ...[
                        const SizedBox(height: KnSize.space12),
                        KnDropdownField(
                          key: const ValueKey('newjob-checklist'),
                          label: LangKeys.newjobChecklist.tr,
                          value: controller.checklist.value == null
                              ? ''
                              : controller.checklistLabel(controller.checklist.value!),
                          placeholder: LangKeys.newjobChecklistNone.tr,
                          onTap: _openChecklists,
                        ),
                      ],
                      const SizedBox(height: KnSize.space12),
                      CustomBaseTextWidget(LangKeys.newjobTechnician.tr, style: text.label),
                      const SizedBox(height: KnSize.space8),
                      AssignRow(
                        name: tech?.name,
                        line: controller.technicianLine,
                        initials: controller.technicianInitials,
                        avatarUrl: tech?.avatarUrl,
                        onTap: controller.onAssignTap,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// The customer search sheet: a search box, matching customers with their address, and
/// "Add “…” as new customer".
class _CustomerSearch extends StatelessWidget {
  const _CustomerSearch({required this.controller});

  final NewJobController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('customer-search'),
          controller: controller.search,
          autofocus: true,
          onChanged: controller.onSearchChanged,
          textCapitalization: TextCapitalization.words,
          style: context.knText.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: kn.bgSurface,
            hintText: LangKeys.newjobCustomerHint.tr,
            prefixIcon: Icon(LucideIcons.search, size: 20, color: kn.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KnSize.radiusMd),
              borderSide: BorderSide(color: kn.borderStrong),
            ),
          ),
        ),
        const SizedBox(height: KnSize.space12),
        Flexible(
          child: Obx(
            () => ListView(
              shrinkWrap: true,
              children: [
                if (controller.canAddNew)
                  PickRow(
                    key: const ValueKey('customer-add'),
                    icon: LucideIcons.userPlus,
                    title: LangKeys.newjobAddCustomer.trParams({'name': controller.query.value.trim()}),
                    subtitle: LangKeys.newjobNewCustomer.tr,
                    onTap: controller.onNewCustomerPicked,
                  ),
                for (final c in controller.found) ...[
                  const SizedBox(height: KnSize.space8),
                  PickRow(
                    key: ValueKey('customer-${c.id}'),
                    title: c.name,
                    subtitle: c.site?.address ?? c.city,
                    selected: controller.customer.value?.id == c.id,
                    onTap: () => controller.onCustomerPicked(c),
                  ),
                ],
                if (!controller.searching.value && controller.found.isEmpty && !controller.canAddNew)
                  Padding(
                    padding: const EdgeInsets.all(KnSize.space16),
                    child: CustomBaseTextWidget(
                      LangKeys.newjobNoCustomers.tr,
                      style: context.knText.body,
                      color: kn.textSecondary,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
