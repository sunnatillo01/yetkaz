import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/address/data/models/address_model.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/domain/usecases/address_usecases.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  test('Address details and model round trip', () {
    final a = tAddress.copyWith(entrance: '2', floor: '', apartment: '15');
    expect(a.details, ['2', '15']);
    expect(AddressModel.fromEntity(a).toEntity(), a);
    expect(AddressModel.fromEntity(a).toFirestore().containsKey('id'), isFalse);
    expect(AddressLabel.parse('work'), AddressLabel.work);
    expect(AddressLabel.parse('???'), AddressLabel.other);
  });

  group('SaveAddress', () {
    late MockAddressRepository repo;
    setUp(() {
      repo = MockAddressRepository();
      when(() => repo.setCurrent(any())).thenAnswer((_) async {});
    });

    test('a new address becomes the current one', () async {
      final draft = tAddress.copyWith(id: null);
      when(() => repo.save(draft)).thenAnswer((_) async => const Right(tAddress));
      when(() => repo.current()).thenReturn(tAddress.copyWith(id: 'other'));
      final result = await SaveAddress(repo)(draft);
      expect(result, const Right<Failure, Address>(tAddress));
      verify(() => repo.setCurrent(tAddress)).called(1);
    });

    test('editing another saved address keeps the current one', () async {
      final edited = tAddress.copyWith(id: 'a2', text: 'Work');
      when(() => repo.save(edited)).thenAnswer((_) async => Right(edited));
      when(() => repo.current()).thenReturn(tAddress);
      await SaveAddress(repo)(edited);
      verifyNever(() => repo.setCurrent(any()));
    });

    test('failure is returned and nothing is selected', () async {
      when(() => repo.save(any())).thenAnswer((_) async => const Left(Failure.network()));
      expect((await SaveAddress(repo)(tAddress)).isLeft(), isTrue);
      verifyNever(() => repo.setCurrent(any()));
    });
  });

  group('CurrentAddressCubit', () {
    late MockGetCurrentAddress get;
    late MockSelectAddress select;
    setUp(() {
      get = MockGetCurrentAddress();
      select = MockSelectAddress();
      when(() => select(any())).thenAnswer((_) async {});
    });

    blocTest<CurrentAddressCubit, Address?>(
      'loads, selects and resets',
      build: () {
        when(() => get()).thenReturn(null);
        return CurrentAddressCubit(get, select);
      },
      act: (c) async {
        c.load();
        await c.select(tAddress);
        c.reset();
      },
      // The first emit is delivered even if equal to the initial state.
      expect: () => [null, tAddress, null],
    );
  });

  group('SavedAddressesCubit', () {
    late MockWatchSavedAddresses watch;
    late MockDeleteAddress delete;
    late StreamController<Either<Failure, List<Address>>> stream;

    setUp(() {
      watch = MockWatchSavedAddresses();
      delete = MockDeleteAddress();
      stream = StreamController();
      when(() => watch()).thenAnswer((_) => stream.stream);
    });

    blocTest<SavedAddressesCubit, SavedAddressesState>(
      'shows the list in real time',
      build: () => SavedAddressesCubit(watch, delete),
      act: (c) async {
        await c.start();
        stream
          ..add(const Right([tAddress]))
          ..add(const Right([]));
      },
      expect: () => [
        const SavedAddressesState.loading(),
        const SavedAddressesState.success([tAddress]),
        const SavedAddressesState.success([]),
      ],
    );

    blocTest<SavedAddressesCubit, SavedAddressesState>(
      'shows failure',
      build: () => SavedAddressesCubit(watch, delete),
      act: (c) async {
        await c.start();
        stream.add(const Left(Failure.permission()));
      },
      expect: () => [
        const SavedAddressesState.loading(),
        const SavedAddressesState.failure(Failure.permission()),
      ],
    );

    test('delete returns the failure for the UI', () async {
      when(() => delete('a1')).thenAnswer((_) async => const Left(Failure.network()));
      final cubit = SavedAddressesCubit(watch, delete);
      expect(await cubit.delete('a1'), const Failure.network());
      await cubit.close();
    });
  });

  group('AddressPickerCubit', () {
    late MockGetMyLocation myLocation;
    late MockResolveAddress resolve;
    late MockSaveAddress save;
    late MockLocationRepository location;
    const point = Coordinates(lat: 41.33, lng: 69.29);

    setUp(() {
      myLocation = MockGetMyLocation();
      resolve = MockResolveAddress();
      save = MockSaveAddress();
      location = MockLocationRepository();
      when(() => resolve(any(), languageCode: any(named: 'languageCode')))
          .thenAnswer((_) async => const Right('Amir Temur 1'));
    });

    AddressPickerCubit build() => AddressPickerCubit(myLocation, resolve, save, location);

    blocTest<AddressPickerCubit, AddressPickerState>(
      'moving the map resolves the address after a debounce',
      build: build,
      act: (c) => c.cameraIdle(point),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        const AddressPickerState(center: point, isResolving: true),
        const AddressPickerState(center: point, addressText: 'Amir Temur 1'),
      ],
    );

    blocTest<AddressPickerCubit, AddressPickerState>(
      '"my location" moves the camera',
      build: () {
        when(() => myLocation(any())).thenAnswer((_) async => const Right(point));
        return build();
      },
      act: (c) => c.locateMe(),
      wait: const Duration(milliseconds: 50),
      verify: (c) {
        expect(c.state.cameraTarget, point);
        expect(c.state.addressText, 'Amir Temur 1');
      },
    );

    blocTest<AddressPickerCubit, AddressPickerState>(
      'denied permission is reported and settings can be opened',
      build: () {
        when(() => myLocation(any()))
            .thenAnswer((_) async => const Left(Failure.location(LocationErrorCode.deniedForever)));
        when(() => location.openAppSettings()).thenAnswer((_) async {});
        return build();
      },
      act: (c) async {
        await c.locateMe();
        await c.openSettings();
      },
      verify: (c) {
        expect(c.state.failure, const Failure.location(LocationErrorCode.deniedForever));
        verify(() => location.openAppSettings()).called(1);
      },
    );

    blocTest<AddressPickerCubit, AddressPickerState>(
      'save uses the map centre and the resolved text',
      build: () {
        when(() => save(any()))
            .thenAnswer((inv) async => Right(inv.positionalArguments.first as Address));
        return build();
      },
      seed: () => const AddressPickerState(center: point, addressText: 'Navoiy 5'),
      act: (c) => c.save(tAddress.copyWith(floor: '3')),
      verify: (c) {
        expect(c.state.saved!.location, point);
        expect(c.state.saved!.text, 'Navoiy 5');
        expect(c.state.saved!.floor, '3');
      },
    );
  });
}
