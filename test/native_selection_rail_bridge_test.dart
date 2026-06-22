import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/ui/native_selection_rail_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test.djinn.selection_rail/native');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'serializes visible selection rail state to the native channel',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      final controller = NativeSelectionRailController(methodChannel: channel);

      await controller.setStateModel(
        NativeSelectionRailState.visible(
          rangeStart: 2,
          rangeEnd: 7,
          tags: const [
            NativeSelectionRailTag(
              id: 'topic:Alpha',
              label: 'Alpha',
              colorValue: 0xFF2563EB,
            ),
          ],
          canDeleteTag: true,
          hasTaggedRanges: true,
          bottomRowExpanded: true,
          roundedCard: false,
          greyBackground: false,
          borderVisible: true,
        ),
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'setState');
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments, containsPair('visible', true));
      expect(arguments, containsPair('rangeStart', 2));
      expect(arguments, containsPair('rangeEnd', 7));
      expect(arguments['tags'], [
        {'id': 'topic:Alpha', 'label': 'Alpha', 'colorValue': 0xFF2563EB},
      ]);
      expect(arguments['actions'], isA<Map<Object?, Object?>>());
      expect(arguments['style'], isA<Map<Object?, Object?>>());

      controller.dispose();
    },
  );

  test('visible state includes table-style action and row flags', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final controller = NativeSelectionRailController(methodChannel: channel);

    await controller.setStateModel(
      NativeSelectionRailState.visible(
        rangeStart: 0,
        rangeEnd: 5,
        tags: const [],
        canDeleteTag: false,
        hasTaggedRanges: true,
        bottomRowExpanded: false,
        roundedCard: true,
        greyBackground: true,
        borderVisible: false,
      ),
    );

    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect((arguments['actions'] as Map<Object?, Object?>).keys, [
      'toggleTags',
      'outdent',
      'indent',
      'tagSelection',
      'clearTags',
      'previousTag',
      'nextTag',
      'toggleRounded',
      'toggleGrey',
      'toggleBorder',
    ]);
    expect(arguments['actions'], containsPair('clearTags', false));
    expect(arguments['actions'], containsPair('previousTag', true));
    expect(arguments['actions'], containsPair('nextTag', true));
    expect(arguments['style'], {
      'bottomRowExpanded': false,
      'roundedCard': true,
      'greyBackground': true,
      'borderVisible': false,
    });

    controller.dispose();
  });

  test('hide sends a hidden rail state', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final controller = NativeSelectionRailController(methodChannel: channel);

    await controller.hide();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setState');
    expect(calls.single.arguments, containsPair('visible', false));

    controller.dispose();
  });

  test('dispatches native performAction callbacks', () async {
    NativeSelectionRailAction? action;
    final controller = NativeSelectionRailController(methodChannel: channel)
      ..onAction = (nextAction) {
        action = nextAction;
      };

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('performAction', {'action': 'indent'}),
          ),
          (_) {},
        );

    expect(action?.type, NativeSelectionRailActionType.indent);
    expect(action?.tagId, isNull);

    controller.dispose();
  });

  test('dispatches native tag delete callbacks with tag id', () async {
    NativeSelectionRailAction? action;
    final controller = NativeSelectionRailController(methodChannel: channel)
      ..onAction = (nextAction) {
        action = nextAction;
      };

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('performAction', {
              'action': 'deleteTag',
              'tagId': 'topic:Alpha',
            }),
          ),
          (_) {},
        );

    expect(action?.type, NativeSelectionRailActionType.deleteTag);
    expect(action?.tagId, 'topic:Alpha');

    controller.dispose();
  });
}
