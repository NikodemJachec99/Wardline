import 'package:flutter/material.dart';

import '../../theme/wl_tokens.dart';
import 'wl_icons.dart';

/// 48 high search field. Focus: white fill, primary border + soft ring,
/// clear button (32dp icon in a 48dp target).
class WlSearchBar extends StatefulWidget {
  const WlSearchBar({
    this.controller,
    this.hint = 'Name, ID or department',
    this.onChanged,
    this.autofocus = false,
    this.semanticsLabel = 'Search patients',
    super.key,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String semanticsLabel;

  @override
  State<WlSearchBar> createState() => _WlSearchBarState();
}

class _WlSearchBarState extends State<WlSearchBar> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: WlMotion.duration(context, t.motion.fast),
      constraints: BoxConstraints(minHeight: t.space.input),
      decoration: BoxDecoration(
        color: focused ? c.surface : c.subtle,
        borderRadius: t.radius.inputBr,
        border: Border.all(color: focused ? c.primary : c.subtle),
        boxShadow: focused
            ? [BoxShadow(color: c.primarySoft, spreadRadius: 3)]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(width: t.space.sm + 2),
          Icon(WlIcons.search, size: 20, color: c.textSecondary),
          SizedBox(width: t.space.sm - 2),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: t.typography.body.copyWith(color: c.text),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: t.typography.body.copyWith(color: c.textSecondary),
                semanticCounterText: '',
              ).copyWith(labelText: null),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              iconSize: 20,
              constraints: BoxConstraints.tight(Size.square(t.space.touchMin)),
              icon: Icon(WlIcons.clear, color: c.textSecondary),
              onPressed: () {
                _controller.clear();
                widget.onChanged?.call('');
              },
            )
          else
            SizedBox(width: t.space.sm),
        ],
      ),
    );
  }
}
