import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/competition.dart';
import '../utils/constants.dart';

class Cell extends StatelessWidget {
  const Cell(
    this.child, {
    super.key,
    this.prototype,
    this.padPrototype = true,
  });

  final Widget child;
  final Widget? prototype;
  final bool padPrototype;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    if (!padPrototype) {
      result = Padding(
        padding: const EdgeInsets.all(spacing),
        child: result,
      );
    }
    if (prototype != null) {
      result = Stack(
        children: [
          Opacity(
            opacity: 0.0,
            child: prototype!,
          ),
          result,
        ],
      );
    }
    if (padPrototype) {
      result = Padding(
        padding: const EdgeInsets.all(spacing),
        child: result,
      );
    }
    return result;
  }
}

@immutable
class _CompetitionTeamIdentity {
  const _CompetitionTeamIdentity(
    this.competition,
    this.team,
  );

  final Competition competition;
  final Team team;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _CompetitionTeamIdentity && other.competition == competition && other.team == team;
  }

  @override
  int get hashCode => Object.hash(competition, team);
}

class VisitedCell extends StatefulWidget {
  VisitedCell({
    required this.team,
    required this.competition,
    this.label,
    this.onVisitedChanged,
  }) : super(key: ValueKey(_CompetitionTeamIdentity(competition, team)));

  final Team team;
  final Competition competition;
  final ValueSetter<Team>? onVisitedChanged;
  final Widget? label;

  @override
  State<VisitedCell> createState() => _VisitedCellState();
}

class _VisitedCellState extends State<VisitedCell> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.competition.addListener(_handleTeamUpdate);
    widget.team.addListener(_handleTeamUpdate);
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = widget.team.visitingJudgesNotes;
  }

  @override
  void didUpdateWidget(VisitedCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.competition == oldWidget.competition);
    assert(widget.team == oldWidget.team);
  }

  @override
  void dispose() {
    widget.team.removeListener(_handleTeamUpdate);
    widget.competition.removeListener(_handleTeamUpdate);
    super.dispose();
  }

  void _handleTeamUpdate() {
    setState(() {
      if (_controller.text != widget.team.visitingJudgesNotes) {
        _controller.text = widget.team.visitingJudgesNotes;
      }
      // also team.visited may have changed
    });
  }

  void _handleTextFieldUpdate() {
    widget.team.visitingJudgesNotes = _controller.text;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) widget.label!,
        Material(
          type: MaterialType.transparency,
          child: Checkbox(
            value: widget.team.visited,
            onChanged: (bool? value) {
              widget.competition.updateTeamVisited(widget.team, visited: value!);
              widget.onVisitedChanged?.call(widget.team);
            },
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: DefaultTextStyle.of(context).style.fontSize! * 15.0,
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration.collapsed(
                hintText: 'no judging team assigned',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                ),
              ),
              style: DefaultTextStyle.of(context).style,
            ),
          ),
        ),
      ],
    );
  }
}

class TextEntryCell extends StatefulWidget {
  const TextEntryCell({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'none',
    this.icons,
  });

  final String value;
  final ValueSetter<String> onChanged;
  final String hintText;
  final List<Widget>? icons;

  @override
  State<TextEntryCell> createState() => _TextEntryCellState();
}

class _TextEntryCellState extends State<TextEntryCell> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = widget.value;
  }

  @override
  void didUpdateWidget(TextEntryCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTextFieldUpdate() {
    if (_controller.text != widget.value) {
      widget.onChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = DefaultTextStyle.of(context).style;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacing),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: DefaultTextStyle.of(context).style.fontSize! * 4.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration.collapsed(
                  hintText: widget.hintText,
                  hintStyle: textStyle.copyWith(fontStyle: FontStyle.italic),
                ),
                style: textStyle,
                cursorColor: textStyle.color,
              ),
            ),
            ...?widget.icons,
          ],
        ),
      ),
    );
  }
}

/// Sizes the column according to the intrinsic dimensions of the
/// cell in the specified row of the relevant column.
///
/// The row is specified using [row].
///
/// This is an expensive way to size a column, compared to
/// [FixedColumnWidth], [FlexColumnWidth], or [FractionColumnWidth],
/// but is much cheaper than [IntrinsicColumnWidth] when the table has
/// a lot of rows.
///
/// A flex value can be provided. If specified (and non-null), the
/// column will participate in the distribution of remaining space
/// once all the non-flexible columns have been sized.
class IntrinsicCellWidth extends TableColumnWidth {
  /// Creates a column width based on intrinsic sizing of the column's cell in
  /// the specified [row] (which defaults to the first row, with index 0).
  ///
  /// The `flex` argument specifies the flex factor to apply to the column if
  /// there is any room left over when laying out the table. If `flex` is
  /// null (the default), the table will not distribute any extra space to the
  /// column.
  const IntrinsicCellWidth({this.row = 0, double? flex}) : _flex = flex;

  /// The row from which to obtain the cell to measure.
  ///
  /// If the table does not have enough rows, then the cell is assumed to
  /// have be of zero width.
  final int row;

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    if (cells.length >= row) {
      result = math.max(result, cells.skip(row).first.getMinIntrinsicWidth(double.infinity));
    }
    return result;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    if (cells.length >= row) {
      result = math.max(result, cells.skip(row).first.getMaxIntrinsicWidth(double.infinity));
    }
    return result;
  }

  final double? _flex;

  @override
  double? flex(Iterable<RenderBox> cells) => _flex;

  @override
  String toString() => '${objectRuntimeType(this, 'IntrinsicCellWidth')}(flex: ${_flex?.toStringAsFixed(1)})';
}
