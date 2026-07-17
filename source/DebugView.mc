import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Timer;

class DebugView extends WatchUi.View {

    private var _repDetector as RepDetector;
    private var _timer as Timer.Timer?;

    function initialize(repDetector as RepDetector) {
        View.initialize();
        _repDetector = repDetector;
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onRefresh), 500, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onRefresh() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var y = 60;

        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "SENSOR DEBUG",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 30;

        // Live values
        dc.setColor(_repDetector.isReceivingData() ? 0x00CC66 : 0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            "Data: " + (_repDetector.isReceivingData() ? "YES" : "NO") +
            "  Samples: " + _repDetector.getDebugSamples(),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            "Live Dev: " + _repDetector.getDebugStdDev().format("%.0f"),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        // Mode and thresholds
        var modeStr = _repDetector.isLearning() ? "LEARNING" : "COUNTING";
        dc.setColor(_repDetector.isLearning() ? 0xFFAA00 : 0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, modeStr,
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            "Peak>" + _repDetector.getDebugPeakThreshold().format("%.0f") +
            "  Ret<" + _repDetector.getDebugReturnThreshold().format("%.0f"),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 30;

        // Logged min/max from set
        dc.setColor(0x00BBFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "--- SET LOG ---",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            "Min: " + _repDetector.getDevMin().format("%.0f") +
            "  Max: " + _repDetector.getDevMax().format("%.0f"),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        // Show last 10 logged values
        var log = _repDetector.getDeviationLog();
        var startIdx = log.size() > 10 ? log.size() - 10 : 0;
        var logStr = "";
        for (var i = startIdx; i < log.size(); i++) {
            if (i > startIdx) { logStr += " "; }
            logStr += log[i].format("%.0f");
        }
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, logStr,
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            "calls:" + _repDetector.getCountCallCount() + " reps:" + _repDetector.getRepCount(),
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class DebugDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
