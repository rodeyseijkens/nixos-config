pragma Singleton
import QtQml

// Pure logic shared across the shell, importable without a running shell —
// the tests exercise exactly this module (the interface is the test surface).
// No Quickshell imports here: `qml test/qml-tests/run.qml` runs it headless.
QtObject {
  // relTime: "now", "5m", "3h", "2d" — the age of a received notification
  // (NotifServer wraps its receivedAt/now state around this core).
  function relTime(then: var, now: var): string {
    if (!then || !now)
      return "";
    var secs = Math.floor((now.getTime() - then.getTime()) / 1000);
    if (secs < 60)
      return "now";
    if (secs < 3600)
      return Math.floor(secs / 60) + "m";
    if (secs < 86400)
      return Math.floor(secs / 3600) + "h";
    return Math.floor(secs / 86400) + "d";
  }

  // calendarCells: Monday-first month grid; 0 = blank lead cell.
  function calendarCells(year: int, month: int): var {
    var first = new Date(year, month, 1);
    var lead = (first.getDay() + 6) % 7;
    var days = new Date(year, month + 1, 0).getDate();
    var cells = [];
    for (var i = 0; i < lead; i++)
      cells.push(0);
    for (var d = 1; d <= days; d++)
      cells.push(d);
    return cells;
  }

  // parseStats: turns the combined /proc snapshot (grep 'cpu ' /proc/stat,
  // free's Mem line, df's used/total line) into display values. cpuPct is a
  // delta against the previous sample: -1 means not enough samples yet and
  // -1 for any metric means keep the previous value. Returns updated prev
  // totals for the caller to feed back on the next read.
  function parseStats(text: string, prevTotal: real, prevIdle: real): var {
    var lines = text.trim().split("\n");
    var out = { cpuPct: -1, memPct: -1, memUsedGiB: "", diskPct: -1, prevTotal: prevTotal, prevIdle: prevIdle };
    if (lines.length < 3)
      return out;
    var c = lines[0].split(/\s+/);
    var idle = parseFloat(c[4]) + parseFloat(c[5]);
    var total = c.slice(1).reduce((a, b) => a + parseFloat(b), 0);
    if (prevTotal > 0) {
      var dTotal = total - prevTotal;
      var dIdle = idle - prevIdle;
      if (dTotal > 0)
        out.cpuPct = Math.round((1 - dIdle / dTotal) * 100);
    }
    out.prevTotal = total;
    out.prevIdle = idle;
    var m = lines[1].split(/\s+/);
    var memTotal = parseFloat(m[0]);
    var memUsed = parseFloat(m[1]);
    if (memTotal > 0) {
      out.memPct = Math.round(memUsed / memTotal * 100);
      out.memUsedGiB = (memUsed / 1024 / 1024 / 1024).toFixed(1);
    }
    var d = lines[2].split(/\s+/);
    var diskUsed = parseFloat(d[0]);
    var diskTotal = parseFloat(d[1]);
    if (diskTotal > 0)
      out.diskPct = Math.round(diskUsed / diskTotal * 100);
    return out;
  }

  // brightnessPct: device value and max (brightnessctl get; max) → 0–100.
  function brightnessPct(cur: real, max: real): int {
    return max > 0 ? Math.round(cur / max * 100) : 0;
  }
}
