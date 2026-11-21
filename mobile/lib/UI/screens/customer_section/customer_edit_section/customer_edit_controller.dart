import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../infrastructure/data_access_layer/api_repository/customers_api_repository.dart';
import '../../../../infrastructure/data_access_layer/networks/api_exception.dart';
import '../../../../infrastructure/data_access_layer/networks/api_result.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/kn_toast.dart';

/// Add customer / Edit customer (owners and managers): the name, the phone and email to reach them, the
/// main address and a private note. No Figma frame: built from the sign-up form fields. Saving an edit
/// changes the main contact and the first address (more contacts and addresses stay on the web for now).
class CustomerEditController extends GetxController {
  CustomerEditController({required this.customers, CustomerOutModel? customer, bool fromArguments = true})
      : original = customer ?? (fromArguments && Get.arguments is CustomerOutModel ? Get.arguments as CustomerOutModel : null);

  final ICustomersApiRepository customers;

  /// The customer being edited; null for a new one.
  final CustomerOutModel? original;

  bool get isNew => original == null;

  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final line1 = TextEditingController();
  final line2 = TextEditingController();
  final city = TextEditingController();
  final postcode = TextEditingController();
  final notes = TextEditingController();

  /// A message under a field: name, phone, email or address.
  final RxMap<String, String> errors = <String, String>{}.obs;
  final RxBool saving = false.obs;
  final String _clientUuid = const Uuid().v4();

  ContactOutModel? get _contact {
    final cs = original?.contacts ?? const <ContactOutModel>[];
    return cs.firstWhereOrNull((c) => c.isPrimary) ?? cs.firstOrNull;
  }

  SiteOutModel? get _site => original?.sites.firstOrNull;

  @override
  void onInit() {
    super.onInit();
    final c = original;
    if (c != null) {
      name.text = c.name;
      notes.text = c.notes ?? '';
      phone.text = _contact?.phone ?? '';
      email.text = _contact?.email ?? '';
      final s = _site;
      line1.text = s?.addressLine1 ?? '';
      line2.text = s?.addressLine2 ?? '';
      city.text = s?.city ?? '';
      postcode.text = s?.postcode ?? '';
    }
  }

  @override
  void onClose() {
    for (final c in [name, phone, email, line1, line2, city, postcode, notes]) {
      c.dispose();
    }
    super.onClose();
  }

  String get title => isNew ? LangKeys.customersAdd.tr : LangKeys.customersEdit.tr;

  void clearError(String field) => errors.remove(field);

  static String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Checks what can be checked here; the server checks the phone and email.
  bool _valid() {
    errors.clear();
    if (_t(name) == null) errors['name'] = LangKeys.customersNameNeeded.tr;
    final anyAddress = [line2, city, postcode].any((c) => _t(c) != null);
    if (_t(line1) == null && (anyAddress || _site != null)) errors['address'] = LangKeys.customersAddressNeeded.tr;
    return errors.isEmpty;
  }

  Map<String, dynamic> get _siteBody => {
        'address_line1': _t(line1),
        'address_line2': _t(line2),
        'city': _t(city),
        'postcode': _t(postcode),
      };

  /// Saves and goes back with the customer as it is now.
  Future<void> onSave() async {
    if (saving.value || !_valid()) return;
    saving.value = true;
    final saved = isNew ? await _create() : await _update();
    saving.value = false;
    if (saved == null) return;
    KnToast.success(isNew ? LangKeys.customersAdded.tr : LangKeys.customersSaved.tr);
    Get.back<CustomerOutModel>(result: saved);
  }

  Future<CustomerOutModel?> _create() async {
    final n = _t(name)!;
    final reach = _t(phone) != null || _t(email) != null;
    final result = await customers.create({
      'name': n,
      'notes': ?_t(notes),
      'client_uuid': _clientUuid,
      if (reach) 'contact': {'name': n, 'phone': ?_t(phone), 'email': ?_t(email), 'is_primary': true},
      if (_t(line1) != null) 'site': _siteBody,
    });
    return _took(result);
  }

  Future<CustomerOutModel?> _update() async {
    final c = original!;
    final n = _t(name)!;
    if (n != c.name || _t(notes) != c.notes) {
      if (_took(await customers.update(c.id, {'name': n, 'notes': _t(notes)})) == null) return null;
    }
    final contact = _contact;
    if (contact != null) {
      if (_t(phone) != contact.phone || _t(email) != contact.email) {
        if (_took(await customers.saveContact(c.id, {'phone': _t(phone), 'email': _t(email)}, contactId: contact.id)) == null) {
          return null;
        }
      }
    } else if (_t(phone) != null || _t(email) != null) {
      final body = {'name': n, 'phone': ?_t(phone), 'email': ?_t(email), 'is_primary': true};
      if (_took(await customers.saveContact(c.id, body)) == null) return null;
    }
    final site = _site;
    final now = _siteBody;
    if (site != null) {
      final was = {
        'address_line1': site.addressLine1,
        'address_line2': site.addressLine2,
        'city': site.city,
        'postcode': site.postcode,
      };
      if (now.entries.any((e) => was[e.key] != e.value)) {
        if (_took(await customers.saveSite(c.id, now, siteId: site.id)) == null) return null;
      }
    } else if (_t(line1) != null) {
      if (_took(await customers.saveSite(c.id, now)) == null) return null;
    }
    return _took(await customers.customer(c.id));
  }

  /// The data, or null after showing what went wrong (under the field when the server names one).
  T? _took<T>(ApiResult<T> result) {
    final data = result.dataOrNull;
    if (data != null) return data;
    final e = result.errorOrNull!;
    if (!_fieldErrors(e)) KnToast.error(e.message);
    return null;
  }

  bool _fieldErrors(ApiException e) {
    if (e.code == 'invalid_phone') {
      errors['phone'] = LangKeys.customersPhoneBad.tr;
      return true;
    }
    var any = false;
    for (final key in e.fields.keys) {
      final field = key.split('.').last;
      final message = switch (field) {
        'phone' => LangKeys.customersPhoneBad.tr,
        'email' => LangKeys.customersEmailBad.tr,
        'name' => LangKeys.customersNameNeeded.tr,
        'address_line1' => LangKeys.customersAddressNeeded.tr,
        _ => null,
      };
      if (message != null) {
        errors[field == 'address_line1' ? 'address' : field] = message;
        any = true;
      }
    }
    return any;
  }
}
