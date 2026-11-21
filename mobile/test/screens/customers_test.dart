import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/customer_section/customer_edit_section/customer_edit_controller.dart';
import 'package:kaamnishaan/UI/screens/customer_section/customer_list_section/customer_list_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

/// Toasts and going back need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

CustomerListItemModel item(String id, String name, {String? contact, String? phone, String? city, int jobs = 0}) =>
    CustomerListItemModel(
      id: id,
      name: name,
      jobCount: jobs,
      city: city,
      primaryContact: contact == null ? null : ContactBriefModel(name: contact, phone: phone),
    );

CustomerListModel page(List<CustomerListItemModel> data, {String? next}) =>
    CustomerListModel(data: data, meta: ListMetaModel(nextCursor: next));

final mehta = CustomerOutModel(
  id: 'c1',
  name: 'Mehta Residence',
  notes: 'Dog in the yard',
  customerSince: DateTime(2024, 3, 2),
  jobCount: 5,
  contacts: const [
    ContactOutModel(id: 'k1', name: 'Rahul Mehta', isPrimary: true, reviewOptedOut: false, phone: '+919876543210'),
  ],
  sites: const [SiteOutModel(id: 's1', addressLine1: '12 MG Road', city: 'Ahmedabad', postcode: '380009', country: 'IN')],
  updatedAt: DateTime(2026, 11, 1),
  version: 1,
);

void main() {
  late MockCustomersRepository customers;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    customers = MockCustomersRepository();
  });

  group('Customers list', () {
    test('rows say who to call, where, and how many jobs; more come as you scroll', () async {
      when(() => customers.page(q: any(named: 'q'), cursor: any(named: 'cursor'))).thenAnswer((i) async {
        final cursor = i.namedArguments[#cursor] as String?;
        return ApiSuccess<CustomerListModel>(
          cursor == null
              ? page([
                  item('c1', 'Mehta Residence', contact: 'Rahul Mehta', city: 'Ahmedabad', jobs: 5),
                  item('c2', 'Priya Shah', contact: 'priya shah', phone: '+919800000000', jobs: 1),
                ], next: 'p2')
              : page([item('c3', 'Green Valley Clinic')]),
        );
      });
      final c = CustomerListController(customers: customers, debounce: Duration.zero);
      await c.load();
      final [a, b] = c.items.toList();
      expect((c.line(a), c.jobs(a)), ('Rahul Mehta · Ahmedabad', '5 jobs'));
      expect((c.line(b), c.jobs(b)), ('+919800000000', '1 job')); // the contact is the customer: show the phone
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect((c.items.length, c.hasMore, c.jobs(c.items.last)), (3, false, 'No jobs yet'));
      await c.loadMore(); // nothing more to ask for
      verify(() => customers.page(q: '', cursor: 'p2')).called(1);
    });

    test('searching asks again; an empty search result says so', () async {
      when(() => customers.page(q: any(named: 'q'), cursor: any(named: 'cursor')))
          .thenAnswer((_) async => ApiSuccess<CustomerListModel>(page([])));
      final c = CustomerListController(customers: customers, debounce: const Duration(milliseconds: 10));
      await c.load();
      expect((c.empty, c.noResults), (true, false));
      c.onSearchChanged('meh');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      verify(() => customers.page(q: 'meh')).called(1);
      expect((c.empty, c.noResults), (false, true));
    });
  });

  group('Add / Edit customer', () {
    test('a new customer goes in one call with the contact and the address', () async {
      when(() => customers.create(any())).thenAnswer((_) async => ApiSuccess<CustomerOutModel>(mehta));
      final c = CustomerEditController(customers: customers, fromArguments: false);
      c.onInit();
      expect(c.isNew, isTrue);
      await c.onSave();
      expect(c.errors['name'], "Type the customer's name.");
      verifyNever(() => customers.create(any()));

      c.name.text = ' Mehta Residence ';
      c.phone.text = '98765 43210';
      c.city.text = 'Ahmedabad';
      await c.onSave();
      expect(c.errors['address'], 'Type the house and street.'); // a city without the street
      c.line1.text = '12 MG Road';
      await _ignoreApp(c.onSave);
      final body = verify(() => customers.create(captureAny())).captured.single as Map<String, dynamic>;
      expect(body['name'], 'Mehta Residence');
      expect(body['contact'], {'name': 'Mehta Residence', 'phone': '98765 43210', 'is_primary': true});
      expect(body['site'], {'address_line1': '12 MG Road', 'address_line2': null, 'city': 'Ahmedabad', 'postcode': null});
      expect(body['client_uuid'], isA<String>());
      expect(body.containsKey('notes'), isFalse);
    });

    test('editing sends only what changed: the contact and the address are their own calls', () async {
      when(() => customers.saveContact(any(), any(), contactId: any(named: 'contactId'))).thenAnswer(
        (_) async => const ApiSuccess<ContactOutModel>(
          ContactOutModel(id: 'k1', name: 'Rahul Mehta', isPrimary: true, reviewOptedOut: false),
        ),
      );
      when(() => customers.customer(any())).thenAnswer((_) async => ApiSuccess<CustomerOutModel>(mehta));
      final c = CustomerEditController(customers: customers, customer: mehta);
      c.onInit();
      expect((c.name.text, c.phone.text, c.line1.text, c.postcode.text, c.notes.text),
          ('Mehta Residence', '+919876543210', '12 MG Road', '380009', 'Dog in the yard'));
      c.email.text = 'rahul@example.com';
      await _ignoreApp(c.onSave);
      verifyNever(() => customers.update(any(), any()));
      verifyNever(() => customers.saveSite(any(), any(), siteId: any(named: 'siteId')));
      final body = verify(() => customers.saveContact('c1', captureAny(), contactId: 'k1')).captured.single;
      expect(body, {'phone': '+919876543210', 'email': 'rahul@example.com'});
      verify(() => customers.customer('c1')).called(1);
    });

    test('the server says the phone is wrong: it shows under the phone', () async {
      when(() => customers.update(any(), any())).thenAnswer(
        (_) async => const ApiFailure<CustomerOutModel>(ApiException(code: 'invalid_phone', message: 'x')),
      );
      when(() => customers.saveContact(any(), any(), contactId: any(named: 'contactId'))).thenAnswer(
        (_) async => const ApiFailure<ContactOutModel>(ApiException(code: 'invalid_phone', message: 'x')),
      );
      final c = CustomerEditController(customers: customers, customer: mehta);
      c.onInit();
      c.phone.text = '12';
      await _ignoreApp(c.onSave);
      expect(c.errors['phone'], "This phone number doesn't look right.");
      expect(c.saving.value, isFalse);
      verifyNever(() => customers.customer(any()));
    });
  });
}
