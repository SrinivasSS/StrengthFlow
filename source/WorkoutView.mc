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
        dc.drawText(cx, cy - 40, Graphics.FONT_MEDIUM, _exerciseName,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_XTINY, _groupName,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 40, Graphics.FONT_SMALL, "Press START",
            Graphics.TEXT_JUSTIFY_CENTER);

        var detectColor = _autoDetectEnabled ? 0x00CC66 : 0x555555;
        dc.setColor(detectColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 80, Graphics.FONT_XTINY,
            _autoDetectEnabled ? "Auto ON" : "Auto OFF",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawActiveState(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        // Green accent bar
        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 4);

        // Zone 1 (top): SET + line + Exercise
        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 45, Graphics.FONT_SMALL, "SET " + _setNumber,
            Graphics.TEXT_JUSTIFY_CENTER);
        drawTopHalfHex(dc, cx, 85, 160, 0x00CC66);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 90, Graphics.FONT_XTINY, _exerciseName,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 2 (upper): HR left, CAL right
        var hr = _healthMonitor.getCurrentHR();
        var zoneColor = _healthMonitor.getZoneColor();
        var hrStr = hr > 0 ? hr.toString() : "--";
        var cal = _healthMonitor.getCalories();

        dc.setColor(zoneColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 80, 170, Graphics.FONT_XTINY, hrStr,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 80, 195, Graphics.FONT_XTINY, "HR",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 80, 170, Graphics.FONT_XTINY, cal.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 80, 195, Graphics.FONT_XTINY, "CAL",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 3 (center): REPS or Distance/Floors for cardio
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (isCardioExercise()) {
            if (isStairExercise()) {
                var floors = _healthMonitor.getFloors();
                dc.drawText(cx, 165, Graphics.FONT_NUMBER_MEDIUM, floors.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, 255, Graphics.FONT_XTINY, "FLOORS",
                    Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                var miles = _healthMonitor.getDistanceMiles();
                dc.drawText(cx, 165, Graphics.FONT_NUMBER_MEDIUM, miles.format("%.2f"),
                    Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, 255, Graphics.FONT_XTINY, "MILES",
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            dc.drawText(cx, 155, Graphics.FONT_NUMBER_HOT, _reps.toString(),
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 265, Graphics.FONT_XTINY, "REPS",
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Zone 4 (lower): Elapsed left, Total right — no borders
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 70, 295, Graphics.FONT_XTINY, formatTime(_elapsedSeconds),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 70, 315, Graphics.FONT_XTINY, "ELAPSED",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 70, 295, Graphics.FONT_XTINY, formatTime(_totalWorkoutSeconds),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 70, 315, Graphics.FONT_XTINY, "TOTAL",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 5 (bottom): clock + auto — half hex resting on bottom bezel
        var now = System.getClockTime();
        var hour = now.hour > 12 ? now.hour - 12 : now.hour;
        if (hour == 0) { hour = 12; }
        var bottomStr = hour + ":" + now.min.format("%02d");
        if (_autoDetectEnabled) {
            bottomStr += " • AUTO";
        }
        drawBottomHalfHex(dc, cx, 350, 160, 0x00CC66);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 355, Graphics.FONT_XTINY, bottomStr,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRestState(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        // Blue accent bar
        dc.setColor(0x3399FF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 4);

        // Zone 1 (top): REST + line + exercise
        dc.setColor(0x3399FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 45, Graphics.FONT_SMALL, "REST",
            Graphics.TEXT_JUSTIFY_CENTER);
        drawTopHalfHex(dc, cx, 85, 160, 0x3399FF);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 78, Graphics.FONT_XTINY, _exerciseName + " • " + _reps + "r",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 2 (upper): HR left, CAL right
        var hr = _healthMonitor.getCurrentHR();
        var zoneColor = _healthMonitor.getZoneColor();
        var hrStr = hr > 0 ? hr.toString() : "--";
        var cal = _healthMonitor.getCalories();

        dc.setColor(zoneColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 80, 170, Graphics.FONT_XTINY, hrStr,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 80, 195, Graphics.FONT_XTINY, "HR",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 80, 170, Graphics.FONT_XTINY, cal.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 80, 195, Graphics.FONT_XTINY, "CAL",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 3 (center): REST TIMER
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 165, Graphics.FONT_NUMBER_MEDIUM, formatTime(_restSeconds),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 255, Graphics.FONT_XTINY, "REST",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 4 (lower): Total left, Sets right — no borders
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 70, 295, Graphics.FONT_XTINY, formatTime(_totalWorkoutSeconds),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - 70, 315, Graphics.FONT_XTINY, "TOTAL",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 70, 295, Graphics.FONT_XTINY, _setNumber.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 70, 315, Graphics.FONT_XTINY, "SETS",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Zone 5 (bottom): clock + auto — half hex resting on bottom bezel
        var now = System.getClockTime();
        var hour = now.hour > 12 ? now.hour - 12 : now.hour;
        if (hour == 0) { hour = 12; }
        var bottomStr = hour + ":" + now.min.format("%02d");
        if (_autoDetectEnabled) {
            bottomStr += " • AUTO";
        }
        drawBottomHalfHex(dc, cx, 350, 160, 0x3399FF);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 355, Graphics.FONT_XTINY, bottomStr,
            Graphics.TEXT_JUSTIFY_CENTER);
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
            "exercise" => _exerciseName
        });
        try {
            _recorder.recordSet(_reps, _exerciseName);
        } catch (e) {}
        _restSeconds = 0;
        _state = STATE_REST;
        _transitionCooldown = 15;
        vibeSetEnd();
        WatchUi.requestUpdate();
    }

    function endWorkout(restartAfter as Boolean) as Void {
        if ((_state == STATE_SET_ACTIVE || _state == STATE_PAUSED) && _reps > 0) {
            _setHistory.add({
                "set" => _setNumber,
                "reps" => _reps,
                "duration" => _elapsedSeconds,
                "exercise" => _exerciseName
            });
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
            _healthMonitor.getCalories()
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
        var weightLabel = _weight > 0 ? _weight + " lbs" : "Not set";
        menu.addItem(new WatchUi.MenuItem("Weight", weightLabel, :weight, null));
        if (isCardioExercise()) {
            menu.addItem(new WatchUi.MenuItem("Save & Switch", "Save cardio, pick new", :switchExercise, null));
        } else {
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
        }
        if (_transitionCooldown > 0) {
            _transitionCooldown--;
        }
        _healthMonitor.update();


        WatchUi.requestUpdate();
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
