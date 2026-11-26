.pragma library
// Session decisions for a symbol, from the trading periods Yahoo returns in the quote
// metadata. Everything takes the session record and "now" as arguments, so the caller
// (which owns the clock and the per-symbol cache) stays responsible for reactivity.

// "open", "pre", "post" or "closed" for the exchange the symbol trades on. Crypto has
// no closing time.
function status(session, nowSec) {
    if (!session) return "";
    if (session.crypto) return "open";
    if (session.regular && nowSec >= session.regular.start && nowSec < session.regular.end) return "open";
    if (session.pre && nowSec >= session.pre.start && nowSec < session.pre.end) return "pre";
    if (session.post && nowSec >= session.post.start && nowSec < session.post.end) return "post";
    return "closed";
}

// True when the instrument's market is closed: outside every session, or in a pre/post
// window for an instrument that has no extended-hours trading at all (indices, for
// example). Unknown symbols are not marked closed.
function isClosed(session, statusValue) {
    if (!session) return false;
    if (statusValue === "closed") return true;
    return !session.hasPrePost && (statusValue === "pre" || statusValue === "post");
}

// True while the regular session has started but its first quote has not arrived.
// Yahoo keeps returning the previous close, with its old timestamp, until the first
// trade of the new session reaches the feed.
function awaitingFirstRegularQuote(session, nowSec) {
    if (!session || !session.regular) return false;
    if (nowSec < session.regular.start || nowSec >= session.regular.end) return false;
    return !(session.quoteTime > 0) || session.quoteTime < session.regular.start;
}

// The next regular-session boundary worth announcing: the close while the regular
// session runs, the open whenever it does not. Returns { kind, at } with `at` in epoch
// seconds, or null when there is nothing to announce (crypto has no closing time, and a
// symbol without session metadata has no times at all).
function nextBoundary(session, statusValue, nowSec) {
    if (!session || !session.regular) return null;
    if (session.crypto) return null;
    if (statusValue === "open") {
        var end = Number(session.regular.end) || 0;
        return end > nowSec ? { kind: "close", at: end } : null;
    }
    var start = nextRegularStart(session, nowSec);
    return start > 0 ? { kind: "open", at: start } : null;
}

// The next regular open after `nowSec`, in epoch seconds.
function nextRegularStart(session, nowSec) {
    return nextStart(session.regular, Number(session.offset) || 0, nowSec);
}

// The extended-session boundary to show beside the regular one: the end of the running
// after-hours session, or the next pre-market open while the market is closed. Only
// exchanges that report extended-hours windows have these, so indices and other
// instruments without them have nothing to announce.
function nextExtendedBoundary(session, statusValue, nowSec) {
    if (!session || !session.hasPrePost) return null;
    if (session.crypto) return null;
    if (statusValue === "post") {
        var end = session.post ? Number(session.post.end) || 0 : 0;
        return end > nowSec ? { kind: "afterHoursEnd", at: end } : null;
    }
    if (statusValue !== "closed") return null;
    var start = nextStart(session.pre, Number(session.offset) || 0, nowSec);
    return start > 0 ? { kind: "preOpen", at: start } : null;
}

// The next start of `period` after `nowSec`, in epoch seconds. The session metadata
// comes from the exchange's current trading day, which stays that day through its
// after-hours part; a start already in the past is projected onto the following
// weekday at the same exchange-local clock time. Weekends are skipped in the exchange's
// calendar (via its own UTC offset), not the user's, so a far-east session is not
// mistaken for a weekday that has no session. Exchange holidays are unknown here; the
// next quote refreshes the metadata and moves it to the real next session.
function nextStart(period, offset, nowSec) {
    if (!period || !(period.start > 0)) return 0;
    if (period.start > nowSec) return period.start;
    var timeOfDay = ((period.start + offset) % 86400 + 86400) % 86400;
    var nowLocal = nowSec + offset;
    var day = Math.floor(nowLocal / 86400);
    for (var i = 0; i <= 8; i++) {
        var candidateDay = day + i;
        var candidate = candidateDay * 86400 + timeOfDay;
        if (candidate <= nowLocal) continue;
        // 1970-01-01 was a Thursday, so adding 3 makes Monday 0.
        var weekday = ((candidateDay + 3) % 7 + 7) % 7;
        if (weekday === 5 || weekday === 6) continue;   // Saturday, Sunday
        return candidate - offset;
    }
    return 0;
}
