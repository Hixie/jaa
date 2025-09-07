import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../utils/constants.dart';
import '../utils/io.dart';
import '../model/competition.dart';
import '../widgets/awards.dart';
import '../widgets/cells.dart';
import '../widgets/selectors.dart';
import '../widgets/widgets.dart';

class InspirePane extends StatefulWidget {
  const InspirePane({super.key, required this.competition});

  final Competition competition;

  @override
  State<InspirePane> createState() => _InspirePaneState();

  static Future<void> exportInspireHTML(BuildContext context, Competition competition) async {
    final DateTime now = DateTime.now();
    StringBuffer page = createHtmlPage(competition, 'Inspire', now);
    final Map<int, Map<Team, Set<String>>> candidates = competition.computeInspireCandidates();
    final List<String> categories = competition.inspireCategories;

    if (categories.isEmpty) {
      page.writeln('<p>No team qualify for the Inspire award.');
    } else {
      for (final int categoryCount in (candidates.keys.toList()..sort()).reversed) {
        page.writeln('<h2>Candidates in $categoryCount categories</h2>');
        page.writeln('<table>');
        page.writeln('<thead>');
        page.writeln('<tr>');
        page.writeln('<th>Team');
        for (final String category in categories) {
          page.writeln('<th>${escapeHtml(category)}');
        }
        page.writeln('<th>Rank Score');
        page.writeln('<th>Rank Count');
        page.writeln('<th>Inspire Placement');
        page.writeln('<tbody>');
        for (final Team team in candidates[categoryCount]!.keys.toList()..sort(Team.inspireCandidateComparator)) {
          page.writeln('<tr>');
          page.writeln('<td>${team.number} <i>${escapeHtml(team.name)}</i>');
          for (final String category in categories) {
            page.writeln('<td>${escapeHtml(team.bestInspireContributingRankFor(category, 'unranked', ''))}');
          }
          page.writeln('<td>${team.rankScore ?? ""}');
          page.writeln('<td>${team.rankedCount}');
          switch (team.inspireStatus) {
            case InspireStatus.eligible:
            case InspireStatus.hidden:
              page.writeln('<td>${team.shortlistsView[competition.inspireAward!]?.rank ?? "<i>Not placed</i>"}');
            case InspireStatus.ineligible:
              page.writeln('<td><i>Not eligible</i>');
            case InspireStatus.exhibition:
              page.writeln('<td><i>Not competing</i>');
          }
        }
        page.writeln('</table>');
      }
    }
    return exportHTML(competition, 'inspire', now, page.toString());
  }
}

class _InspirePaneState extends State<InspirePane> {
  final Set<Team> _legacyTeams = <Team>{};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.competition,
      builder: (BuildContext context, Widget? child) {
        final Map<int, Map<Team, Set<String>>> candidates = widget.competition.computeInspireCandidates();
        final List<String> categories = widget.competition.inspireCategories;
        final List<int> categoryCounts = (candidates.keys.toList()..sort()).reversed.take(widget.competition.minimumInspireCategories).toList();
        final canShowAnything = widget.competition.teamsView.isNotEmpty && (widget.competition.inspireAward != null) && categoryCounts.isNotEmpty;
        final List<Award> awards = canShowAnything && widget.competition.expandInspireTable
            ? (widget.competition.awardsView.where(Award.isInspireQualifyingPredicate).toList()..sort(widget.competition.awardSorter))
            : const [];
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Heading(title: '5. Inspire'),
            if (widget.competition.teamsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No teams loaded. Use the Setup pane to import a teams list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (widget.competition.awardsView.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No awards loaded. Use the Setup pane to import an awards list.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (widget.competition.inspireAward == null)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No Inspire award defined. Use the Setup pane to import an awards list with an Inspire award.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(indent, spacing, indent, indent),
                child: Text(
                  'No teams shortlisted for sufficient advancing award categories. Use the Shortlists pane to nominate teams.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              )
            else if (categoryCounts.first < categories.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'No teams are shortlisted for ${categories.length == 2 ? 'both' : 'all ${categories.length}'} categories.',
                  softWrap: true,
                  overflow: TextOverflow.clip,
                ),
              ),
            if (canShowAnything)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, indent, indent, spacing),
                child: Text('Candidates for ${widget.competition.inspireAward!.name} award:', style: bold),
              ),
            if (canShowAnything)
              CheckboxRow(
                checked: widget.competition.expandInspireTable,
                onChanged: (bool? value) {
                  widget.competition.expandInspireTable = value!;
                  setState(() {
                    _legacyTeams.clear();
                  });
                },
                tristate: false,
                label: 'Show rankings for all awards in addition to categories.',
              ),
            if (canShowAnything)
              CheckboxRow(
                checked: widget.competition.hideInspireHiddenTeams
                    ? _legacyTeams.isEmpty
                        ? false
                        : null
                    : true,
                onChanged: (bool? value) {
                  widget.competition.hideInspireHiddenTeams = !value!;
                  setState(() {
                    _legacyTeams.clear();
                  });
                },
                tristate: widget.competition.hideInspireHiddenTeams && _legacyTeams.isNotEmpty,
                label: 'Include ineligible teams and teams marked as hidden.',
              ),
            if (canShowAnything)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: TeamOrderSelector(
                  value: widget.competition.inspireSortOrder,
                  onChange: (TeamComparatorCallback newValue) {
                    widget.competition.inspireSortOrder = newValue;
                  },
                ),
              ),
            if (widget.competition.inspireAward != null) const SizedBox(height: indent),
            if (widget.competition.inspireAward != null)
              for (final int categoryCount in categoryCounts)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, indent),
                  child: HorizontalScrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(indent, 0.0, indent, indent),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Candidates in $categoryCount categories'
                              '${categoryCount < widget.competition.minimumInspireCategories ? " (insufficient to qualify for ${widget.competition.inspireAward!.name} award)" : ""}:',
                            ),
                            const SizedBox(height: spacing),
                            Builder(builder: (context) {
                              final List<Team> teams = candidates[categoryCount]!.keys.toList()..sort(widget.competition.inspireSortOrder);
                              if (widget.competition.hideInspireHiddenTeams) {
                                teams.removeWhere((Team team) => !_legacyTeams.contains(team) && (team.inspireStatus != InspireStatus.eligible || (widget.competition.inspireAward!.needsPortfolio && !team.hasPortfolio)));
                              }
                              if (teams.isEmpty) {
                                return const Text('All eligible teams are hidden.');
                              }
                              return Table(
                                border: awards.isEmpty
                                    ? const TableBorder.symmetric(
                                        inside: BorderSide(),
                                      )
                                    : SkipColumnTableBorder.symmetric(
                                        inside: const BorderSide(),
                                        skippedColumn: 1 + categories.length + 3 + (categoryCount >= widget.competition.minimumInspireCategories ? 1 : 0),
                                      ),
                                defaultColumnWidth: const IntrinsicCellWidth(),
                                columnWidths: {
                                  if (awards.isNotEmpty)
                                    1 + categories.length + 3 + (categoryCount >= widget.competition.minimumInspireCategories ? 1 : 0):
                                        const FixedColumnWidth(indent * 2.0),
                                },
                                defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  TableRow(
                                    children: [
                                      Cell(
                                        Text('#', style: bold),
                                        prototype: Text('${widget.competition.teamsView.last.number} WW'), // longest team number plus icon(s)
                                        highlight: widget.competition.inspireSortOrder == Team.teamNumberComparator,
                                      ),
                                      for (final String category in categories)
                                        Cell(
                                          Text(category, style: bold),
                                          prototype: const Text('unranked'),
                                        ),
                                      Cell(Text('Rank Score', style: bold),
                                          prototype: Text('000'), highlight: widget.competition.inspireSortOrder == Team.inspireCandidateComparator),
                                      Cell(Text('Rank Count', style: bold),
                                          prototype: Text('000'), highlight: widget.competition.inspireSortOrder == Team.rankedCountComparator),
                                      if (categoryCount >= widget.competition.minimumInspireCategories)
                                        const Cell(Text('Inspire Placement ✎_', style: bold), prototype: Text('Not eligible WW')), // WW represents the icon(s)
                                      const Cell(Text('Hide?', style: bold), prototype: SizedBox(width: kMinInteractiveDimension)),
                                      if (awards.isNotEmpty) const SizedBox.shrink(),
                                      for (final Award award in awards)
                                        ListenableBuilder(
                                          listenable: award,
                                          builder: (BuildContext context, Widget? child) {
                                            final Color foregroundColor = textColorForColor(award.color);
                                            return ColoredBox(
                                              color: award.color,
                                              child: Cell(
                                                Row(
                                                  children: [
                                                    Text(
                                                      award.name,
                                                      style: bold.copyWith(
                                                        color: textColorForColor(award.color),
                                                      ),
                                                    ),
                                                    if (award.comment != '')
                                                      Padding(
                                                        padding: const EdgeInsetsDirectional.only(start: spacing),
                                                        child: Tooltip(
                                                          message: award.comment,
                                                          child: Icon(
                                                            Symbols.emoji_objects,
                                                            size: DefaultTextStyle.of(context).style.fontSize,
                                                            color: foregroundColor,
                                                          ),
                                                        ),
                                                      )
                                                  ],
                                                ),
                                                prototype: const Text('0000 XX'),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                  for (final Team team in teams)
                                    TableRow(
                                      decoration:
                                          widget.competition.hideInspireHiddenTeams && team.inspireStatus == InspireStatus.hidden && _legacyTeams.contains(team)
                                              ? BoxDecoration(color: Colors.grey.shade100)
                                              : null,
                                      children: [
                                        Tooltip(
                                          message: team.name,
                                          child: Cell(Text('${team.number}')),
                                        ),
                                        for (final String category in categories) Cell(Text(team.bestInspireContributingRankFor(category, 'unranked', ''))),
                                        Cell(Text('${team.rankScore ?? ""}')),
                                        Cell(Text('${team.rankedCount}')),
                                        if (categoryCount >= widget.competition.minimumInspireCategories)
                                          if ((team.inspireStatus == InspireStatus.ineligible) ||
                                              (team.inspireStatus == InspireStatus.exhibition) ||
                                              (widget.competition.inspireAward!.needsPortfolio && !team.hasPortfolio))
                                            Cell(
                                              Text('Not eligible'),
                                              icons: [
                                                if (team.inspireStatus == InspireStatus.ineligible)
                                                  Tooltip(
                                                    message: 'Team has already won the Inspire award this season!',
                                                    child: Icon(
                                                      Symbols.social_leaderboard, // medal
                                                      size: DefaultTextStyle.of(context).style.fontSize,
                                                    ),
                                                  ),
                                                if (team.inspireStatus == InspireStatus.exhibition)
                                                  Tooltip(
                                                    message: 'Team is an exhibition team and is not eligible for any awards!',
                                                    child: Icon(
                                                      Symbols.cruelty_free, // bunny
                                                      size: DefaultTextStyle.of(context).style.fontSize,
                                                    ),
                                                  ),
                                                if (widget.competition.inspireAward!.needsPortfolio && !team.hasPortfolio)
                                                  Tooltip(
                                                    message: 'Team is missing a portfolio!',
                                                    child: Icon(
                                                      Symbols.content_paste_off, // clipboard crossed out
                                                      size: DefaultTextStyle.of(context).style.fontSize,
                                                    ),
                                                  ),
                                              ],
                                            )
                                          else
                                            InspirePlacementCell(
                                              competition: widget.competition,
                                              team: team,
                                              award: widget.competition.inspireAward!,
                                            ),
                                        TableCell(
                                          verticalAlignment: TableCellVerticalAlignment.fill,
                                          child: Material(
                                            type: MaterialType.transparency,
                                            child: Checkbox(
                                              key: ValueKey<Team>(team),
                                              value: (team.inspireStatus != InspireStatus.eligible) ||
                                                    (widget.competition.inspireAward!.needsPortfolio && !team.hasPortfolio),
                                              onChanged: (team.inspireStatus == InspireStatus.ineligible) ||
                                                         (team.inspireStatus == InspireStatus.exhibition) ||
                                                         (widget.competition.inspireAward!.needsPortfolio && !team.hasPortfolio)
                                                  ? null
                                                  : (bool? value) {
                                                      value!;
                                                      if (value) {
                                                        _legacyTeams.add(team);
                                                      }
                                                      widget.competition.updateTeamInspireStatus(
                                                        team,
                                                        status: value ? InspireStatus.hidden : InspireStatus.eligible,
                                                      );
                                                    },
                                            ),
                                          ),
                                        ),
                                        if (awards.isNotEmpty) const SizedBox.shrink(),
                                        for (final Award award in awards)
                                          RankCell(
                                            entry: widget.competition.shortlistsView[award]!.entriesView[team],
                                          ),
                                      ],
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            if (canShowAnything)
              Padding(
                padding: const EdgeInsets.fromLTRB(indent, spacing, indent, spacing),
                child: Text(
                  'Rank Score: Sum of the highest rank in each shortlisted category (if they are all ranked); lower is better.\n'
                  'Rank Count: Number of categories in which the team is ranked in one or more awards; higher is better.',
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            if (awards.isNotEmpty)
              AwardOrderSwitch(
                competition: widget.competition,
              ),
          ],
        );
      },
    );
  }
}

class RankCell extends StatelessWidget {
  const RankCell({
    super.key,
    required this.entry,
  });

  final ShortlistEntry? entry;

  @override
  Widget build(BuildContext context) {
    return Cell(
      Row(
        children: [
          Expanded(
            child: Text(
              entry == null
                  ? ''
                  : entry!.rank != null
                      ? '${entry!.rank}'
                      : bullet,
            ),
          ),
          if (entry != null && entry!.nominator.isNotEmpty)
            Tooltip(
              message: entry!.nominator,
              child: Icon(
                Symbols.people,
                size: DefaultTextStyle.of(context).style.fontSize,
              ),
            ),
          if (entry != null && entry!.comment.isNotEmpty)
            Tooltip(
              message: entry!.comment,
              child: Icon(
                Symbols.mark_unread_chat_alt,
                size: DefaultTextStyle.of(context).style.fontSize,
              ),
            ),
        ],
      ),
    );
  }
}

class InspirePlacementCell extends StatefulWidget {
  InspirePlacementCell({
    required this.competition,
    required this.team,
    required this.award,
  }) : super(key: ValueKey(TripleIdentity<InspirePlacementCell, Competition, Award, Team>(competition, award, team)));

  final Competition competition;
  final Team team;
  final Award award;

  @override
  State<InspirePlacementCell> createState() => _InspirePlacementCellState();
}

class _InspirePlacementCellState extends State<InspirePlacementCell> {
  final TextEditingController _controller = TextEditingController();
  ShortlistEntry? _entry;
  bool _error = false;

  String _placementAsString() {
    if (_entry == null) {
      return '';
    }
    if (_entry!.rank == null) {
      return '';
    }
    return '${_entry!.rank!}';
  }

  @override
  void initState() {
    super.initState();
    widget.competition.addListener(_updateError);
    widget.team.addListener(_handleTeamUpdate);
    _handleTeamUpdate();
    _controller.addListener(_handleTextFieldUpdate);
    _controller.text = _placementAsString();
    _updateError();
  }

  @override
  void didUpdateWidget(InspirePlacementCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.competition == oldWidget.competition);
    assert(widget.team == oldWidget.team);
    assert(widget.award == oldWidget.award);
    _updateError();
  }

  @override
  void dispose() {
    _entry?.removeListener(_handleEntryUpdate);
    widget.team.removeListener(_handleTeamUpdate);
    widget.competition.removeListener(_updateError);
    _controller.dispose();
    super.dispose();
  }

  void _updateError() {
    setState(() {
      _error = _entry == null || _entry!.rank == null || _entry!.rank! <= 0 || _entry!.rank! > widget.competition.teamsView.length;
    });
  }

  void _handleTeamUpdate() {
    setState(() {
      if (_entry == null) {
        _entry = widget.team.shortlistsView[widget.award];
        _entry?.addListener(_handleEntryUpdate);
      } else {
        if (!widget.team.shortlistsView.containsKey(widget.award)) {
          _entry!.removeListener(_handleTeamUpdate);
          _entry = null;
        }
      }
      _handleEntryUpdate();
    });
  }

  void _handleTextFieldUpdate() {
    if (_controller.text == '') {
      if (_entry != null) {
        widget.competition.removeFromShortlist(widget.award, widget.team);
      }
    } else {
      if (_entry == null) {
        widget.competition.addToShortlist(widget.award, widget.team, ShortlistEntry(lateEntry: false, rank: int.parse(_controller.text)));
        assert(_entry != null); // set by _handleTeamUpdate
      } else {
        widget.competition.updateShortlistRank(widget.award, widget.team, int.parse(_controller.text));
      }
    }
  }

  void _handleEntryUpdate() {
    final String newValue = _placementAsString();
    if (_controller.text != newValue) {
      _controller.text = newValue;
    }
    _updateError();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = DefaultTextStyle.of(context).style;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: spacing),
        child: SizedBox(
          width: DefaultTextStyle.of(context).style.fontSize! * 4.0,
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration.collapsed(
              hintText: 'Not placed',
              hintStyle: TextStyle(
                fontStyle: FontStyle.italic,
              ),
            ),
            style: _error
                ? textStyle.copyWith(
                    color: Colors.red,
                    shadows: const [Shadow(color: Colors.white, blurRadius: 3.0)],
                  )
                : textStyle,
            cursorColor: textStyle.color,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            keyboardType: TextInputType.number,
          ),
        ),
      ),
    );
  }
}

/// Border specification for [Table] widgets, with a missing column.
///
/// This is like [TableBorder], but the horizontal lines skip one of
/// the columns, the [skippedColumn].
@immutable
class SkipColumnTableBorder implements TableBorder {
  /// Creates a border for a table.
  ///
  /// All the sides of the border default to [BorderSide.none].
  const SkipColumnTableBorder({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
    this.horizontalInside = BorderSide.none,
    this.verticalInside = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
    required this.skippedColumn,
  });

  /// A uniform border with all sides the same color and width.
  ///
  /// The sides default to black solid borders, one logical pixel wide.
  factory SkipColumnTableBorder.all({
    Color color = const Color(0xFF000000),
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
    BorderRadius borderRadius = BorderRadius.zero,
    required int skippedColumn,
  }) {
    final BorderSide side = BorderSide(color: color, width: width, style: style);
    return SkipColumnTableBorder(
      top: side,
      right: side,
      bottom: side,
      left: side,
      horizontalInside: side,
      verticalInside: side,
      borderRadius: borderRadius,
      skippedColumn: skippedColumn,
    );
  }

  /// Creates a border for a table where all the interior sides use the same
  /// styling and all the exterior sides use the same styling.
  const SkipColumnTableBorder.symmetric({
    BorderSide inside = BorderSide.none,
    BorderSide outside = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
    required this.skippedColumn,
  })  : top = outside,
        right = outside,
        bottom = outside,
        left = outside,
        horizontalInside = inside,
        verticalInside = inside;

  /// The top side of this border.
  @override
  final BorderSide top;

  /// The right side of this border.
  @override
  final BorderSide right;

  /// The bottom side of this border.
  @override
  final BorderSide bottom;

  /// The left side of this border.
  @override
  final BorderSide left;

  /// The horizontal interior sides of this border.
  @override
  final BorderSide horizontalInside;

  /// The vertical interior sides of this border.
  @override
  final BorderSide verticalInside;

  /// The [BorderRadius] to use when painting the corners of this border.
  ///
  /// It is also applied to [DataTable]'s [Material].
  @override
  final BorderRadius borderRadius;

  /// The index of the column that the horizontal rows are to skip.
  final int skippedColumn;

  /// The widths of the sides of this border represented as an [EdgeInsets].
  ///
  /// This can be used, for example, with a [Padding] widget to inset a box by
  /// the size of these borders.
  @override
  EdgeInsets get dimensions {
    return EdgeInsets.fromLTRB(left.width, top.width, right.width, bottom.width);
  }

  /// Whether all the sides of the border (outside and inside) are identical.
  /// Uniform borders are typically more efficient to paint.
  ///
  /// For [SkipColumnTableBorder], this is always false, because of the [skippedColumn].
  @override
  bool get isUniform => false;

  /// Creates a copy of this border but with the widths scaled by the factor `t`.
  ///
  /// The `t` argument represents the multiplicand, or the position on the
  /// timeline for an interpolation from nothing to `this`, with 0.0 meaning
  /// that the object returned should be the nil variant of this object, 1.0
  /// meaning that no change should be applied, returning `this` (or something
  /// equivalent to `this`), and other values meaning that the object should be
  /// multiplied by `t`. Negative values are treated like zero.
  ///
  /// Values for `t` are usually obtained from an [Animation<double>], such as
  /// an [AnimationController].
  ///
  /// The [skippedColumn] is not scaled.
  ///
  /// See also:
  ///
  ///  * [BorderSide.scale], which is used to implement this method.
  @override
  SkipColumnTableBorder scale(double t) {
    return SkipColumnTableBorder(
      top: top.scale(t),
      right: right.scale(t),
      bottom: bottom.scale(t),
      left: left.scale(t),
      horizontalInside: horizontalInside.scale(t),
      verticalInside: verticalInside.scale(t),
      skippedColumn: skippedColumn,
    );
  }

  /// Linearly interpolate between two table borders.
  ///
  /// If a border is null, it is treated as having only [BorderSide.none]
  /// borders.
  ///
  /// If the [skippedColumn] is not identical in the two inputs, it is interpolated
  /// discretely, which will typically not result in a pretty rendering.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static SkipColumnTableBorder? lerp(SkipColumnTableBorder? a, SkipColumnTableBorder? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    return SkipColumnTableBorder(
      top: BorderSide.lerp(a.top, b.top, t),
      right: BorderSide.lerp(a.right, b.right, t),
      bottom: BorderSide.lerp(a.bottom, b.bottom, t),
      left: BorderSide.lerp(a.left, b.left, t),
      horizontalInside: BorderSide.lerp(a.horizontalInside, b.horizontalInside, t),
      verticalInside: BorderSide.lerp(a.verticalInside, b.verticalInside, t),
      skippedColumn: lerpDouble(a.skippedColumn, b.skippedColumn, t)!.round(),
    );
  }

  /// Paints the border around the given [Rect] on the given [Canvas], with the
  /// given rows and columns.
  ///
  /// The `rows` argument specifies the vertical positions between the rows,
  /// relative to the given rectangle. For example, if the table contained two
  /// rows of height 100.0 each, then `rows` would contain a single value,
  /// 100.0, which is the vertical position between the two rows (relative to
  /// the top edge of `rect`).
  ///
  /// The `columns` argument specifies the horizontal positions between the
  /// columns, relative to the given rectangle. For example, if the table
  /// contained two columns of width 100.0 each, then `columns` would contain a
  /// single value, 100.0, which is the horizontal position between the two
  /// columns (relative to the left edge of `rect`).
  ///
  /// The [verticalInside] border is only drawn if there are at least two
  /// columns. The [horizontalInside] border is only drawn if there are at least
  /// two rows. The horizontal borders are drawn after the vertical borders.
  ///
  /// The horizontal lines skip over the [skippedColumn].
  ///
  /// The outer borders (in the order [top], [right], [bottom], [left], with
  /// [left] above the others) are painted after the inner borders.
  ///
  /// The paint order is particularly notable in the case of
  /// partially-transparent borders.
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    required Iterable<double> rows,
    required Iterable<double> columns,
  }) {
    final List<double> theColumns = columns.toList();
    assert(rows.isEmpty || (rows.first >= 0.0 && rows.last <= rect.height));
    assert(theColumns.isEmpty || (theColumns.first >= 0.0 && theColumns.last <= rect.width));

    if (theColumns.isNotEmpty || rows.isNotEmpty) {
      final Paint paint = Paint();
      final Path path = Path();

      if (theColumns.isNotEmpty) {
        switch (verticalInside.style) {
          case BorderStyle.solid:
            paint
              ..color = verticalInside.color
              ..strokeWidth = verticalInside.width
              ..style = PaintingStyle.stroke;
            path.reset();
            for (int index = 0; index < theColumns.length; index += 1) {
              if (index != skippedColumn - 1 && index != skippedColumn) {
                final double x = theColumns[index];
                path.moveTo(rect.left + x, rect.top);
                path.lineTo(rect.left + x, rect.bottom);
              }
            }
            canvas.drawPath(path, paint);
          case BorderStyle.none:
            break;
        }
      }

      if (rows.isNotEmpty) {
        switch (horizontalInside.style) {
          case BorderStyle.solid:
            paint
              ..color = horizontalInside.color
              ..strokeWidth = horizontalInside.width
              ..style = PaintingStyle.stroke;
            path.reset();
            if (skippedColumn > 0) {
              final double right = skippedColumn > theColumns.length ? rect.right - rect.left : theColumns[skippedColumn - 1];
              for (final double y in rows) {
                path.moveTo(rect.left, rect.top + y);
                path.lineTo(rect.left + right, rect.top + y);
              }
            }
            if (skippedColumn < theColumns.length) {
              final double left = theColumns[skippedColumn];
              for (final double y in rows) {
                path.moveTo(rect.left + left, rect.top + y);
                path.lineTo(rect.right, rect.top + y);
              }
            }
            canvas.drawPath(path, paint);
          case BorderStyle.none:
            break;
        }
      }
    }
    if (!isUniform || borderRadius == BorderRadius.zero) {
      paintBorder(canvas, rect, top: top, right: right, bottom: bottom, left: left);
    } else {
      final RRect outer = borderRadius.toRRect(rect);
      final RRect inner = outer.deflate(top.width);
      final Paint paint = Paint()..color = top.color;
      canvas.drawDRRect(outer, inner, paint);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SkipColumnTableBorder &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.left == left &&
        other.horizontalInside == horizontalInside &&
        other.verticalInside == verticalInside &&
        other.borderRadius == borderRadius &&
        other.skippedColumn == skippedColumn;
  }

  @override
  int get hashCode => Object.hash(top, right, bottom, left, horizontalInside, verticalInside, borderRadius, skippedColumn);

  @override
  String toString() => 'SkipColumnTableBorder($top, $right, $bottom, $left, $horizontalInside, $verticalInside, $borderRadius, $skippedColumn)';
}
