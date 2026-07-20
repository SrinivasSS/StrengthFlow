import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.System;

enum WorkoutState {
    STATE_READY,
    STATE_SET_ACTIVE,
    STATE_REST,
    STATE_PAUSED
}

class WorkoutView extends WatchUi.View {

    private var _state as WorkoutState = STATE_READY;
    private var _exerciseName as String;
    private var _groupName as String;
    private var _setNumber as Number = 0;
    private var _reps as Number = 0;
    private var _elapsedSeconds as Number = 0;
    private var _restSeconds as Number = 0;
    private var _totalWorkoutSeconds as Number = 0;
    private var _timer as Timer.Timer?;
    private var _repDetector as RepDetector;
    private var _healthMonitor as HealthMonitor;
    private var _recorder as WorkoutRecorder;
    private var _setHistory as Array<Dictionary> = [];
    private var _autoDetectEnabled as Boolean = true;
    private var _stateBeforePause as WorkoutState = STATE_SET_ACTIVE;
    private var _transitionCooldown as Number = 0;
    private var _weight as Number = 0;
    private var _manualDistance as Float = -1.0;
    private var _restAlertFired as Boolean = false;
    private var _totalVolume as Number = 0;
    private var _newPR as Boolean = false;
    private var _newPRText as String = "";

    function initialize(exerciseName as String, groupName as String) {
        View.initialize();
        _exerciseName = exerciseName;
        _groupName = groupName;
        _repDetector = new RepDetector(self);
        _healthMonitor = new HealthMonitor();
        _recorder = new WorkoutRecorder();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_isSaving) {
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, "Saving...",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_state == STATE_READY) {
            drawReadyState(dc, cx, cy, w, h);
        } else if (_state == STATE_SET_ACTIVE) {
            drawActiveState(dc, cx, cy, w, h);
        } else if (_state == STATE_REST) {
            drawRestState(dc, cx, cy, w, h);
        }
    }

    private function drawReadyState(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        dc.setColor(0x00BBFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 55, Graphics.FONT_MEDIUM, _exerciseName,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 18, Graphics.FONT_XTINY, _groupName,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Last-time recall
        var last = LastSession.summary(_exerciseName, weightUnit());
        if (!last.equals("")) {
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 8, Graphics.FONT_XTINY, "Last: " + last,
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 45, Graphics.FONT_SMALL, "Press START",
            Graphics.TEXT_JUSTIFY_CENTER);

        var detectColor = _autoDetectEnabled ? 0x00CC66 : 0x555555;
        dc.setColor(detectColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 82, Graphics.FONT_XTINY,
            _autoDetectEnabled ? "Auto ON" : "Auto OFF",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawActiveState(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        var accent = 0x00CC66;
        var hr = _healthMonitor.getCurrentHR();
        var hrStr = hr > 0 ? hr.toString() : "--";
        var hrColor = _healthMonitor.getZoneColor();
        var cal = _healthMonitor.getCalories();

        // Primary metric value + label
        var bigVal;
        var bigLabel;
        if (isCardioExercise()) {
            if (isStairExercise()) {
                bigVal = _healthMonitor.getFloors().toString();
                bigLabel = "FLOORS";
            } else {
                var miles = _manualDistance >= 0.0 ? _manualDistance : _healthMonitor.getDistanceMiles();
                bigVal = miles.format("%.2f");
                bigLabel = _manualDistance >= 0.0 ? "MILES *" : "MILES";
            }
        } else {
            bigVal = _reps.toString();
            bigLabel = "REPS";
        }

        // Show weight next to exercise name when set (strength only)
        var sub = _exerciseName;
        if (!isCardioExercise() && _weight > 0) {
            sub = _exerciseName + " • " + _weight + " " + weightUnit();
        }

        drawWorkoutGrid(dc, {
            "accent" => accent,
            "status" => "SET " + _setNumber,
            "sub" => sub,
            "bigVal" => bigVal,
            "bigLabel" => bigLabel,
            "hrStr" => hrStr,
            "hrColor" => hrColor,
            "cal" => cal.toString(),
            "leftVal" => formatTime(_elapsedSeconds),
            "leftLabel" => "SET TIME",
            "rightVal" => formatTime(_totalWorkoutSeconds),
            "rightLabel" => "TOTAL"
        });
    }

    // Garmin-style grid: header row, big hero cell, then 2 rows of split data cells
    private function drawWorkoutGrid(dc as Dc, d as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var accent = d["accent"] as Number;
        var statusText = d["status"] as String;
        var subText = d["sub"] as String;
        var bigVal = d["bigVal"] as String;
        var bigLabel = d["bigLabel"] as String;
        var hrStr = d["hrStr"] as String;
        var hrColor = d["hrColor"] as Number;
        var calStr = d["cal"] as String;
        var leftVal = d["leftVal"] as String;
        var leftLabel = d["leftLabel"] as String;
        var rightVal = d["rightVal"] as String;
        var rightLabel = d["rightLabel"] as String;

        var line = 0x333333;

        // HR zone ring across the top
        drawHrZoneRing(dc, cx, h / 2, w, h);

        // Row boundaries
        var r1 = 95;   // header band bottom
        var r2 = 235;  // hero cell bottom
        var r3 = 300;  // data row 1 bottom

        // Grid divider lines (horizontal)
        dc.setColor(line, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w * 10 / 100, r1, w * 90 / 100, r1);
        dc.drawLine(w * 8 / 100, r2, w * 92 / 100, r2);
        dc.drawLine(w * 10 / 100, r3, w * 90 / 100, r3);
        // Vertical divider in data row (between HR and CAL)
        dc.drawLine(cx, r2, cx, r3);
        // Vertical divider in bottom row (between ELAPSED and TOTAL)
        dc.drawLine(cx, r3, cx, h * 90 / 100);

        // === Header band (clock • status, then exercise) ===
        var now = System.getClockTime();
        var hour = now.hour > 12 ? now.hour - 12 : now.hour;
        if (hour == 0) { hour = 12; }
        var clockStr = hour + ":" + now.min.format("%02d");
        // Status + exercise at top
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 44, Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 66, Graphics.FONT_XTINY, subText, Graphics.TEXT_JUSTIFY_CENTER);
        // Clock at bottom
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 40, Graphics.FONT_XTINY, clockStr, Graphics.TEXT_JUSTIFY_CENTER);

        // === Hero cell (big primary metric) ===
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 108, Graphics.FONT_NUMBER_HOT, bigVal, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 210, Graphics.FONT_XTINY, bigLabel, Graphics.TEXT_JUSTIFY_CENTER);

        // === Data row 1: HR | CAL === (columns inset from edges for round display)
        var q1 = w * 30 / 100;
        var q3 = w * 70 / 100;
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q1, r2 + 6, Graphics.FONT_SMALL, hrStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q1, r2 + 44, Graphics.FONT_XTINY, "HR", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q3, r2 + 6, Graphics.FONT_SMALL, calStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q3, r2 + 44, Graphics.FONT_XTINY, "CAL", Graphics.TEXT_JUSTIFY_CENTER);

        // === Data row 2: leftVal | rightVal ===
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q1, r3 + 6, Graphics.FONT_SMALL, leftVal, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q1, r3 + 44, Graphics.FONT_XTINY, leftLabel, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q3, r3 + 6, Graphics.FONT_SMALL, rightVal, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(q3, r3 + 44, Graphics.FONT_XTINY, rightLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRestState(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        var hr = _healthMonitor.getCurrentHR();
        var hrStr = hr > 0 ? hr.toString() : "--";
        var hrColor = _healthMonitor.getZoneColor();
        var cal = _healthMonitor.getCalories();

        // If rest timer enabled, count down to target; else count up
        var restBig;
        var restLbl;
        if (isRestTimerEnabled()) {
            var remaining = getRestTarget() - _restSeconds;
            if (remaining < 0) { remaining = 0; }
            restBig = formatTime(remaining);
            restLbl = "REST LEFT";
        } else {
            restBig = formatTime(_restSeconds);
            restLbl = "REST TIME";
        }

        var restSub = _exerciseName + " • " + _reps + "r";
        if (_weight > 0) {
            restSub += " • " + _weight + " " + weightUnit();
        }
        if (!_newPRText.equals("")) {
            restSub = "PR! " + _newPRText + " " + weightUnit();
        }

        // Right cell shows this exercise's PR (best weight) if known
        var pr = PRTracker.getBestWeight(_exerciseName);
        var rightVal = pr > 0 ? pr.toString() : _setNumber.toString();
        var rightLabel = pr > 0 ? ("PR " + weightUnit()) : "SETS";

        drawWorkoutGrid(dc, {
            "accent" => 0x3399FF,
            "status" => "REST",
            "sub" => restSub,
            "bigVal" => restBig,
            "bigLabel" => restLbl,
            "hrStr" => hrStr,
            "hrColor" => hrColor,
            "cal" => cal.toString(),
            "leftVal" => formatTime(_totalWorkoutSeconds),
            "leftLabel" => "TOTAL",
            "rightVal" => rightVal,
            "rightLabel" => rightLabel
        });
    }

    private function isCardioExercise() as Boolean {
        return _exerciseName.equals("Treadmill Run") ||
               _exerciseName.equals("Elliptical") ||
               _exerciseName.equals("Stairmaster") ||
               _exerciseName.equals("HIIT") ||
               _exerciseName.equals("Rowing Machine") ||
               _exerciseName.equals("Cycling") ||
               _exerciseName.equals("Jump Rope") ||
               _exerciseName.equals("Burpees") ||
               _exerciseName.equals("Mountain Climbers") ||
               _exerciseName.equals("Jumping Jacks") ||
               _exerciseName.equals("Box Jumps") ||
               _exerciseName.equals("Battle Ropes") ||
               _exerciseName.equals("Kettlebell Swing");
    }

    private function isStairExercise() as Boolean {
        return _exerciseName.equals("Stairmaster");
    }

    private function isDistanceExercise() as Boolean {
        return _exerciseName.equals("Treadmill Run") ||
               _exerciseName.equals("Elliptical") ||
               _exerciseName.equals("Rowing Machine") ||
               _exerciseName.equals("Cycling");
    }

    // Half-hex that rests on the top bezel edge — like Garmin's native data screens
    private function drawTopHalfHex(dc as Dc, cx as Number, bottomY as Number, w as Number, color as Number) as Void {
        var hw = w / 2;
        var indent = hw / 3;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Bottom edge (flat) + angled sides going up to bezel
        dc.drawLine(cx - hw + indent, bottomY, cx + hw - indent, bottomY);
        dc.drawLine(cx + hw - indent, bottomY, cx + hw, bottomY - 20);
        dc.drawLine(cx - hw + indent, bottomY, cx - hw, bottomY - 20);
    }

    // Half-hex that rests on the bottom bezel edge
    private function drawBottomHalfHex(dc as Dc, cx as Number, topY as Number, w as Number, color as Number) as Void {
        var hw = w / 2;
        var indent = hw / 3;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Top edge (flat) + angled sides going down to bezel
        dc.drawLine(cx - hw + indent, topY, cx + hw - indent, topY);
        dc.drawLine(cx + hw - indent, topY, cx + hw, topY + 20);
        dc.drawLine(cx - hw + indent, topY, cx - hw, topY + 20);
    }

    // Draws a 5-segment HR zone ring around the display edge.
    // Each zone gets a segment; the current zone is bright, others dim.
    private function drawHrZoneRing(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        if (!(dc has :drawArc)) { return; }

        var radius = (w / 2) - 4;
        var currentZone = _healthMonitor.getHRZone();

        // Zone colors (1-5)
        var zoneColors = [0xAAAAAA, 0x00AAFF, 0x00CC00, 0xFFAA00, 0xFF0000];

        // 5 segments across the TOP half. Garmin arc angles: 0°=3 o'clock,
        // 90°=12 o'clock, 180°=9 o'clock. Top half = 180° (left) to 0° (right),
        // going clockwise through 90 (top). Span the full top: 175°..5°.
        var segStart = 175;
        var segSpan = 34; // degrees per zone segment (5 × 34 ≈ 170°)

        if (dc has :setPenWidth) {
            dc.setPenWidth(8);
        }

        for (var z = 1; z <= 5; z++) {
            var color = zoneColors[z - 1];
            // Always visible: dim if not the current zone, but not black
            if (currentZone > 0 && z != currentZone) {
                color = dimColor(color);
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            var start = segStart - (z - 1) * segSpan;
            var end = start - segSpan + 3;
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, start, end);
        }

        if (dc has :setPenWidth) {
            dc.setPenWidth(1);
        }
    }

    private function dimColor(color as Number) as Number {
        // Halve each RGB channel to dim
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        r = r / 4;
        g = g / 4;
        b = b / 4;
        return (r << 16) | (g << 8) | b;
    }

    private function getTotalReps() as Number {
        var total = 0;
        for (var i = 0; i < _setHistory.size(); i++) {
            total += _setHistory[i]["reps"] as Number;
        }
        total += _reps;
        return total;
    }

    function startWorkout() as Void {
        _totalWorkoutSeconds = 0;
        _setNumber = 0;
        _setHistory = [];
        try { _healthMonitor.start(); } catch (e) {}
        try {
            if (isCardioExercise()) {
                _recorder.startCardio(_exerciseName);
            } else {
                _recorder.startStrength(_groupName);
            }
        } catch (e) {}
        startSet();
        startTimer();
        var autoRepEnabled = true;
        try {
            var val = Application.Properties.getValue("autoRepCounting");
            if (val != null && val instanceof Boolean) {
                autoRepEnabled = val as Boolean;
            }
        } catch (e) {}
        if (_autoDetectEnabled && autoRepEnabled && !isCardioExercise()) {
            try {
                _repDetector.start();
                _repDetector.loadThresholdsForExercise(_exerciseName);
            } catch (e) {}
        }
        vibeStart();
    }

    function startSet() as Void {
        if (_state == STATE_REST) {
            _repDetector.onManualTransition(false);
            vibeSetStart();
        }
        _setNumber++;
        _reps = 0;
        _elapsedSeconds = 0;
        _state = STATE_SET_ACTIVE;
        _transitionCooldown = 15;
        _newPRText = "";
        _recorder.setCurrentExercise(_exerciseName);
        WatchUi.requestUpdate();
    }

    function endSet() as Void {
        try {
            _repDetector.onManualTransition(true);
        } catch (e) {}
        try {
            if (_repDetector.isLearning()) {
                _repDetector.finalizeLearning();
            }
        } catch (e) {}
        _setHistory.add({
            "set" => _setNumber,
            "reps" => _reps,
            "duration" => _elapsedSeconds,
            "exercise" => _exerciseName,
            "weight" => _weight
        });
        _totalVolume += _weight * _reps;
        LastSession.record(_exerciseName, _weight, _reps);
        // Check for a new PR
        if (_weight > 0 && PRTracker.checkAndRecord(_exerciseName, _weight)) {
            _newPR = true;
            _newPRText = _exerciseName + " " + _weight;
        }
        try {
            _recorder.recordSet(_reps, _exerciseName);
        } catch (e) {}
        _restSeconds = 0;
        _restAlertFired = false;
        _state = STATE_REST;
        _transitionCooldown = 15;
        if (_newPR) {
            vibePR();
            _newPR = false;
        } else {
            vibeSetEnd();
        }
        WatchUi.requestUpdate();
    }

    function endWorkout(restartAfter as Boolean) as Void {
        if ((_state == STATE_SET_ACTIVE || _state == STATE_PAUSED) && _reps > 0) {
            _setHistory.add({
                "set" => _setNumber,
                "reps" => _reps,
                "duration" => _elapsedSeconds,
                "exercise" => _exerciseName,
                "weight" => _weight
            });
            _totalVolume += _weight * _reps;
            LastSession.record(_exerciseName, _weight, _reps);
            if (_weight > 0) { PRTracker.checkAndRecord(_exerciseName, _weight); }
            try { _recorder.recordSet(_reps, _exerciseName); } catch (e) {}
        }
        stopTimer();
        try { _repDetector.stop(); } catch (e) {}
        try { _healthMonitor.stop(); } catch (e) {}
        try { _recorder.save(); } catch (e) {}
        _state = STATE_READY;
        vibeWorkoutEnd();

        var summaryView = new SummaryView(
            _setHistory, _totalWorkoutSeconds, _exerciseName,
            _healthMonitor.getAvgHR(), _healthMonitor.getPeakHR(),
            _healthMonitor.getCalories(), _totalVolume
        );
        WatchUi.pushView(summaryView, new SummaryDelegate(summaryView, restartAfter), WatchUi.SLIDE_LEFT);
    }

    function pauseWorkout() as Void {
        _stateBeforePause = _state;
        _state = STATE_PAUSED;
        stopTimer();
        // Keep repDetector running so debug view shows live data
        vibeTap();

        var menu = new WatchUi.Menu2({:title => "Workout Paused"});
        menu.addItem(new WatchUi.MenuItem("Resume", formatTime(_totalWorkoutSeconds) + " elapsed", :resume, null));
        if (isCardioExercise()) {
            if (!isStairExercise()) {
                var distLabel = _manualDistance >= 0.0 ? _manualDistance.format("%.1f") + " mi" : "Auto";
                menu.addItem(new WatchUi.MenuItem("Set Distance", distLabel, :distance, null));
            }
            menu.addItem(new WatchUi.MenuItem("Save & Switch", "Save cardio, pick new", :switchExercise, null));
        } else {
            var weightLabel = _weight > 0 ? _weight + " " + weightUnit() : "Not set";
            menu.addItem(new WatchUi.MenuItem("Weight", weightLabel, :weight, null));
            menu.addItem(new WatchUi.MenuItem("Switch Exercise", _exerciseName, :quickSwitch, null));
        }
        var autoLabel = _autoDetectEnabled ? "Auto-Detect: ON" : "Auto-Detect: OFF";
        menu.addItem(new WatchUi.MenuItem(autoLabel, "Toggle auto set/rest & reps", :toggleAuto, null));
        menu.addItem(new WatchUi.MenuItem("Save", _setNumber + " sets • " + getTotalReps() + " reps", :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard", "Delete workout", :discard, null));
        WatchUi.pushView(menu, new PauseMenuDelegate(self), WatchUi.SLIDE_UP);
    }

    function resumeWorkout() as Void {
        if (_state != STATE_PAUSED) {
            return;
        }
        _state = _stateBeforePause;
        _transitionCooldown = 15;
        startTimer();
        if (_autoDetectEnabled) {
            _repDetector.start();
        }
        vibeTap();
        WatchUi.requestUpdate();
    }

    function discardWorkout() as Void {
        stopTimer();
        _repDetector.stop();
        _healthMonitor.stop();
        _recorder.discard();
        _state = STATE_READY;
        _setHistory = [];
        _setNumber = 0;
        _reps = 0;
        _totalWorkoutSeconds = 0;
        vibeTap();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    private var _pendingSessionSwitch as Boolean = false;
    private var _isSaving as Boolean = false;
    private var _quickSwitchMode as Boolean = false;


    function setQuickSwitchMode(on as Boolean) as Void {
        _quickSwitchMode = on;
    }

    function isQuickSwitchMode() as Boolean {
        return _quickSwitchMode;
    }

    function doQuickSwitch(newName as String, newGroup as String) as Void {
        _quickSwitchMode = false;

        // Save current set if there are reps
        if (_reps > 0) {
            _setHistory.add({
                "set" => _setNumber,
                "reps" => _reps,
                "duration" => _elapsedSeconds,
                "exercise" => _exerciseName
            });
            try { _recorder.recordSet(_reps, _exerciseName); } catch (e) {}
        }

        // Switch to new exercise
        _exerciseName = newName;
        _groupName = newGroup;
        _setNumber++;
        _reps = 0;
        _elapsedSeconds = 0;

        try {
            _repDetector.resetLearning();
            _repDetector.loadThresholdsForExercise(newName);
        } catch (e) {}
        try {
            ExerciseHistory.recordUsage(newName);
            ExerciseHistory.recordGroup(newGroup);
        } catch (e) {}
    }

    function setWeight(w as Number) as Void {
        _weight = w;
    }

    function getVolume() as Number {
        return _totalVolume;
    }

    // Weight unit label: "kg" or "lbs" based on setting
    static function weightUnit() as String {
        try {
            var v = Application.Properties.getValue("useKg");
            if (v != null && v instanceof Boolean && v) {
                return "kg";
            }
        } catch (e) {}
        return "lbs";
    }

    static function useKg() as Boolean {
        try {
            var v = Application.Properties.getValue("useKg");
            return v != null && v instanceof Boolean && v;
        } catch (e) {}
        return false;
    }

    function setManualDistance(tenths as Number) as Void {
        // tenths of a mile → miles
        _manualDistance = tenths / 10.0;
    }

    function getManualDistanceTenths() as Number {
        if (_manualDistance < 0.0) { return 0; }
        return (_manualDistance * 10.0).toNumber();
    }

    function isCurrentCardio() as Boolean {
        return isCardioExercise();
    }

    function getWeight() as Number {
        return _weight;
    }

    function getExerciseName() as String {
        return _exerciseName;
    }

    function getGroupName() as String {
        return _groupName;
    }

    function getRepDetector() as RepDetector {
        return _repDetector;
    }

    function addRep() as Void {
        _reps++;
        vibeRep();
        WatchUi.requestUpdate();
    }

    function removeRep() as Void {
        if (_reps > 0) {
            _reps--;
            WatchUi.requestUpdate();
        }
    }

    function onAutoSetDetected() as Void {
        if (_state == STATE_REST && _transitionCooldown <= 0) {
            startSet();
        }
    }

    function onAutoRestDetected() as Void {
        if (_state == STATE_SET_ACTIVE && _reps > 0 && _transitionCooldown <= 0) {
            endSet();
        }
    }

    function toggleAutoDetect() as Void {
        _autoDetectEnabled = !_autoDetectEnabled;
        if (_autoDetectEnabled && _state != STATE_READY && _state != STATE_PAUSED) {
            _repDetector.start();
        } else if (!_autoDetectEnabled) {
            _repDetector.stop();
        }
        vibeTap();
        WatchUi.requestUpdate();
    }

    function getState() as WorkoutState {
        return _state;
    }

    function isAutoDetectEnabled() as Boolean {
        return _autoDetectEnabled;
    }

    private function startTimer() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    private function stopTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        _totalWorkoutSeconds++;
        if (_state == STATE_SET_ACTIVE) {
            _elapsedSeconds++;
        } else if (_state == STATE_REST) {
            _restSeconds++;
            // Rest timer alert — vibrate once when target rest reached
            if (!_restAlertFired && isRestTimerEnabled() && _restSeconds >= getRestTarget()) {
                _restAlertFired = true;
                vibeRestDone();
            }
        }
        if (_transitionCooldown > 0) {
            _transitionCooldown--;
        }
        _healthMonitor.update();
        WatchUi.requestUpdate();
    }

    private function isRestTimerEnabled() as Boolean {
        try {
            var v = Application.Properties.getValue("restTimerEnabled");
            return v != null && v instanceof Boolean && v;
        } catch (e) {
            return false;
        }
    }

    private function getRestTarget() as Number {
        try {
            var v = Application.Properties.getValue("restTimerSeconds");
            if (v != null && v instanceof Number && v > 0) {
                return v;
            }
        } catch (e) {}
        return 90;
    }

    private function vibeRestDone() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 300),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 300)
            ]);
        }
    }

    private function vibePR() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 150),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 150),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 400)
            ]);
        }
    }

    private function vibeStart() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 200)]);
        }
    }

    private function vibeRep() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(40, 40)]);
        }
    }

    private function vibeSetEnd() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 150),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(100, 150)
            ]);
        }
    }

    private function vibeSetStart() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(80, 100),
                new Attention.VibeProfile(0, 50),
                new Attention.VibeProfile(80, 100)
            ]);
        }
    }

    private function vibeWorkoutEnd() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 250)
            ]);
        }
    }

    private function vibeTap() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(30, 30)]);
        }
    }

    private function formatTime(seconds as Number) as String {
        var min = seconds / 60;
        var sec = seconds % 60;
        return min.format("%d") + ":" + sec.format("%02d");
    }
}
