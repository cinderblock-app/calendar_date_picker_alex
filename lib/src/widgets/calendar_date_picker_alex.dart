// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:calendar_date_picker_alex/calendar_date_picker_alex.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:jiffy/jiffy.dart';

part '_impl/_calendar_view.dart';

part '_impl/_date_picker_mode_toggle_button.dart';

part '_impl/_day_picker.dart';

part '_impl/_focus_date.dart';

part '_impl/_month_picker.dart';

part '_impl/year_picker.dart';

const Duration _monthScrollDuration = Duration(milliseconds: 200);
const int _yearPickerColumnCount = 3;
const double _yearPickerPadding = 16.0;
const double _yearPickerRowHeight = 52.0;
const double _yearPickerRowSpacing = 8.0;

const int _monthPickerColumnCount = 3;
const double _monthPickerPadding = 16.0;
const double _monthPickerRowHeight = 52.0;
const double _monthPickerRowSpacing = 8.0;

const double _subHeaderHeight = 52.0;
const double _monthNavButtonsWidth = 108.0;

class CalendarDatePickerAlex extends StatefulWidget {
  CalendarDatePickerAlex({
    required this.config,
    required this.value,
    this.onValueChanged,
    this.displayedMonthDate,
    this.onDisplayedMonthChanged,
    Key? key,
  }) : super(key: key) {
    const valid = true;
    const invalid = false;

    if (config.calendarType == CalendarDatePickerAlexType.single) {
      assert(value.length < 2,
          'Error: single date picker only allows maximum one initial date');
    }

    if (config.calendarType == CalendarDatePickerAlexType.range &&
        value.length > 1) {
      final isRangePickerValueValid = value[0] == null
          ? (value[1] != null ? invalid : valid)
          : (value[1] != null
              ? (value[1]!.isBefore(value[0]!) ? invalid : valid)
              : valid);

      assert(
        isRangePickerValueValid,
        'Error: range date picker must has start date set before setting end date, and start date must before end date.',
      );
    }
  }

  /// The calendar UI related configurations
  final CalendarDatePickerAlexConfig config;

  /// The selected [DateTime]s that the picker should display.
  final List<DateTime?> value;

  /// Called when the selected dates changed
  final ValueChanged<List<DateTime?>>? onValueChanged;

  /// Date to control calendar displayed month
  final DateTime? displayedMonthDate;

  /// Called when the displayed month changed
  final ValueChanged<DateTime>? onDisplayedMonthChanged;

  @override
  State<CalendarDatePickerAlex> createState() => _CalendarDatePickerAlexState();
}

class _CalendarDatePickerAlexState extends State<CalendarDatePickerAlex> {
  bool _announcedInitialDate = false;
  late List<DateTime?> _selectedDates;
  late CalendarDatePickerAlexMode _mode;
  late DateTime _currentDisplayedMonthDate;
  final GlobalKey _dayPickerKey = GlobalKey();
  final GlobalKey _monthPickerKey = GlobalKey();
  final GlobalKey _yearPickerKey = GlobalKey();
  late MaterialLocalizations _localizations;
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    final initialDate = widget.displayedMonthDate ??
        (widget.value.isNotEmpty && widget.value[0] != null
            ? DateTime(widget.value[0]!.year, widget.value[0]!.month)
            : DateUtils.dateOnly(DateTime.now()));
    _mode = config.calendarViewMode;
    _currentDisplayedMonthDate = DateTime(initialDate.year, initialDate.month);
    _selectedDates = widget.value.toList();
  }

  @override
  void didUpdateWidget(CalendarDatePickerAlex oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.calendarViewMode != oldWidget.config.calendarViewMode) {
      _mode = widget.config.calendarViewMode;
    }

    if (widget.displayedMonthDate != null) {
      _currentDisplayedMonthDate = DateTime(
        widget.displayedMonthDate!.year,
        widget.displayedMonthDate!.month,
      );
    }

    _selectedDates = widget.value.toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    _localizations = MaterialLocalizations.of(context);
    _textDirection = Directionality.of(context);
    if (!_announcedInitialDate && _selectedDates.isNotEmpty) {
      _announcedInitialDate = true;
      for (final date in _selectedDates) {
        if (date != null) {
          SemanticsService.announce(
            _localizations.formatFullDate(date),
            _textDirection,
          );
        }
      }
    }
  }

  void _vibrate() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        HapticFeedback.vibrate();
        break;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
    }
  }

  // Commented because not used atm
  // void _handleModeChanged(CalendarDatePickerAlexMode mode) {
  //   _vibrate();
  //   setState(() {
  //     _mode = mode;
  //     if (_selectedDates.isNotEmpty) {
  //       for (final date in _selectedDates) {
  //         if (date != null) {
  //           SemanticsService.announce(
  //             _mode == CalendarDatePickerAlexMode.day
  //                 ? _localizations.formatMonthYear(date)
  //                 : _mode == CalendarDatePickerAlexMode.month
  //                     ? _localizations.formatMonthYear(date)
  //                     : _localizations.formatYear(date),
  //             _textDirection,
  //           );
  //         }
  //       }
  //     }
  //   });
  // }

  void _handleDisplayedMonthDateChanged(
    DateTime date, {
    bool fromYearPicker = false,
  }) {
    _vibrate();
    setState(() {
      final currentDisplayedMonthDate = DateTime(
        _currentDisplayedMonthDate.year,
        _currentDisplayedMonthDate.month,
      );
      var newDisplayedMonthDate = currentDisplayedMonthDate;

      if (_currentDisplayedMonthDate.year != date.year ||
          _currentDisplayedMonthDate.month != date.month) {
        newDisplayedMonthDate = DateTime(date.year, date.month);
      }

      if (fromYearPicker) {
        final selectedDatesInThisYear = _selectedDates
            .where((d) => d?.year == date.year)
            .toList()
          ..sort((d1, d2) => d1!.compareTo(d2!));
        if (selectedDatesInThisYear.isNotEmpty) {
          newDisplayedMonthDate =
              DateTime(date.year, selectedDatesInThisYear[0]!.month);
        }
      }

      if (currentDisplayedMonthDate.year != newDisplayedMonthDate.year ||
          currentDisplayedMonthDate.month != newDisplayedMonthDate.month) {
        _currentDisplayedMonthDate = DateTime(
          newDisplayedMonthDate.year,
          newDisplayedMonthDate.month,
        );
        widget.onDisplayedMonthChanged?.call(_currentDisplayedMonthDate);
      }
    });
  }

  void _handleMonthChanged(DateTime value) {
    _vibrate();
    setState(() {
      _mode = CalendarDatePickerAlexMode.day;
      _handleDisplayedMonthDateChanged(value);
    });
  }

  void _handleYearChanged(DateTime value) {
    _vibrate();

    if (value.isBefore(widget.config.firstDate)) {
      value = widget.config.firstDate;
    } else if (value.isAfter(widget.config.lastDate)) {
      value = widget.config.lastDate;
    }

    setState(() {
      _mode = CalendarDatePickerAlexMode.day;
      _handleDisplayedMonthDateChanged(value, fromYearPicker: true);
    });
  }

  void _handleDayChanged(DateTime value) {
    _vibrate();
    setState(() {
      var selectedDates = [..._selectedDates];
      selectedDates.removeWhere((d) => d == null);

      final calendarType = widget.config.calendarType;
      switch (calendarType) {
        case CalendarDatePickerAlexType.single:
          selectedDates = [value];
          break;

        case CalendarDatePickerAlexType.multi:
          final index =
              selectedDates.indexWhere((d) => DateUtils.isSameDay(d, value));
          if (index != -1) {
            selectedDates.removeAt(index);
          } else {
            selectedDates.add(value);
          }
          break;

        case CalendarDatePickerAlexType.range:
          if (selectedDates.isEmpty) {
            selectedDates.add(value);
            break;
          }

          final isRangeSet =
              selectedDates.length > 1 && selectedDates[1] != null;
          final isSelectedDayBeforeStartDate =
              value.isBefore(selectedDates[0]!);

          if (isRangeSet) {
            selectedDates = [value, null];
          } else if (isSelectedDayBeforeStartDate &&
              widget.config.rangeBidirectional != true) {
            selectedDates = [value, null];
          } else {
            selectedDates = [selectedDates[0], value];
          }

          break;
      }

      selectedDates
        ..removeWhere((d) => d == null)
        ..sort((d1, d2) => d1!.compareTo(d2!));

      final isValueDifferent =
          widget.config.calendarType != CalendarDatePickerAlexType.single ||
              !DateUtils.isSameDay(selectedDates[0],
                  _selectedDates.isNotEmpty ? _selectedDates[0] : null);
      if (isValueDifferent || widget.config.allowSameValueSelection == true) {
        _selectedDates = [...selectedDates];
        widget.onValueChanged?.call(_selectedDates);
      }
    });
  }

  Widget _buildPicker() {
    switch (_mode) {
      case CalendarDatePickerAlexMode.day:
        return _CalendarView(
          config: widget.config,
          key: _dayPickerKey,
          initialMonth: _currentDisplayedMonthDate,
          selectedDates: _selectedDates,
          onChanged: _handleDayChanged,
          onDisplayedMonthChanged: _handleDisplayedMonthDateChanged,
        );
      case CalendarDatePickerAlexMode.month:
        return Padding(
          padding: EdgeInsets.only(
              top: widget.config.controlsHeight ?? _subHeaderHeight),
          child: _MonthPicker(
            config: widget.config,
            key: _monthPickerKey,
            initialMonth: _currentDisplayedMonthDate,
            selectedDates: _selectedDates,
            onChanged: _handleMonthChanged,
          ),
        );
      case CalendarDatePickerAlexMode.year:
        return Padding(
          padding: EdgeInsets.only(
              top: widget.config.controlsHeight ?? _subHeaderHeight),
          child: YearPicker(
            config: widget.config,
            key: _yearPickerKey,
            initialMonth: _currentDisplayedMonthDate,
            selectedDates: _selectedDates,
            onChanged: _handleYearChanged,
          ),
        );
    }
  }

  int _numberOfWeeksThisMonth() {
    _currentDisplayedMonthDate;
    final numberOfDays = DateTime(_currentDisplayedMonthDate.year,
            _currentDisplayedMonthDate.month + 1, 0)
        .day;
    final List<int> weeks = <int>[];
    for (int i = 1; i <= numberOfDays; i++) {
      final int week = Jiffy.parseFromDateTime(DateTime(
              _currentDisplayedMonthDate.year,
              _currentDisplayedMonthDate.month,
              i))
          .weekOfYear;
      if (!weeks.contains(week)) {
        weeks.add(week);
      }
    }

    return weeks.length;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));

    return LayoutBuilder(builder: (context, constraints) {
      final maxDayPickerRowCount = _numberOfWeeksThisMonth();
      final calendarPadding = widget.config.calendarPaddingSize ?? 0;
      final double tileWidth =
          (constraints.maxWidth - calendarPadding) / DateTime.daysPerWeek;
      final header = widget.config.controlsHeight ?? _subHeaderHeight;
      final height = (tileWidth * (maxDayPickerRowCount + 1)) + header;
      return SizedBox(
        width: constraints.maxWidth,
        height: height,
        child: _buildPicker(),
      );
    });
  }
}
