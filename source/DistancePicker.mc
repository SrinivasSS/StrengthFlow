import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Rollable dial picker for distance: whole miles wheel + tenths wheel
class DistancePicker extends WatchUi.Picker {

    function initialize(startTenths as Number) {
        var wholeStart = startTenths / 10;
        var tenthStart = startTenths % 10;

        var title = new WatchUi.Text({
            :text => "Distance (mi)",
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_TOP,
            :color => Graphics.COLOR_WHITE
        });

        // Whole miles 0-99
        var wholeValues = new [100];
        for (var i = 0; i < 100; i++) {
            wholeValues[i] = i.toString();
        }
        var wholeFactory = new NumberFactory(wholeValues);

        // Decimal point separator
        var dotFactory = new NumberFactory(["."]);

        // Tenths 0-9
        var tenthValues = new [10];
        for (var i = 0; i < 10; i++) {
            tenthValues[i] = i.toString();
        }
        var tenthFactory = new NumberFactory(tenthValues);

        Picker.initialize({
            :title => title,
            :pattern => [wholeFactory, dotFactory, tenthFactory],
            :defaults => [wholeStart, 0, tenthStart]
        });
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

// Simple factory that shows a list of string values
class NumberFactory extends WatchUi.PickerFactory {
    private var _values as Array<String>;

    function initialize(values as Array<String>) {
        PickerFactory.initialize();
        _values = values;
    }

    function getSize() as Number {
        return _values.size();
    }

    function getValue(index as Number) as Object? {
        return index;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        return new WatchUi.Text({
            :text => _values[index],
            :color => selected ? Graphics.COLOR_WHITE : 0x555555,
            :font => selected ? Graphics.FONT_NUMBER_MILD : Graphics.FONT_SMALL,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}
