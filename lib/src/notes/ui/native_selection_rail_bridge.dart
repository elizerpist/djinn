import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _defaultNativeSelectionRailChannel = MethodChannel(
  'djinn.selection_rail/native',
);

enum NativeSelectionRailActionType {
  toggleTags,
  outdent,
  indent,
  tagSelection,
  clearTags,
  previousTag,
  nextTag,
  toggleRounded,
  toggleGrey,
  toggleBorder,
  deleteTag,
}

class NativeSelectionRailAction {
  const NativeSelectionRailAction({required this.type, this.tagId});

  final NativeSelectionRailActionType type;
  final String? tagId;

  static NativeSelectionRailAction? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final actionName = value['action'];
    if (actionName is! String) {
      return null;
    }
    final type = _actionTypeByWireName[actionName];
    if (type == null) {
      return null;
    }
    final tagId = value['tagId'];
    return NativeSelectionRailAction(
      type: type,
      tagId: tagId is String ? tagId : null,
    );
  }
}

const _actionWireNames = <NativeSelectionRailActionType, String>{
  NativeSelectionRailActionType.toggleTags: 'toggleTags',
  NativeSelectionRailActionType.outdent: 'outdent',
  NativeSelectionRailActionType.indent: 'indent',
  NativeSelectionRailActionType.tagSelection: 'tagSelection',
  NativeSelectionRailActionType.clearTags: 'clearTags',
  NativeSelectionRailActionType.previousTag: 'previousTag',
  NativeSelectionRailActionType.nextTag: 'nextTag',
  NativeSelectionRailActionType.toggleRounded: 'toggleRounded',
  NativeSelectionRailActionType.toggleGrey: 'toggleGrey',
  NativeSelectionRailActionType.toggleBorder: 'toggleBorder',
  NativeSelectionRailActionType.deleteTag: 'deleteTag',
};

final _actionTypeByWireName = {
  for (final entry in _actionWireNames.entries) entry.value: entry.key,
};

class NativeSelectionRailTag {
  const NativeSelectionRailTag({
    required this.id,
    required this.label,
    this.colorValue,
  });

  final String id;
  final String label;
  final int? colorValue;

  Map<String, Object?> toJson() {
    return {'id': id, 'label': label, 'colorValue': colorValue};
  }
}

class NativeSelectionRailState {
  const NativeSelectionRailState._({
    required this.visible,
    this.rangeStart,
    this.rangeEnd,
    this.tags = const [],
    this.canDeleteTag = false,
    this.hasTaggedRanges = false,
    this.bottomRowExpanded = true,
    this.roundedCard = false,
    this.greyBackground = false,
    this.borderVisible = true,
  });

  const NativeSelectionRailState.hidden() : this._(visible: false);

  const NativeSelectionRailState.visible({
    required int rangeStart,
    required int rangeEnd,
    required List<NativeSelectionRailTag> tags,
    required bool canDeleteTag,
    required bool hasTaggedRanges,
    required bool bottomRowExpanded,
    required bool roundedCard,
    required bool greyBackground,
    required bool borderVisible,
  }) : this._(
         visible: true,
         rangeStart: rangeStart,
         rangeEnd: rangeEnd,
         tags: tags,
         canDeleteTag: canDeleteTag,
         hasTaggedRanges: hasTaggedRanges,
         bottomRowExpanded: bottomRowExpanded,
         roundedCard: roundedCard,
         greyBackground: greyBackground,
         borderVisible: borderVisible,
       );

  final bool visible;
  final int? rangeStart;
  final int? rangeEnd;
  final List<NativeSelectionRailTag> tags;
  final bool canDeleteTag;
  final bool hasTaggedRanges;
  final bool bottomRowExpanded;
  final bool roundedCard;
  final bool greyBackground;
  final bool borderVisible;

  Map<String, Object?> toJson() {
    return {
      'visible': visible,
      if (visible) ...{
        'rangeStart': rangeStart,
        'rangeEnd': rangeEnd,
        'tags': tags.map((tag) => tag.toJson()).toList(growable: false),
        'actions': {
          _actionWireNames[NativeSelectionRailActionType.toggleTags]!: true,
          _actionWireNames[NativeSelectionRailActionType.outdent]!: true,
          _actionWireNames[NativeSelectionRailActionType.indent]!: true,
          _actionWireNames[NativeSelectionRailActionType.tagSelection]!: true,
          _actionWireNames[NativeSelectionRailActionType.clearTags]!:
              canDeleteTag,
          _actionWireNames[NativeSelectionRailActionType.previousTag]!:
              hasTaggedRanges,
          _actionWireNames[NativeSelectionRailActionType.nextTag]!:
              hasTaggedRanges,
          _actionWireNames[NativeSelectionRailActionType.toggleRounded]!: true,
          _actionWireNames[NativeSelectionRailActionType.toggleGrey]!: true,
          _actionWireNames[NativeSelectionRailActionType.toggleBorder]!: true,
        },
        'style': {
          'bottomRowExpanded': bottomRowExpanded,
          'roundedCard': roundedCard,
          'greyBackground': greyBackground,
          'borderVisible': borderVisible,
        },
      },
    };
  }
}

class NativeSelectionRailController {
  NativeSelectionRailController({
    MethodChannel methodChannel = _defaultNativeSelectionRailChannel,
  }) : _methodChannel = methodChannel {
    _methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  final MethodChannel _methodChannel;
  FutureOr<void> Function(NativeSelectionRailAction action)? onAction;

  Future<void> setStateModel(NativeSelectionRailState state) {
    return _methodChannel.invokeMethod<void>('setState', state.toJson());
  }

  Future<void> hide() {
    return setStateModel(const NativeSelectionRailState.hidden());
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method != 'performAction') {
      throw PlatformException(
        code: 'unsupported_method',
        message: 'Unsupported native selection rail method: ${call.method}',
      );
    }
    final action = NativeSelectionRailAction.fromJson(call.arguments);
    if (action == null) {
      throw PlatformException(
        code: 'invalid_action',
        message: 'Invalid native selection rail action payload.',
      );
    }
    await onAction?.call(action);
  }

  void dispose() {
    _methodChannel.setMethodCallHandler(null);
  }
}
