import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Timer;

class ExerciseView extends WatchUi.View {

    private var _exerciseName as String;
    private var _currentSet as Number = 1;
    private var _totalSets as Number = 4;
    private var _reps as Number = 0;
    private var _weight as Number = 0;
    private var _restTimer as Timer.Timer?;
    private var _restSeconds as Number = 0;
    private var _isResting as Boolean = false;

    function initialize(exerciseName as String) {
        View.initialize();
        _exerciseName = exerciseName;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var centerX = dc.getWidth() / 2;

        dc.drawText(centerX, 10, Graphics.FONT_SMALL, _exerciseName,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(centerX, 50, Graphics.FONT_MEDIUM,
            "Set " + _currentSet + "/" + _totalSets,
            Graphics.TEXT_JUSTIFY_CENTER);

        if (_isResting) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 100, Graphics.FONT_LARGE,
                "Rest: " + _restSeconds + "s",
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(centerX, 90, Graphics.FONT_SMALL,
                "Weight: " + _weight + " lbs",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, 120, Graphics.FONT_SMALL,
                "Reps: " + _reps,
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 170, Graphics.FONT_SMALL,
                "Press to log set",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function logSet() as Void {
        if (_currentSet < _totalSets) {
            _currentSet++;
            startRest();
        } else {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }

    function startRest() as Void {
        _isResting = true;
        _restSeconds = 90;
        _restTimer = new Timer.Timer();
        _restTimer.start(method(:onRestTick), 1000, true);
        WatchUi.requestUpdate();
    }

    function onRestTick() as Void {
        _restSeconds--;
        if (_restSeconds <= 0) {
            _isResting = false;
            if (_restTimer != null) {
                _restTimer.stop();
            }
        }
        WatchUi.requestUpdate();
    }

    function incrementWeight() as Void {
        _weight += 5;
        WatchUi.requestUpdate();
    }

    function decrementWeight() as Void {
        if (_weight >= 5) {
            _weight -= 5;
        }
        WatchUi.requestUpdate();
    }

    function incrementReps() as Void {
        _reps++;
        WatchUi.requestUpdate();
    }
}

class ExerciseDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var view = WatchUi.getCurrentView() as ExerciseView;
        if (view != null) {
            view.logSet();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
