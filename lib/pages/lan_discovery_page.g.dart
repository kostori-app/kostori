// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lan_discovery_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LanDiscovery)
final lanDiscoveryProvider = LanDiscoveryProvider._();

final class LanDiscoveryProvider
    extends $NotifierProvider<LanDiscovery, LanDiscoveryState> {
  LanDiscoveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lanDiscoveryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lanDiscoveryHash();

  @$internal
  @override
  LanDiscovery create() => LanDiscovery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LanDiscoveryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LanDiscoveryState>(value),
    );
  }
}

String _$lanDiscoveryHash() => r'c302d204c225b9a0cbc2e52c98a49ada456e9c73';

abstract class _$LanDiscovery extends $Notifier<LanDiscoveryState> {
  LanDiscoveryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LanDiscoveryState, LanDiscoveryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LanDiscoveryState, LanDiscoveryState>,
              LanDiscoveryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
