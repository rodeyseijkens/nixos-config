// Unit tests for the pure shell lib (Services/Lib.qml) — run headless via
// the qtdeclarative `qml` runner: `nix develop test -c qml-test`. The tests
// cross the same interface callers do; expected values are hand-computed.
import "../../modules/home/quickshell/config/Services"

QtObject {
  Component.onCompleted: {
    var failures = 0;
    function expect(name, actual, expected) {
      if (actual !== expected) {
        failures++;
        console.log("FAIL " + name + " — got [" + actual + "] want [" + expected + "]");
      }
    }

    var now = new Date(2026, 9, 1, 12, 0, 0);

    // relTime — NotifServer semantics: <60 "now", <3600 "Nm", <86400 "Nh", else "Nd"
    expect("relTime same instant", Lib.relTime(now, now), "now");
    expect("relTime 59s", Lib.relTime(new Date(now.getTime() - 59 * 1000), now), "now");
    expect("relTime 60s", Lib.relTime(new Date(now.getTime() - 60 * 1000), now), "1m");
    expect("relTime 59m", Lib.relTime(new Date(now.getTime() - 59 * 60 * 1000), now), "59m");
    expect("relTime 60m", Lib.relTime(new Date(now.getTime() - 3600 * 1000), now), "1h");
    expect("relTime 23h", Lib.relTime(new Date(now.getTime() - 23 * 3600 * 1000), now), "23h");
    expect("relTime 24h", Lib.relTime(new Date(now.getTime() - 86400 * 1000), now), "1d");
    expect("relTime no receipt", Lib.relTime(null, now), "");
    expect("relTime no now", Lib.relTime(now, null), "");

    // calendarCells — October 2026 starts on a Thursday: Mon-first lead is 3
    var oct = Lib.calendarCells(2026, 9);
    expect("oct lead blank", oct[0], 0);
    expect("oct lead blank2", oct[2], 0);
    expect("oct first day", oct[3], 1);
    expect("oct last day", oct[34], 31);
    expect("oct length", oct.length, 35);
    // February 2027: non-leap, starts on a Monday (lead 0), 28 days
    var feb = Lib.calendarCells(2027, 1);
    expect("feb first day", feb[0], 1);
    expect("feb last day", feb[27], 28);
    expect("feb length", feb.length, 28);
    // February 2024: leap year, 29 days, starts on a Thursday (lead 3)
    var leap = Lib.calendarCells(2024, 1);
    expect("leap first day", leap[3], 1);
    expect("leap last day", leap[32], 29);
    expect("leap length", leap.length, 32);

    // parseStats — synthetic /proc snapshot; totals are hand-computed so the
    // expected values are independent of the code under test.
    var snapA = "cpu0 100 0 0 40 0 0 0 0\n16106127360 8589934592\n2000000000 5000000000";
    var r1 = Lib.parseStats(snapA, 0, 0);
    expect("first cpu sentinel", r1.cpuPct, -1);
    expect("mem pct", r1.memPct, 50);
    expect("mem giB", r1.memUsedGiB, "8.0");
    expect("disk pct", r1.diskPct, 40);
    expect("prev total captured", r1.prevTotal, 140);
    // second sample: total 240 (delta 100), idle 90 (delta 50) → 50% cpu
    var snapB = "cpu0 150 0 0 90 0 0 0 0\n16106127360 8589934592\n2000000000 5000000000";
    var r2 = Lib.parseStats(snapB, r1.prevTotal, r1.prevIdle);
    expect("cpu pct delta", r2.cpuPct, 50);
    // degraded/short snapshot must not move any metric
    var r0 = Lib.parseStats("cpu0 1 2 3", 5, 5);
    expect("short cpu sentinel", r0.cpuPct, -1);
    expect("short mem sentinel", r0.memPct, -1);
    // zero totals are rejected rather than divided
    var rz = Lib.parseStats("cpu0 0 0 0 0 0 0 0 0\n0 0\n0 0", 0, 0);
    expect("zero mem sentinel", rz.memPct, -1);
    expect("zero disk sentinel", rz.diskPct, -1);

    // brightnessPct
    expect("brightness 25%", Lib.brightnessPct(250, 1000), 25);
    expect("brightness 0%", Lib.brightnessPct(0, 1000), 0);
    expect("brightness 100%", Lib.brightnessPct(1000, 1000), 100);

    if (failures === 0) {
      console.log("ALL PASSED");
    } else {
      console.log(failures + " FAILURES");
    }
  }
}
