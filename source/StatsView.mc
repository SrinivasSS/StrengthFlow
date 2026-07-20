import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Secondary screen (below main) showing history for the current exercise:
// last session, personal record, and this workout's running volume.
class StatsView extends WatchUi.View {

    private var _exerciseName as String;
    private var _volume as Number;
    private var _unit as String;

    function initialize(exerciseName as String, volume as Number, unit as String) {
        View.initialize();
        _exerciseName = exerciseName;
        _volume = volume;
        _unit = unit;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var y = 55;

        // Title
        dc.setColor(0x00BBFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "STATS", Graphics.TEXT_JUSTIFY_CENTER);
        y += 22;
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, _exerciseName, Graphics.TEXT_JUSTIFY_CENTER);
        y += 40;

        // Last session
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "LAST TIME", Graphics.TEXT_JUSTIFY_CENTER);
        y += 22;
        var last = LastSession.summary(_exerciseName, _unit);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, last.equals("") ? "--" : last,
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 42;

        // Personal record
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "PERSONAL BEST", Graphics.TEXT_JUSTIFY_CENTER);
        y += 22;
        var pr = PRTracker.getBestWeight(_exerciseName);
        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, pr > 0 ? pr + " " + _unit : "--",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 42;

        // This workout volume
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "VOLUME TODAY", Graphics.TEXT_JUSTIFY_CENTER);
        y += 22;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            _volume > 0 ? _volume + " " + _unit : "--",
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class StatsDelegate extends WatchUi.BehaviorDelegate {

    private var _view as WorkoutView;

    function initialize(view as WorkoutView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // BACK — close stats AND toggle set/rest (same as main screen)
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        var state = _view.getState();
        if (state == STATE_SET_ACTIVE) {
            _view.endSet();
        } else if (state == STATE_REST) {
            _view.startSet();
        }
        return true;
    }

    // UP returns to the main workout screen
    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
