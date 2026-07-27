import Toybox.Lang;
import Toybox.Activity;
import Toybox.UserProfile;
import Toybox.System;

class HealthMonitor {

    private var _currentHR as Number = 0;
    private var _peakHR as Number = 0;
    private var _avgHR as Number = 0;
    private var _hrSamples as Number = 0;
    private var _hrSum as Number = 0;
    private var _calories as Number = 0;
    private var _hrZone as Number = 0;
    private var _distanceMeters as Float = 0.0;
    private var _isRunning as Boolean = false;

    function initialize() {
    }

    function start() as Void {
        _isRunning = true;
        _currentHR = 0;
        _peakHR = 0;
        _avgHR = 0;
        _hrSamples = 0;
        _hrSum = 0;
        _calories = 0;
        _hrZone = 0;
    }

    function stop() as Void {
        _isRunning = false;
    }

    private var _lastHR as Number = 0;
    private var _staleCount as Number = 0;
    private var _hrValid as Boolean = false;

    // Call this every second from the timer tick
    function update() as Void {
        if (!_isRunning) { return; }

        var info = Activity.getActivityInfo();
        if (info != null) {
            if (info.currentHeartRate != null) {
                var hr = info.currentHeartRate;

                // If HR hasn't changed for 15 seconds, likely stale/not worn
                if (hr == _lastHR) {
                    _staleCount++;
                    if (_staleCount > 15) {
                        _hrValid = false;
                        _currentHR = 0;
                    }
                } else {
                    _staleCount = 0;
                    _hrValid = true;
                    _currentHR = hr;
                    _lastHR = hr;

                    _hrSamples++;
                    _hrSum += _currentHR;
                    _avgHR = _hrSum / _hrSamples;

                    if (_currentHR > _peakHR) {
                        _peakHR = _currentHR;
                    }

                    _hrZone = computeZone(_currentHR);
                }
            } else {
                _hrValid = false;
                _currentHR = 0;
            }

            if (info.calories != null) {
                _calories = info.calories;
            }

            if (info.elapsedDistance != null) {
                _distanceMeters = info.elapsedDistance;
            }
        }
    }

    function getDistanceMiles() as Float {
        return _distanceMeters / 1609.34;
    }

    function getFloors() as Number {
        var info = Activity.getActivityInfo();
        if (info != null && info.totalAscent != null) {
            return info.totalAscent / 3;
        }
        return 0;
    }

    private function computeZone(hr as Number) as Number {
        // getHeartRateZones returns 6 boundaries: zones[0]=floor of zone 1,
        // zones[1]=floor of zone 2, ... zones[4]=floor of zone 5, zones[5]=max HR.
        // Zone N = zones[N-1] <= hr < zones[N]. (The old code compared the wrong
        // indices, so real zone-1 HRs fell through to 0 and nothing highlighted.)
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones != null && zones.size() >= 6) {
            if (hr >= zones[4]) { return 5; }
            if (hr >= zones[3]) { return 4; }
            if (hr >= zones[2]) { return 3; }
            if (hr >= zones[1]) { return 2; }
            if (hr >= zones[0]) { return 1; }
        }
        return 0;
    }

    function getCurrentHR() as Number {
        return _currentHR;
    }

    function getHRZone() as Number {
        return _hrZone;
    }

    function getCalories() as Number {
        return _calories;
    }

    function getPeakHR() as Number {
        return _peakHR;
    }

    function getAvgHR() as Number {
        return _avgHR;
    }

    function getZoneColor() as Number {
        switch (_hrZone) {
            case 1: return 0xAAAAAA;
            case 2: return 0x00AAFF;
            case 3: return 0x00CC00;
            case 4: return 0xFFAA00;
            case 5: return 0xFF0000;
            default: return 0x666666;
        }
    }

    function getZoneName() as String {
        switch (_hrZone) {
            case 1: return "WARM UP";
            case 2: return "EASY";
            case 3: return "AEROBIC";
            case 4: return "THRESHOLD";
            case 5: return "MAXIMUM";
            default: return "--";
        }
    }
}
