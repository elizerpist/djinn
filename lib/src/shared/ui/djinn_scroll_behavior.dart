import 'package:flutter/material.dart';

class DjinnScrollBehavior extends MaterialScrollBehavior {
  const DjinnScrollBehavior();

  static const ScrollPhysics menuPhysics = ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => menuPhysics;
}
