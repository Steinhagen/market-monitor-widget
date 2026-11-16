.pragma library

function inExtendedSession(period, time, kind) {
    if (!period) return false;
    return time >= period.start && (kind === "post" ? time <= period.end : time < period.end);
}

// Parsing and aggregation for the Yahoo Finance chart response. Kept separate
// from main.qml so the quote/fetch workflow stays readable.

function tradingDays(meta) {
    function period(p) {
        if (p && p.length) p = p[0];
        return (p && p.start < p.end) ? p : null;
    }
    var days = [];
    var tp = meta ? meta.tradingPeriods : null;
    if (tp && tp.regular && tp.regular.length) {
        for (var i = 0; i < tp.regular.length; i++) {
            days.push({
                pre: tp.pre ? period(tp.pre[i]) : null,
                regular: period(tp.regular[i]),
                post: tp.post ? period(tp.post[i]) : null
            });
        }
    } else if (tp && tp.length) {
        for (var j = 0; j < tp.length; j++) days.push({ pre: null, regular: period(tp[j]), post: null });
    } else if (meta && meta.currentTradingPeriod) {
        var c = meta.currentTradingPeriod;
        days.push({ pre: period(c.pre), regular: period(c.regular), post: period(c.post) });
    }
    return days;
}
// Latest trading day whose regular session has at least one data point, or null.
function displayedDay(meta, timestamps) {
    if (!timestamps) return null;
    var days = tradingDays(meta);
    for (var d = days.length - 1; d >= 0; d--) {
        var reg = days[d].regular;
        if (!reg) continue;
        for (var i = 0; i < timestamps.length; i++) {
            if (timestamps[i] >= reg.start && timestamps[i] < reg.end) return days[d];
        }
    }
    return null;
}
// The session a 1D chart plots. Normally the latest completed regular session, but
// while the current pre-market is running (or before the first regular candle of the
// day arrives) its points are plotted instead, so the chart follows today's quote the
// same way a regular session does on exchanges without extended hours. Falls back to
// the regular session until the pre-market has a close, so the chart is never empty.
function chartDayFor(meta, timestamps, quotes) {
    var day = displayedDay(meta, timestamps);
    var periods = meta ? meta.currentTradingPeriod : null;
    if (!periods || !timestamps || !quotes) return day;
    // The current regular session is already on screen; keep the full-day chart.
    if (day && day.regular && periods.regular && day.regular.start === periods.regular.start)
        return day;
    var pre = periods.pre;
    if (!pre || !(pre.start < pre.end)) return day;
    for (var i = 0; i < timestamps.length; i++) {
        if (timestamps[i] >= pre.start && timestamps[i] < pre.end
                && quotes[i] !== null && quotes[i] !== undefined)
            return { pre: null, regular: pre, post: null };
    }
    return day;
}
// True when `day` is the running pre-market, i.e. the session chartDayFor substituted
// for the regular one. The pre period must be non-empty: exchanges without extended
// hours (BVB, for example) report an empty pre period that starts at the regular open,
// and that must not turn the regular session into a pre-market one.
function isPreSessionDay(meta, day) {
    var periods = meta ? meta.currentTradingPeriod : null;
    var pre = periods ? periods.pre : null;
    return !!(day && day.regular && pre && pre.start < pre.end
              && day.regular.start === pre.start
              && day.regular.end === pre.end);
}
// Pre-market and after-hours closes of `day`, or null when neither has any point.
function extendedSessionSeries(quotes, timestamps, day) {
    var preTimes = [], preValues = [], postTimes = [], postValues = [];
    for (var i = 0; i < quotes.length; i++) {
        var v = quotes[i], t = timestamps[i];
        if (v === null || v === undefined) continue;
        if (day.pre && inExtendedSession(day.pre, t, "pre")) { preTimes.push(t); preValues.push(v); }
        else if (day.post && inExtendedSession(day.post, t, "post")) { postTimes.push(t); postValues.push(v); }
    }
    if (preValues.length === 0 && postValues.length === 0) return null;
    return {
        preTimes: preTimes, preValues: preValues,
        postTimes: postTimes, postValues: postValues,
        regStart: day.regular.start, regEnd: day.regular.end,
        preStart: day.pre ? day.pre.start : 0,
        postEnd: day.post ? day.post.end : 0
    };
}
function cleanChartData(quotes, timestamps, startTime, range, quote, day) {
    var chartRange = range;
    var q = quote || {};
    var opens = q.open || null;
    var highs = q.high || null;
    var lows = q.low || null;
    var volumes = q.volume || null;
    var values = [], times = [], outOpens = [], outHighs = [], outLows = [], outVolumes = [];
    if (!quotes) return { values: values, times: times, opens: outOpens, highs: outHighs, lows: outLows, volumes: outVolumes };

    function addPoint(i) {
        var close = quotes[i];
        if (close === null || close === undefined) return;
        values.push(close);
        times.push(timestamps ? timestamps[i] : 0);
        outOpens.push(opens && opens[i] !== null && opens[i] !== undefined ? opens[i] : close);
        outHighs.push(highs && highs[i] !== null && highs[i] !== undefined ? highs[i] : close);
        outLows.push(lows && lows[i] !== null && lows[i] !== undefined ? lows[i] : close);
        outVolumes.push(volumes && volumes[i] !== null && volumes[i] !== undefined ? volumes[i] : 0);
    }

    var bounded = chartRange === "1D" && day && day.regular && timestamps;
    for (var i = 0; i < quotes.length; i++) {
        if (bounded) {
            // Extended-hours points are requested but belong to chartSessions, not here.
            if (timestamps[i] < day.regular.start || timestamps[i] >= day.regular.end) continue;
        } else if (chartRange === "1D" && startTime > 0 && timestamps && timestamps[i] < startTime)
            continue;
        addPoint(i);
    }

    if (!bounded && chartRange === "1D" && values.length === 0 && timestamps && timestamps.length > 0) {
        var dayStartIndex = 0;
        for (var j = timestamps.length - 1; j > 0; j--) {
            if (timestamps[j] - timestamps[j-1] > 4 * 3600) {
                dayStartIndex = j;
                break;
            }
        }
        for (var k = dayStartIndex; k < quotes.length; k++) addPoint(k);
    }
    return { values: values, times: times, opens: outOpens, highs: outHighs, lows: outLows, volumes: outVolumes };
}

// A session starts with a single tick before the next candle arrives. A one-point
// series cannot be drawn (the canvas needs two points), so the chart went blank
// between the first quote of the day and the second candle. Start the day's line at
// the previous close instead: the card then shows the move since yesterday from the
// first tick, and draws itself normally once the next candle arrives.
function seedFirstSessionPoint(chart, dayStart, meta) {
    if (!chart || !chart.values || chart.values.length !== 1) return;
    if (!chart.times || chart.times.length !== 1 || !(chart.times[0] > 0)) return;
    var dayTime = (dayStart > 0 && dayStart < chart.times[0]) ? dayStart : chart.times[0];
    var seed = dailyPreviousClose(meta, chart.values[0], "1D");
    if (!(seed > 0)) seed = chart.values[0];
    chart.values.unshift(seed);
    chart.times.unshift(dayTime);
    chart.opens.unshift(seed);
    chart.highs.unshift(seed);
    chart.lows.unshift(seed);
    chart.volumes.unshift(0);
}

// Yesterday's close for the daily change. Yahoo's FX feed carries a stale
// `previousClose` (EURRON=X reported 5.3013 for a day whose real close was 5.3418),
// but the 2-day chart's `chartPreviousClose` is the last completed daily close. Use
// that for currencies; the other instrument types keep Yahoo's `previousClose`, which
// is the correct one for them and differs from `chartPreviousClose` (that one points
// one day further back in the 2-day window).
function previousCloseFor(meta, range) {
    if (!meta) return 0;
    if (range === "1D" && String(meta.instrumentType) === "CURRENCY") {
        var fx = Number(meta.chartPreviousClose);
        if (fx > 0) return fx;
    }
    var prev = Number(meta.regularMarketPreviousClose);
    if (prev > 0) return prev;
    prev = Number(meta.previousClose);
    if (prev > 0) return prev;
    prev = Number(meta.chartPreviousClose);
    return prev > 0 ? prev : 0;
}

// The last close of a completed day in a daily-series reply. The current day's bar
// (when Yahoo includes it) starts at currentTradingPeriod.regular.start, so skip it
// and take the bar before it. Used for FX, whose intraday meta carries a stale
// previousClose; the daily bars are the source of the real close (EURRON=X:
// 5.3013 intraday vs 5.3418 as the daily bar).
function lastCompletedDailyClose(json) {
    var result = json && json.chart && json.chart.result && json.chart.result[0];
    if (!result) return 0;
    var times = result.timestamp || [];
    var quote = result.indicators && result.indicators.quote
                ? result.indicators.quote[0] : null;
    var closes = quote ? quote.close : null;
    if (!closes) return 0;
    var current = result.meta && result.meta.currentTradingPeriod
                  && result.meta.currentTradingPeriod.regular
                  ? Number(result.meta.currentTradingPeriod.regular.start) : 0;
    for (var i = Math.min(times.length, closes.length) - 1; i >= 0; i--) {
        if (current > 0 && Number(times[i]) >= current) continue;
        var close = Number(closes[i]);
        if (closes[i] !== null && closes[i] !== undefined && isFinite(close) && close > 0)
            return close;
    }
    return 0;
}

// Yesterday's close, independent of the chart range. Yahoo sends `previousClose` only
// for the 1D range; longer ranges still carry the day's change, so derive it from
// regularMarketPrice - fulldayChange (or from the change percentage). `range` is
// optional so the existing callers and tests keep their old behaviour.
function dailyPreviousClose(meta, fallback, range) {
    if (meta) {
        if (range === "1D") {
            var close = previousCloseFor(meta, range);
            if (close > 0) return close;
        }
        var prev = meta.regularMarketPreviousClose || meta.previousClose || 0;
        if (prev > 0) return prev;
        // `fulldayChange` is the most precise day change, but it can follow an
        // after-hours price; only use it while it still refers to the regular price.
        var regular = meta.regularMarketPrice;
        var fullDay = meta.fulldayPrice;
        if (regular > 0 && typeof meta.fulldayChange === "number"
                && (!(fullDay > 0) || Math.abs(fullDay - regular) < 0.005))
            return regular - meta.fulldayChange;
        if (regular > 0 && typeof meta.regularMarketChangePercent === "number"
                && meta.regularMarketChangePercent > -100)
            return regular / (1 + meta.regularMarketChangePercent / 100);
    }
    return fallback > 0 ? fallback : 0;
}
