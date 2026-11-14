"""Edits to one event inside a caldir .ics file.

caldir keeps each event as an iCalendar file and pushes changes made to the
file. An edit here changes only the properties the panel can show. Everything
else in the file (attendees, the organiser, properties this module does not
know, the VTIMEZONE blocks) is kept as caldir wrote it.

Lines are unfolded on read and folded again on write, so the text is edited
one logical line at a time. Pure functions on text, so every rule is testable
without caldir or a file.
"""

import re
from datetime import date, datetime, timezone

LINE_OCTETS = 75
REMINDER_DESCRIPTION = "Reminder"


class IcsError(ValueError):
    """The file has no event this module can edit."""


def _eol(text):
    return "\r\n" if "\r\n" in text else "\n"


def _unfolded(text):
    """Logical lines: a line that starts with a space or tab continues the one before."""
    lines = []
    for raw in text.split(_eol(text)):
        if raw == "":
            continue
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def _name(line):
    return re.split(r"[;:]", line, maxsplit=1)[0].upper()


def _value(line):
    return line.split(":", 1)[1] if ":" in line else ""


def _event_span(lines):
    """Indexes of the first VEVENT's BEGIN and END lines."""
    for start, line in enumerate(lines):
        if line.upper() != "BEGIN:VEVENT":
            continue
        depth = 0
        for end in range(start, len(lines)):
            upper = lines[end].upper()
            if upper.startswith("BEGIN:"):
                depth += 1
            elif upper.startswith("END:"):
                depth -= 1
                if depth == 0:
                    return start, end
    raise IcsError("the file has no event")


def _children(lines, start, end):
    """The VEVENT's direct children: ("prop", name, line) or ("block", name, lines)."""
    items = []
    index = start + 1
    while index < end:
        line = lines[index]
        if line.upper().startswith("BEGIN:"):
            depth = 0
            close = index
            while True:
                upper = lines[close].upper()
                if upper.startswith("BEGIN:"):
                    depth += 1
                elif upper.startswith("END:"):
                    depth -= 1
                if depth == 0:
                    break
                close += 1
            items.append(("block", _value(line).upper(), lines[index:close + 1]))
            index = close + 1
        else:
            items.append(("prop", _name(line), line))
            index += 1
    return items


def _fold(line):
    """One logical line as physical lines of at most 75 octets each."""
    out, current, size, limit = [], "", 0, LINE_OCTETS
    for char in line:
        width = len(char.encode("utf-8"))
        if size + width > limit:
            out.append(current)
            current, size = " " + char, 1 + width
        else:
            current, size = current + char, size + width
        limit = LINE_OCTETS
    out.append(current)
    return out


def escape_text(value):
    """A value as iCalendar text: backslashes, separators and newlines escaped."""
    return (
        str(value)
        .replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\r\n", "\n")
        .replace("\n", "\\n")
    )


def utc_stamp(moment, tz):
    """A datetime as the UTC form iCalendar writes. Naive times are read in tz."""
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=tz)
    return moment.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def time_line(name, node, tz):
    """DTSTART or DTEND as a content line, from a Google start or end node.

    All-day values are dates. Timed values are written in UTC, which needs no
    VTIMEZONE block and names the same instant.
    """
    if "date" in node:
        day = date.fromisoformat(node["date"])
        return "%s;VALUE=DATE:%s" % (name, day.strftime("%Y%m%d"))
    return "%s:%s" % (name, utc_stamp(datetime.fromisoformat(node["dateTime"]), tz))


def _alarm(minutes):
    return [
        "BEGIN:VALARM",
        "ACTION:DISPLAY",
        "DESCRIPTION:" + REMINDER_DESCRIPTION,
        "TRIGGER;RELATED=START:-PT%dM" % minutes,
        "END:VALARM",
    ]


def update_event(text, *, props=None, alarms=None, default_reminders=None, now=None):
    """The file with its first event changed.

    props maps a property name to the content line that replaces its direct
    properties, or to None to remove them. alarms, when given, replaces every
    reminder with one per minute before the start. default_reminders sets or
    clears Google's flag that the calendar's default reminders apply. now, an
    iCalendar UTC stamp, refreshes LAST-MODIFIED if the event has one.
    """
    lines = _unfolded(text)
    start, end = _event_span(lines)
    children = _children(lines, start, end)

    for name, line in (props or {}).items():
        children = [c for c in children if not (c[0] == "prop" and c[1] == name)]
        if line is not None:
            children.append(("prop", name, line))

    if alarms is not None:
        children = [c for c in children if not (c[0] == "block" and c[1] == "VALARM")]
        children.extend(("block", "VALARM", _alarm(minutes)) for minutes in alarms)

    if default_reminders is not None:
        name = "X-GOOGLE-DEFAULT-REMINDERS"
        children = [c for c in children if not (c[0] == "prop" and c[1] == name)]
        if default_reminders:
            children.append(("prop", name, name + ":TRUE"))

    if now is not None:
        children = [
            ("prop", "LAST-MODIFIED", "LAST-MODIFIED:" + now)
            if c[0] == "prop" and c[1] == "LAST-MODIFIED" else c
            for c in children
        ]

    rebuilt = [lines[start]]
    for item in children:
        if item[0] == "prop":
            rebuilt.append(item[2])
        else:
            rebuilt.extend(item[2])
    rebuilt.append(lines[end])
    rebuilt = lines[:start] + rebuilt + lines[end + 1:]

    eol = _eol(text)
    return eol.join(part for line in rebuilt for part in _fold(line)) + eol


def first_event_props(text):
    """The direct properties of the first event, as (name, logical line) pairs."""
    lines = _unfolded(text)
    start, end = _event_span(lines)
    return [(c[1], c[2]) for c in _children(lines, start, end) if c[0] == "prop"]


def is_repeating(text):
    """True when the first event repeats, or is one occurrence of a series."""
    return any(name in ("RRULE", "RDATE", "RECURRENCE-ID") for name, _line in first_event_props(text))


def event_uid(text):
    """The UID of the first event, or "" when it has none."""
    for name, line in first_event_props(text):
        if name == "UID":
            return _value(line)
    return ""


def file_name(start, title, tz):
    """caldir's name for an event: its start, then its title as a slug.

    Timed events show their start in local time, to the minute. All-day
    events show their date only.
    """
    if isinstance(start, datetime):
        stamp = start.astimezone(tz).strftime("%Y-%m-%dT%H%M")
    else:
        stamp = start.isoformat()
    slug = re.sub(r"[^a-z0-9]+", "-", str(title).lower()).strip("-") or "event"
    return "%s__%s.ics" % (stamp, slug)
