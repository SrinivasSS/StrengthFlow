import Toybox.Lang;
import Toybox.WatchUi;

class WorkoutDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START/STOP — start or pause
    function onSelect() as Boolean {
        var state = _view.getState();
        if (state == STATE_READY) {
            _view.startWorkout();
        } else if (state == STATE_PAUSED) {
            // Shouldn't get here since menu is showing, but just in case
            _view.resumeWorkout();
        } else {
            _view.pauseWorkout();
        }
        return true;
    }

    // BACK / LAP — toggle between set and rest
    function onBack() as Boolean {
        var state = _view.getState();
        if (state == STATE_READY) {
            return false;
        } else if (state == STATE_SET_ACTIVE) {
            _view.endSet();
        } else if (state == STATE_REST) {
            _view.startSet();
        }
        return true;
    }

    // UP button — add rep
    function onPreviousPage() as Boolean {
        var state = _view.getState();
        if (state == STATE_SET_ACTIVE) {
            _view.addRep();
        }
        return true;
    }

    // DOWN / LAP button — also toggle set/rest
    function onNextPage() as Boolean {
        var state = _view.getState();
        if (state == STATE_SET_ACTIVE) {
            _view.endSet();
        } else if (state == STATE_REST) {
            _view.startSet();
        }
        return true;
    }

    // MENU (long press) — toggle auto-detect during workout
    function onMenu() as Boolean {
        var state = _view.getState();
        if (state != STATE_READY && state != STATE_PAUSED) {
            _view.toggleAutoDetect();
        }
        return true;
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Symbol;
        if (id == :resume) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.resumeWorkout();
        } else if (id == :save) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.endWorkout(false);
        } else if (id == :discard) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.discardWorkout();
        } else if (id == :debug) {
            WatchUi.pushView(new DebugView(_view.getRepDetector()), new DebugDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :toggleAuto) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.toggleAutoDetect();
            _view.resumeWorkout();
        } else if (id == :switchExercise) {
            // Same as Save, but summary will go to picker instead of back
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _view.endWorkout(true);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        _view.resumeWorkout();
    }
}

