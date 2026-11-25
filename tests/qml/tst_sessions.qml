import QtQuick
import QtTest
import "../../contents/ui/domain/sessions.js" as Sessions

TestCase {
    name: "Sessions"

    function test_status() {
        var session = { regular: { start: 100, end: 200 } };
        compare(Sessions.status(session, 150), "open");
        compare(Sessions.status(session, 250), "closed");
        compare(Sessions.status({ pre: { start: 50, end: 100 } }, 75), "pre");
        compare(Sessions.status({ post: { start: 200, end: 300 } }, 250), "post");
        compare(Sessions.status({ crypto: true }, 1), "open");
        compare(Sessions.status(null, 150), "");
    }

    function test_isClosed() {
        compare(Sessions.isClosed({ hasPrePost: true }, "pre"), false);
        compare(Sessions.isClosed({ hasPrePost: false }, "pre"), true);
        compare(Sessions.isClosed({ hasPrePost: false }, "post"), true);
        compare(Sessions.isClosed({ hasPrePost: true }, "closed"), true);
        compare(Sessions.isClosed(null, "closed"), false);
    }

    function test_awaitingFirstRegularQuote() {
        var session = { regular: { start: 100, end: 200 }, quoteTime: 50 };
        compare(Sessions.awaitingFirstRegularQuote(session, 150), true);
        compare(Sessions.awaitingFirstRegularQuote(session, 250), false);
        compare(Sessions.awaitingFirstRegularQuote({ regular: { start: 100, end: 200 },
                                                     quoteTime: 120 }, 150), false);
        compare(Sessions.awaitingFirstRegularQuote({ quoteTime: 120 }, 150), false);
        compare(Sessions.awaitingFirstRegularQuote(null, 150), false);
    }

    function test_nextBoundaryWhileOpen() {
        var session = { regular: { start: 1000, end: 2000 } };
        var boundary = Sessions.nextBoundary(session, "open", 1500);
        compare(boundary.kind, "close");
        compare(boundary.at, 2000);
        // The close has already passed; there is nothing stale to announce.
        compare(Sessions.nextBoundary(session, "open", 2500), null);
    }

    function test_nextBoundaryWhileClosed() {
        var session = { regular: { start: 1000, end: 2000 }, offset: 0 };
        var boundary = Sessions.nextBoundary(session, "pre", 500);
        compare(boundary.kind, "open");
        compare(boundary.at, 1000);
        // After 00:00 UTC on 1970-01-01 the open is projected onto the next weekday.
        boundary = Sessions.nextBoundary(session, "closed", 2500);
        compare(boundary.kind, "open");
        compare(boundary.at, 87400); // Friday 01:00 UTC
    }

    function test_nextBoundaryWithoutSessions() {
        compare(Sessions.nextBoundary(null, "closed", 1000), null);
        compare(Sessions.nextBoundary({ crypto: true,
                                        regular: { start: 1000, end: 2000 } }, "open", 1500), null);
        compare(Sessions.nextBoundary({ regular: null }, "closed", 1500), null);
    }

    function test_nextOpenProjectsTheExchangeWeekday() {
        // INTC, Wednesday 2026-11-25: 09:30-16:00 New York (EST).
        var start = 1795617000;   // 14:30 UTC
        var end = 1795640400;     // 21:00 UTC
        var session = { regular: { start: start, end: end }, offset: -18000 };

        // After the close the metadata still describes today, so the next open is
        // Thursday at the same exchange-local time.
        var boundary = Sessions.nextBoundary(session, "post", end + 3600);
        compare(boundary.kind, "open");
        compare(boundary.at, start + 86400);

        // Stale metadata before Monday's open still points at today, not next Tuesday.
        var mondayStart = 1796049000; // 2026-11-30 14:30 UTC
        compare(Sessions.nextBoundary(session, "closed", mondayStart - 5400).at, mondayStart);
    }

    function test_nextOpenSkipsTheWeekend() {
        // Friday 2026-11-27, same New York session.
        var start = 1795789800;   // 14:30 UTC
        var end = 1795813200;     // 21:00 UTC
        var session = { regular: { start: start, end: end }, offset: -18000 };

        compare(Sessions.nextBoundary(session, "post", end + 3600).at, start + 3 * 86400);
        // Saturday, with Friday's metadata still in place.
        compare(Sessions.nextBoundary(session, "closed", start + 86400 - 5400).at,
                start + 3 * 86400);
    }
}
