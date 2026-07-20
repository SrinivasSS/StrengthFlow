import Toybox.Application;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;

class RepDetector {

    private var _view as WorkoutView;
    private var _isRunning as Boolean = false;
    private var _timer as Timer.Timer?;
    private var _usingSensorListener as Boolean = false;

    // Sliding window of acceleration magnitudes
    private var _buffer as Array<Float> = [];
    private const BUFFER_SIZE = 40;

    // Rep detection state
    private var _peakSeen as Boolean = false;
    private var _lastRepTime as Number = 0;
    private const MIN_REP_MS = 2000;
    private var _smoothedMag as Float = 1000.0;

    // Learning mode — calibrate from first manual set
    private var _isLearning as Boolean = true;
    private var _learnedPeakThreshold as Float = 50.0;
    private var _learnedReturnThreshold as Float = 25.0;
    private var _observedPeaks as Array<Float> = [];
    private var _observedValleys as Array<Float> = [];
    private var _currentPeak as Float = 0.0;
    private var _trackingPeak as Boolean = false;

    // Debug log — records deviation every 0.5s during active set
    private var _deviationLog as Array<Float> = [];
    private var _logCounter as Number = 0;
    private var _devMin as Float = 9999.0;
    private var _devMax as Float = -9999.0;

    // Running baseline
    private var _globalMean as Float = 1000.0;
    private var _frozenMean as Float = 1000.0;
    private var _meanFrozen as Boolean = false;
    private var _sampleCount as Number = 0;

    // Set/rest detection — tighter thresholds, requires learning
    private var _varianceHistory as Array<Float> = [];
    private const VAR_HISTORY_SIZE = 20;
    private var _stillCount as Number = 0;
    private var _moveCount as Number = 0;
    private const STILL_FRAMES_NEEDED = 80;
    private const MOVE_FRAMES_NEEDED = 25;
    private var _manualTransitions as Number = 0;
    private var _autoEnabled as Boolean = false;
    private var _restVariance as Float = 0.0;
    private var _activeVariance as Float = 0.0;
    private var _learnedRest as Boolean = false;
    private var _learnedActive as Boolean = false;

    private var _dataReceived as Boolean = false;
    private var _debugMag as Float = 0.0;
    private var _debugVariance as Float = 0.0;
    private var _debugStdDev as Float = 0.0;
    private var _debugSamples as Number = 0;

    function initialize(view as WorkoutView) {
        _view = view;
    }

    function isReceivingData() as Boolean {
        return _dataReceived;
    }

    function getDebugMag() as Float {
        return _debugMag;
    }

    function getDebugVariance() as Float {
        return _debugVariance;
    }

    function getDebugStdDev() as Float {
        return _debugStdDev;
    }

    function getDebugSamples() as Number {
        return _debugSamples;
    }

    function getDebugPeakThreshold() as Float {
        return _learnedPeakThreshold;
    }

    function getDebugReturnThreshold() as Float {
        return _learnedReturnThreshold;
    }

    function getDevMin() as Float {
        return _devMin;
    }

    function getDevMax() as Float {
        return _devMax;
    }

    function getDeviationLog() as Array<Float> {
        return _deviationLog;
    }

    function clearLog() as Void {
        _deviationLog = [];
        _devMin = 9999.0;
        _devMax = -9999.0;
    }

    function start() as Void {
        if (_isRunning) { return; }
        _isRunning = true;
        _buffer = [];
        _varianceHistory = [];
        _sampleCount = 0;
        _globalMean = 1000.0;
        _peakSeen = false;
        _smoothedMag = 1000.0;
        _isLearning = true;
        _observedPeaks = [];
        _observedValleys = [];
        _currentPeak = 0.0;
        _trackingPeak = false;
        _stillCount = 0;
        _moveCount = 0;
        _manualTransitions = 0;
        _autoEnabled = false;
        _learnedRest = false;
        _learnedActive = false;
        _restVariance = 0.0;
        _activeVariance = 0.0;
        _usingSensorListener = false;

        // Poll accelerometer at 10Hz — reliable on all devices
        _timer = new Timer.Timer();
        _timer.start(method(:onPoll), 100, true);
    }

    // Called when user manually transitions — learn from current variance
    function onManualTransition(toRest as Boolean) as Void {
        _manualTransitions++;

        if (_varianceHistory.size() < 5) { return; }

        var avgVar = 0.0;
        for (var i = 0; i < _varianceHistory.size(); i++) {
            avgVar += _varianceHistory[i];
        }
        avgVar = avgVar / _varianceHistory.size();

        if (toRest) {
            // User just ended a set — current variance is "active" level
            _activeVariance = (_activeVariance + avgVar) / 2.0;
            _learnedActive = true;
        } else {
            // User just started a set — current variance is "rest" level
            _restVariance = (_restVariance + avgVar) / 2.0;
            _learnedRest = true;
        }

        // Enable auto after 2 manual transitions (one set + one rest)
        if (_manualTransitions >= 2 && _learnedRest && _learnedActive) {
            _autoEnabled = true;
        }

        _stillCount = 0;
        _moveCount = 0;
    }

    function stop() as Void {
        if (_isRunning) {
            _isRunning = false;
            if (_timer != null) {
                _timer.stop();
                _timer = null;
            }
        }
    }

    // Polling fallback (guaranteed to work)
    function onPoll() as Void {
        if (!_isRunning) { return; }

        var info = Sensor.getInfo();
        if (info == null) { return; }
        if (!(info has :accel) || info.accel == null) { return; }

        var accel = info.accel as Array<Number>;
        var x = accel[0].toFloat();
        var y = accel[1].toFloat();
        var z = accel[2].toFloat();
        var mag = Math.sqrt(x * x + y * y + z * z).toFloat();

        processSample(mag);
    }

    private function processSample(mag as Float) as Void {
        _dataReceived = true;
        _debugMag = mag;
        _debugSamples++;
        _sampleCount++;

        // Build baseline from first 20 samples
        if (_sampleCount <= 20) {
            _globalMean = _globalMean + (mag - _globalMean) / _sampleCount;
            _buffer.add(mag);
            return;
        }

        // Slowly adapt baseline
        _globalMean = _globalMean * 0.997 + mag * 0.003;

        // Sliding window
        _buffer.add(mag);
        if (_buffer.size() > BUFFER_SIZE) {
            _buffer = _buffer.slice(1, null);
        }

        if (_buffer.size() < 20) { return; }

        // Local stats over recent buffer
        var localMean = 0.0;
        for (var i = 0; i < _buffer.size(); i++) {
            localMean += _buffer[i];
        }
        localMean = localMean / _buffer.size();

        var localVar = 0.0;
        for (var i = 0; i < _buffer.size(); i++) {
            var d = _buffer[i] - localMean;
            localVar += d * d;
        }
        localVar = localVar / _buffer.size();
        _debugVariance = localVar.toFloat();
        _debugStdDev = Math.sqrt(localVar).toFloat();

        // Track variance
        _varianceHistory.add(localVar.toFloat());
        if (_varianceHistory.size() > VAR_HISTORY_SIZE) {
            _varianceHistory = _varianceHistory.slice(1, null);
        }

        detectRep(mag, localMean, localVar);
        detectSetRest();
    }

    private function detectRep(mag as Float, mean as Float, variance as Float) as Void {
        // Always update smoothed signal (even when paused, for debug)
        _smoothedMag = _smoothedMag * 0.8 + mag * 0.2;

        // Freeze mean at the start of counting to prevent drift
        if (!_meanFrozen && !_isLearning) {
            _frozenMean = _globalMean;
            _meanFrozen = true;
        }

        // Use frozen mean for counting, global mean for learning
        var refMean = _meanFrozen ? _frozenMean : _globalMean;
        var deviation = _smoothedMag - refMean;
        _debugStdDev = deviation;

        if (_view.getState() == STATE_SET_ACTIVE) {
            // Log deviation every 5 samples (~0.5s)
            _logCounter++;
            if (_logCounter >= 5) {
                _logCounter = 0;
                if (_deviationLog.size() < 120) {
                    _deviationLog.add(deviation);
                }
                if (deviation < _devMin) { _devMin = deviation; }
                if (deviation > _devMax) { _devMax = deviation; }
            }
        }

        if (_view.getState() != STATE_SET_ACTIVE) {
            _peakSeen = false;
            _trackingPeak = false;
            return;
        }

        if (_isLearning) {
            // During learning: track peaks and valleys to build thresholds
            learnFromSignal(deviation);
        } else {
            // After learning: count reps using learned thresholds
            countRep(deviation);
        }
    }

    private function learnFromSignal(deviation as Float) as Void {
        var absDev = deviation > 0 ? deviation : -deviation;

        if (!_trackingPeak) {
            if (absDev > _currentPeak) {
                _currentPeak = absDev;
            }
            // Signal returned toward zero from a peak
            if (_currentPeak > 30.0 && absDev < _currentPeak * 0.4) {
                _observedPeaks.add(_currentPeak);
                _currentPeak = 0.0;
                _trackingPeak = true;
            }
        } else {
            // Wait for signal to settle before looking for next peak
            if (absDev > 30.0) {
                _trackingPeak = false;
                _currentPeak = absDev;
            }
        }
    }

    // Called when first manual set ends — finalize learning
    function finalizeLearning() as Void {
        try {
            if (_observedPeaks.size() >= 2) {
                var sumPeaks = 0.0;
                for (var i = 0; i < _observedPeaks.size(); i++) {
                    sumPeaks += _observedPeaks[i];
                }
                var avgPeak = sumPeaks / _observedPeaks.size();

                _learnedPeakThreshold = avgPeak * 0.5;
                if (_learnedPeakThreshold < 30.0) {
                    _learnedPeakThreshold = 30.0;
                }
                _learnedReturnThreshold = _learnedPeakThreshold * 0.7;

                _isLearning = false;
                saveThresholds();
            } else {
                _learnedPeakThreshold = 40.0;
                _learnedReturnThreshold = 15.0;
                _isLearning = false;
            }
        } catch (e) {
            _learnedPeakThreshold = 40.0;
            _learnedReturnThreshold = 15.0;
            _isLearning = false;
        }
    }

    function loadThresholdsForExercise(exerciseName as String) as Void {
        try {
            var key = "rep_" + exerciseName;
            var stored = Application.Storage.getValue(key);
            if (stored != null && stored instanceof Array) {
                var data = stored as Array<Float>;
                if (data.size() >= 2) {
                    _learnedPeakThreshold = data[0];
                    _learnedReturnThreshold = data[1];
                    _isLearning = false;
                    return;
                }
            }
        } catch (e) {}
        _isLearning = true;
    }

    private function saveThresholds() as Void {
        try {
            var exerciseName = _view.getExerciseName();
            var key = "rep_" + exerciseName;
            var data = [_learnedPeakThreshold, _learnedReturnThreshold] as Array<Float>;
            Application.Storage.setValue(key, data);
        } catch (e) {
            // Storage failed — not critical
        }
    }

    function isLearning() as Boolean {
        return _isLearning;
    }

    function resetLearning() as Void {
        _isLearning = true;
        _meanFrozen = false;
        _observedPeaks = [];
        _observedValleys = [];
        _currentPeak = 0.0;
        _trackingPeak = false;
    }

    private var _lowestSincePeak as Float = 9999.0;
    private var _repCount as Number = 0;
    private var _samplesSincePeak as Number = 0;
    private var _countCallCount as Number = 0;

    private function countRep(deviation as Float) as Void {
        _countCallCount++;
        var absDev = deviation;
        if (absDev < 0.0) { absDev = -absDev; }
        _samplesSincePeak++;

        // Track lowest point since last peak
        if (absDev < _lowestSincePeak) {
            _lowestSincePeak = absDev;
        }

        // When we see a new peak
        if (absDev > _learnedPeakThreshold) {
            // Check: was there a valid valley since last peak, and enough time passed?
            if (_peakSeen) {
                if (_lowestSincePeak < _learnedReturnThreshold) {
                    if (_samplesSincePeak > 10) {
                        _repCount++;
                        _view.addRep();
                    }
                }
            }
            _peakSeen = true;
            _lowestSincePeak = absDev;
            _samplesSincePeak = 0;
        }
    }

    function getRepCount() as Number {
        return _repCount;
    }

    function getCountCallCount() as Number {
        return _countCallCount;
    }

    private function detectSetRest() as Void {
        if (!_view.isAutoDetectEnabled()) { return; }
        if (!_autoEnabled) { return; }
        if (_varianceHistory.size() < VAR_HISTORY_SIZE) { return; }

        var avgVar = 0.0;
        for (var i = 0; i < _varianceHistory.size(); i++) {
            avgVar += _varianceHistory[i];
        }
        avgVar = avgVar / _varianceHistory.size();

        // Use learned thresholds with a margin
        // Rest threshold: midpoint between learned rest and active, biased toward rest
        var restThresh = _restVariance + (_activeVariance - _restVariance) * 0.25;
        // Active threshold: midpoint biased toward active
        var activeThresh = _restVariance + (_activeVariance - _restVariance) * 0.75;

        if (avgVar < restThresh) {
            _stillCount++;
            _moveCount = 0;
            if (_stillCount >= STILL_FRAMES_NEEDED) {
                _view.onAutoRestDetected();
                _stillCount = 0;
            }
        } else if (avgVar > activeThresh) {
            _moveCount++;
            _stillCount = 0;
            if (_moveCount >= MOVE_FRAMES_NEEDED) {
                _view.onAutoSetDetected();
                _moveCount = 0;
            }
        } else {
            if (_stillCount > 0) { _stillCount--; }
            if (_moveCount > 0) { _moveCount--; }
        }
    }
}
