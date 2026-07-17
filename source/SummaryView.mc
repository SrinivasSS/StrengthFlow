import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SummaryView extends WatchUi.View {

    private var _sets as Array<Dictionary>;
    private var _totalTime as Number;
    private var _exerciseName as String;
    private var _avgHR as Number;
    private var _peakHR as Number;
    private var _calories as Number;
    private var _scrollOffset as Number = 0;

    function initialize(sets as Array<Dictionary>, totalTime as Number, exerciseName as String,
                        avgHR as Number, peakHR as Number, calories as Number) {
        View.initialize();
        _sets = sets;
        _totalTime = totalTime;
        _exerciseName = exerciseName;
        _avgHR = avgHR;
        _peakHR = peakHR;
        _calories = calories;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var y = 55 - _scrollOffset;

        // Header
        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "WORKOUT COMPLETE",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 35;

        // Stats spread across width
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 90, y, Graphics.FONT_XTINY, formatTime(_totalTime),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, _calories + " cal",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 90, y, Graphics.FONT_XTINY, _avgHR > 0 ? _avgHR + " bpm" : "--",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 35;

        // === EXERCISE BREAKDOWN BARS ===
        var exercises = getExerciseBreakdown();
        var maxReps = 1;
        for (var i = 0; i < exercises.size(); i++) {
            var reps = exercises[i]["reps"] as Number;
            if (reps > maxReps) { maxReps = reps; }
        }

        var barX = 70;
        var barMaxW = w - 140;

        for (var i = 0; i < exercises.size(); i++) {
            var ex = exercises[i];
            var name = ex["name"] as String;
            var reps = ex["reps"] as Number;
            var sets = ex["sets"] as Number;

            // Exercise name + stats on same line
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(barX, y, Graphics.FONT_XTINY, name,
                Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 70, y, Graphics.FONT_XTINY,
                sets + "s " + reps + "r",
                Graphics.TEXT_JUSTIFY_RIGHT);
            y += 22;

            // Bar
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, y, barMaxW, 8, 3);
            var fillW = (barMaxW * reps) / maxReps;
            dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, y, fillW, 8, 3);
            y += 25;
        }

        // === PER-SET DETAIL ===
        y += 15;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "SETS",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        for (var i = 0; i < _sets.size(); i++) {
            var setData = _sets[i];
            var reps = setData["reps"] as Number;
            var dur = setData["duration"] as Number;
            var exName = "";
            if (setData.hasKey("exercise")) {
                exName = setData["exercise"] as String;
            }

            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(barX, y, Graphics.FONT_XTINY,
                (i + 1) + ". " + exName,
                Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 70, y, Graphics.FONT_XTINY,
                reps + "r " + formatTime(dur),
                Graphics.TEXT_JUSTIFY_RIGHT);
            y += 25;
        }
    }

    private function getExerciseBreakdown() as Array<Dictionary> {
        var exercises = [] as Array<Dictionary>;
        var exerciseNames = [] as Array<String>;

        for (var i = 0; i < _sets.size(); i++) {
            var exName = "";
            if (_sets[i].hasKey("exercise")) {
                exName = _sets[i]["exercise"] as String;
            } else {
                exName = _exerciseName;
            }

            var found = -1;
            for (var j = 0; j < exerciseNames.size(); j++) {
                if (exerciseNames[j].equals(exName)) {
                    found = j;
                    break;
                }
            }

            var reps = _sets[i]["reps"] as Number;

            if (found >= 0) {
                var existing = exercises[found];
                exercises[found] = {
                    "name" => exName,
                    "sets" => (existing["sets"] as Number) + 1,
                    "reps" => (existing["reps"] as Number) + reps
                };
            } else {
                exerciseNames.add(exName);
                exercises.add({
                    "name" => exName,
                    "sets" => 1,
                    "reps" => reps
                });
            }
        }
        return exercises;
    }

    function scrollUp() as Void {
        if (_scrollOffset > 0) {
            _scrollOffset -= 40;
            WatchUi.requestUpdate();
        }
    }

    function scrollDown() as Void {
        _scrollOffset += 40;
        WatchUi.requestUpdate();
    }

    private function formatTime(seconds as Number) as String {
        var min = seconds / 60;
        var sec = seconds % 60;
        return min.format("%d") + ":" + sec.format("%02d");
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {

    private var _view as SummaryView;
    private var _restartAfter as Boolean;

    function initialize(view as SummaryView, restartAfter as Boolean) {
        BehaviorDelegate.initialize();
        _view = view;
        _restartAfter = restartAfter;
    }

    function onSelect() as Boolean {
        dismiss();
        return true;
    }

    function onBack() as Boolean {
        dismiss();
        return true;
    }

    private function dismiss() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (_restartAfter) {
            ExercisePickerView.showGroupMenu();
        }
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        return true;
    }
}
