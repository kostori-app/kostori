// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clipboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ClipboardNotifier)
final clipboardProvider = ClipboardNotifierProvider._();

final class ClipboardNotifierProvider
    extends $NotifierProvider<ClipboardNotifier, ClipboardState> {
  ClipboardNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipboardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipboardNotifierHash();

  @$internal
  @override
  ClipboardNotifier create() => ClipboardNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipboardState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipboardState>(value),
    );
  }
}

String _$clipboardNotifierHash() => r'f370309357c85e8fd35ef84eadb6dad7338397fe';

abstract class _$ClipboardNotifier extends $Notifier<ClipboardState> {
  ClipboardState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ClipboardState, ClipboardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ClipboardState, ClipboardState>,
              ClipboardState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
