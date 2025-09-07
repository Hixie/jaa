import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';

Color textColorForColor(Color color) => color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

String placementDescriptor(int rank) {
  if (rank > 3 && rank <= 20) {
    return '${rank}th';
  }
  if (rank % 10 == 1) {
    return '${rank}st';
  }
  if (rank % 10 == 2) {
    return '${rank}nd';
  }
  if (rank % 10 == 3) {
    return '${rank}rd';
  }
  return '${rank}th';
}

String count(int value, String singular, [String? plural]) {
  plural ??= '${singular}s';
  if (value == 1) {
    return '1 $singular';
  }
  return '$value $plural';
}

@immutable
class TripleIdentity<T, A, B, C> {
  const TripleIdentity(
    this.a,
    this.b,
    this.c,
  );

  final A a;
  final B b;
  final C c;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TripleIdentity<T, A, B, C> && other.a == a && other.b == b && other.c == c;
  }

  @override
  int get hashCode => Object.hash(a, b, c);
}

class SelectableButton<T> extends StatefulWidget {
  const SelectableButton({
    super.key,
    required this.value,
    required this.selection,
    required this.onChanged,
    required this.child,
  });

  final T value;
  final T selection;
  final ValueSetter<T>? onChanged;
  final Widget child;

  bool get selected => value == selection;

  @override
  State<SelectableButton<T>> createState() => _SelectableButtonState<T>();
}

class _SelectableButtonState<T> extends State<SelectableButton<T>> {
  late final WidgetStatesController statesController;

  @override
  void initState() {
    super.initState();
    statesController = WidgetStatesController(
      <WidgetState>{
        if (widget.selected) WidgetState.selected,
      },
    );
  }

  @override
  void didUpdateWidget(SelectableButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      statesController.update(WidgetState.selected, widget.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    late final TextButton result;
    result = TextButton(
      statesController: statesController,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).colorScheme.onPrimary;
            }
            return null; // defer to the defaults
          },
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).colorScheme.primary;
            }
            return null; // defer to the defaults
          },
        ),
      ),
      onPressed: widget.onChanged != null
          ? () {
              widget.onChanged!(widget.value);
            }
          : null,
      child: Builder(
        builder: (BuildContext context) {
          final TextStyle style = DefaultTextStyle.of(context).style;
          return DefaultTextStyle(
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: style.color,
            ),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            child: widget.child,
          );
        },
      ),
    );
    return result;
  }
}

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
  });

  final String label;
  final VoidCallback? onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(
          label,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class CheckboxRow extends StatelessWidget {
  const CheckboxRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
    required this.tristate,
    this.includePadding = true,
  });

  final String label;
  final bool? checked;
  final ValueSetter<bool?>? onChanged;
  final bool tristate;
  final bool includePadding;

  @override
  Widget build(BuildContext context) {
    final Widget result = MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            type: MaterialType.transparency,
            child: Checkbox(
              value: checked,
              tristate: tristate,
              onChanged: onChanged == null ? null : (bool? value) => onChanged!(value),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onChanged == null
                  ? null
                  : () {
                      if (tristate) {
                        onChanged!(switch (checked) {
                          true => null,
                          null => false,
                          false => true,
                        });
                      } else {
                        onChanged!(!checked!);
                      }
                    },
              child: Text(
                label,
                softWrap: true,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ],
      ),
    );
    if (includePadding) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
        child: result,
      );
    }
    return result;
  }
}

class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    required this.title,
    required this.headerButtonLabel,
    required this.onHeaderButtonPressed,
  });

  final String title;
  final String headerButtonLabel;
  final VoidCallback? onHeaderButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: indent),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: double.infinity), // makes Wrap as wide as container
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Heading(
              title: title,
              padding: const EdgeInsets.fromLTRB(indent, 0.0, 0.0, 0.0),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, spacing),
              child: FilledButton(
                onPressed: onHeaderButtonPressed,
                child: Text(
                  headerButtonLabel,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Heading extends StatelessWidget {
  const Heading({
    required this.title,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
  });

  final String title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24.0,
        ),
      ),
    );
  }
}

class ConditionalText extends StatelessWidget {
  const ConditionalText(
    this.message, {
    super.key,
    required this.active,
  });

  final String message;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.0,
      duration: animationDuration,
      curve: Curves.easeInOut,
      child: Text(message),
    );
  }
}

class _ForcedScrollbarScrollBehavior extends MaterialScrollBehavior {
  const _ForcedScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          child: child,
        );
      default:
        return super.buildScrollbar(context, child, details);
    }
  }
}

class HorizontalScrollbar extends StatelessWidget {
  const HorizontalScrollbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _ForcedScrollbarScrollBehavior(),
      child: child,
    );
  }
}

class ScrollableRegion extends StatelessWidget {
  const ScrollableRegion({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => HorizontalScrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minimumReasonableWidth,
              maxWidth: math.max(minimumReasonableWidth, constraints.maxWidth),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, 0.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class InlineScrollableCard extends StatelessWidget {
  const InlineScrollableCard({
    super.key,
    required this.children,
    required this.onClosed,
    this.toolbar,
  });

  final List<Widget> children;
  final VoidCallback onClosed;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: DefaultTextStyle.merge(
        softWrap: false, // Card resets this
        overflow: TextOverflow.ellipsis, // Card resets this
        child: HorizontalScrollbar(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: math.max(minimumReasonableWidth, constraints.maxWidth)),
                      child: Padding(
                        padding: const EdgeInsets.all(spacing * 2.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  children: [
                    ?toolbar,
                    IconButton(
                      onPressed: onClosed,
                      iconSize: DefaultTextStyle.of(context).style.fontSize,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({super.key, required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    switch (theme.platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return TextButton(onPressed: onPressed, child: child);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoDialogAction(onPressed: onPressed, child: child);
    }
  }
}

class DropdownList<T> extends StatelessWidget {
  const DropdownList({
    super.key,
    this.focusNode,
    required this.controller,
    required this.onSelected,
    required this.label,
    required this.values,
  });

  final FocusNode? focusNode;
  final TextEditingController controller;
  final ValueChanged<T?>? onSelected;
  final String label;
  final Map<T, String> values;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      focusNode: focusNode,
      controller: controller,
      onSelected: onSelected,
      requestFocusOnTap: true,
      enableFilter: true,
      menuStyle: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(
          Size(double.infinity, indent * 11.0),
        ),
      ),
      label: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      dropdownMenuEntries: values.keys.map<DropdownMenuEntry<T>>((T value) {
        return DropdownMenuEntry<T>(
          value: value,
          label: values[value]!,
        );
      }).toList(),
    );
  }
}

class ContinuousAnimationBuilder extends StatefulWidget {
  const ContinuousAnimationBuilder({
    super.key,
    required this.builder,
    this.min = 0.0,
    this.max = 1.0,
    this.reverse = false,
    required this.period,
    this.child,
  });

  final ValueWidgetBuilder<double> builder;
  final double min;
  final double max;
  final bool reverse;
  final Duration period;
  final Widget? child;

  @override
  State<ContinuousAnimationBuilder> createState() => _ContinuousAnimationBuilderState();
}

class _ContinuousAnimationBuilderState extends State<ContinuousAnimationBuilder> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant ContinuousAnimationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.min != widget.min || oldWidget.max != widget.max || oldWidget.reverse != widget.reverse || oldWidget.period != widget.period) {
      _restart();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _controller.repeat(min: widget.min, max: widget.max, reverse: widget.reverse, period: widget.period);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(valueListenable: _controller, builder: widget.builder, child: widget.child);
  }
}

class TriggerAnimation extends StatefulWidget {
  const TriggerAnimation({super.key, required this.trigger, required this.child});

  final ChangeNotifier trigger;
  final Widget child;

  @override
  State<TriggerAnimation> createState() => _TriggerAnimationState();
}

class _TriggerAnimationState extends State<TriggerAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 240),
    vsync: this,
  );

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.elasticIn,
  ).drive(Tween<double>(begin: 1.0, end: 1.02));

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_statusListener);
    widget.trigger.addListener(_trigger);
  }

  @override
  void didUpdateWidget(covariant TriggerAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_trigger);
      widget.trigger.addListener(_trigger);
    }
  }

  void _statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  void _trigger() {
    if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_trigger);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class VisitInput extends StatelessWidget {
  const VisitInput({
    super.key,
    this.min = 0,
    this.max = 99,
    this.highlightThreshold,
    required this.value,
    required this.onChanged,
  });

  final int min;
  final int max;
  final int? highlightThreshold;
  final int value;
  final ValueSetter<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (min == 0 && highlightThreshold == 1) {
      return Material(
        type: MaterialType.transparency,
        child: Checkbox(
          value: value >= 1,
          onChanged: (bool? value) {
            onChanged(value! ? 1 : 0);
          },
        ),
      );
    }
    final double size = DefaultTextStyle.of(context).style.fontSize!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacing / 2.0),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: size * 1.5,
            height: size * 1.5,
            child: IconButton(
              iconSize: DefaultTextStyle.of(context).style.fontSize,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: Ink(
                decoration: const ShapeDecoration(
                  color: Color(0x10000000),
                  shape: CircleBorder(),
                ),
                child: Icon(Icons.remove),
              ),
              onPressed: value <= min
                  ? null
                  : () {
                      onChanged((value - 1).clamp(min, max));
                    },
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (highlightThreshold != null && value >= highlightThreshold!)
                Positioned(
                  top: 0,
                  right: -size / 3.0,
                  child: IgnoreBaseline(
                    child: Icon(
                      size: size / 1.5,
                      color: Theme.of(context).colorScheme.onPrimaryFixedVariant.withValues(alpha: 0.75),
                      Icons.check,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spacing / 2.0),
                child: Opacity(
                  opacity: 0.0,
                  child: Text('9' * ('${highlightThreshold ?? max}'.length)),
                ),
              ),
              Positioned.fill(
                child: Text('$value', textAlign: TextAlign.center),
              ),
            ],
          ),
          SizedBox(
            width: size * 1.5,
            height: size * 1.5,
            child: IconButton(
              iconSize: size,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: Ink(
                decoration: const ShapeDecoration(
                  color: Color(0x10000000),
                  shape: CircleBorder(),
                ),
                child: Icon(Icons.add),
              ),
              onPressed: value >= max
                  ? null
                  : () {
                      onChanged((value + 1).clamp(min, max));
                    },
            ),
          ),
        ],
      ),
    );
  }
}
