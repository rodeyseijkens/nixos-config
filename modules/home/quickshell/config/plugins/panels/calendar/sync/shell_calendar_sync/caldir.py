"""caldir as a calendar source, and as the place the panel's changes go.

caldir (https://caldir.org) keeps calendars as plain .ics files on disk and
syncs them with Google, iCloud and CalDAV through its own providers. Someone
who already uses it has signed in once there, so this backend needs no Google
Cloud project, no OAuth client and no second sign-in: it asks the caldir CLI
for its calendars and events as JSON.

Writes edit the event's .ics file (see ics_edit), then `caldir push` sends
that calendar's changes to the provider. If the push fails, the file goes
back to what it was, so no half-made change stays pending.

Like the rest of the sync, this emits Google event resources (see resources.py)
rather than contract rows.
"""

import json
import os
import re
import subprocess
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from . import budget, ics_edit
from .errors import EventNotFound, SyncError
from .resources import build_event

FALLBACK_COLOR = "#9e9e9e"

# What the event form offers that caldir cannot store yet. The panel hides
# these for a calendar, and a save that still asks for one is refused.
LACKS = ["guests", "meet", "color", "repeat"]

_VERSION = re.compile(r"(\d+)\.(\d+)\.(\d+)")
_ANSI = re.compile(r"\x1b\[[0-9;]*m")
_CREATED = re.compile(r"Created: (.+?\.ics)")
# An event id is its UID, plus the start of the occurrence when the sync
# wrote one. A UID can hold colons, so the start is matched from the end.
_EVENT_ID = re.compile(r"^(?P<uid>.+?)(?::(?P<start>\d{4}-\d{2}-\d{2}(?:T.*)?))?$")

REPEATING = "caldir cannot change a repeating event yet. Edit it in caldir."


class CaldirError(SyncError):
    """caldir could not be read or changed."""


class CaldirMissing(CaldirError):
    """The caldir binary is not installed or not on PATH."""


def _subprocess_runner(argv):
    # stdin is closed: a caldir command that asks a question must fail, not wait.
    completed = subprocess.run(
        argv, capture_output=True, text=True, timeout=budget.HELPER_SECONDS,
        stdin=subprocess.DEVNULL, preexec_fn=budget.uncap_memory,
    )
    return completed.returncode, completed.stdout, completed.stderr


def time_to_node(value, all_day):
    """A caldir start or end as a Google start/end node.

    caldir writes all-day times as a bare date and timed ones with an offset.
    A timed value without one is refused rather than guessed, as normalize
    would refuse it anyway.
    """
    if not value:
        return None
    if all_day:
        return {"date": str(value)[:10]}
    parsed = datetime.fromisoformat(str(value))
    if parsed.tzinfo is None:
        raise CaldirError("caldir returned a time without an offset: %r" % value)
    return {"dateTime": parsed.isoformat()}


def event_type(raw):
    """Google's event type (workingLocation, outOfOffice, focusTime), if any."""
    for prop in raw.get("x_properties") or []:
        if str(prop.get("name") or "").upper() == "X-GOOGLE-EVENT-TYPE":
            return str(prop.get("value") or "")
    return ""


def conference_url(raw):
    """The meeting link. caldir puts Google's conference link in `url`."""
    for prop in raw.get("x_properties") or []:
        if str(prop.get("name") or "").upper() == "X-GOOGLE-CONFERENCE":
            return str(prop.get("value") or "")
    return str(raw.get("url") or "")


def reminder_minutes(raw):
    minutes = []
    for reminder in raw.get("reminders") or []:
        value = reminder.get("minutes_before_start")
        if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
            minutes.append(value)
    return sorted(set(minutes))


def to_event(raw):
    """One caldir event as a Google event resource."""
    all_day = raw.get("all_day") is True
    event = build_event(
        uid=str(raw.get("uid") or raw.get("instance_id") or ""),
        start_node=time_to_node(raw.get("start"), all_day),
        end_node=time_to_node(raw.get("end"), all_day),
        summary=raw.get("title") or raw.get("summary") or "",
        location=raw.get("location") or "",
        description=raw.get("description") or "",
        status=raw.get("status") or "",
        conference_url=conference_url(raw),
        # caldir already answers for the account that owns the calendar.
        partstat=raw.get("rsvp") or "",
        reminders=reminder_minutes(raw),
    )
    kind = event_type(raw)
    if kind:
        event["eventType"] = kind
    return event


def split_event_id(event_id):
    """(uid, start) of a sync row id. The start is "" when the id has none."""
    match = _EVENT_ID.match(str(event_id or ""))
    if not match:
        raise EventNotFound("The event id %r is not one this calendar makes." % event_id)
    return match.group("uid"), match.group("start") or ""


def _local_date(rfc3339):
    return datetime.fromisoformat(rfc3339).astimezone().date()


def _day_of(start):
    try:
        return date.fromisoformat(str(start)[:10])
    except ValueError:
        return date.today()


def _optional_line(name, value):
    """A text property, or None (removed) when the value is blank."""
    if value in (None, ""):
        return None
    return "%s:%s" % (name, ics_edit.escape_text(value))


class Caldir:
    """A calendar client backed by the caldir CLI.

    Presents the same surface as the sync needs -- check, version, calendars,
    events -- and the four writes, so cli.run and event_cli drive it directly.
    """

    SOURCE_NAME = "caldir"

    can_write = True

    def __init__(self, binary="caldir", pull=True, runner=None, tz=None):
        self.binary = binary
        self._pull = pull
        self._runner = runner or _subprocess_runner
        self._pulled = False
        self._dir = None
        self.tz = tz or datetime.now().astimezone().tzinfo

    def _run(self, args):
        try:
            return self._runner([os.path.expanduser(self.binary), *args])
        except subprocess.TimeoutExpired as error:
            raise CaldirError("%s did not answer in %d s" % (self.binary, budget.HELPER_SECONDS)) from error
        except FileNotFoundError as error:
            raise CaldirMissing(
                "%s is not installed or not on PATH. A systemd user service "
                "does not inherit your shell PATH, so set caldirPath to an "
                "absolute path in calendar-sync.json." % self.binary
            ) from error

    def _json(self, args):
        code, stdout, stderr = self._run(["--json", *args])
        if code != 0:
            excerpt = stderr.strip()[:200] or "no stderr output"
            raise CaldirError("caldir %s failed (exit %d): %s" % (args[0], code, excerpt))
        try:
            return json.loads(stdout)
        except json.JSONDecodeError as error:
            raise CaldirError("caldir %s returned invalid JSON: %s" % (args[0], error))

    def version(self):
        code, stdout, stderr = self._run(["--version"])
        match = _VERSION.search(stdout)
        if not match:
            excerpt = stderr.strip()[:200] or "no stderr output"
            raise CaldirError(
                "cannot parse caldir version from %r (exit %d: %s)" % (stdout, code, excerpt)
            )
        return tuple(int(part) for part in match.groups())

    def check(self):
        self.version()

    def _default_calendar(self):
        try:
            payload = self._json(["config"])
        except CaldirError:
            return ""
        return str((payload.get("config") or {}).get("default_calendar") or "")

    def calendars(self):
        """caldir's calendars, pulled from their providers first if asked.

        The pull belongs here rather than in events() so it runs once per sync
        instead of once per calendar. A failed pull is not fatal: the files
        caldir already has are still the best answer available.
        """
        if self._pull and not self._pulled:
            code, _stdout, stderr = self._run(["pull"])
            self._pulled = True
            if code != 0:
                print("caldir pull failed, using local copy: %s" % stderr.strip()[:200])

        primary = self._default_calendar()
        payload = self._json(["calendars"])
        if not isinstance(payload, list):
            raise CaldirError("caldir calendars must return a JSON array")

        calendars = []
        for item in payload:
            slug = str(item.get("slug") or "").strip()
            if not slug:
                continue
            calendars.append(
                {
                    "id": slug,
                    "name": str(item.get("name") or "").strip() or slug,
                    "color": item.get("color") or FALLBACK_COLOR,
                    "primary": slug == primary,
                    "writable": item.get("read_only") is False,
                    "lacks": list(LACKS),
                }
            )
        return sorted(calendars, key=lambda calendar: calendar["name"])

    def events(self, calendar_id, time_min, time_max):
        # caldir takes whole local dates. Ask for a day either side, then keep
        # only what overlaps the window, so no event is lost to a zone edge.
        first = _local_date(time_min) - timedelta(days=1)
        last = _local_date(time_max) + timedelta(days=1)
        payload = self._json(
            ["events", "--calendar", calendar_id,
             "--from", first.isoformat(), "--to", last.isoformat()]
        )
        if not isinstance(payload, list):
            raise CaldirError("caldir events must return a JSON array")

        window_start = datetime.fromisoformat(time_min)
        window_end = datetime.fromisoformat(time_max)
        events = []
        for raw in payload:
            event = to_event(raw)
            if _overlaps(event, window_start, window_end):
                events.append(event)
        return events

    def auth_hint(self, _cfg):
        return (
            "if this is an auth error, run `caldir status` in a terminal; "
            "`caldir connect` signs in to a provider again"
        )

    # ---- Reads for a write -------------------------------------------------

    def calendar_dir(self):
        """Where caldir keeps the calendars' folders (its calendar_dir setting)."""
        if self._dir is None:
            payload = self._json(["config"])
            folder = str((payload.get("config") or {}).get("calendar_dir") or "")
            if not folder:
                raise CaldirError("caldir did not say where its calendars are")
            self._dir = Path(os.path.expanduser(folder))
        return self._dir

    def _locate(self, calendar_id, uid):
        """The file that holds the event with this UID, in the calendar's folder."""
        for path in sorted((self.calendar_dir() / calendar_id).glob("*.ics")):
            try:
                if ics_edit.event_uid(path.read_bytes().decode("utf-8")) == uid:
                    return path
            except (ics_edit.IcsError, UnicodeDecodeError):
                continue
        raise EventNotFound("This event is no longer in caldir.")

    def _resource(self, calendar_id, uid, day, want_id=None):
        """The Google resource for one event, as the sync reads it.

        Looks a day either side of `day` first. An id can point at a day the
        event has since left (it was moved), so a miss searches a year around
        it before giving up.
        """
        for spread in (1, 366):
            found = self._search(calendar_id, uid, day - timedelta(days=spread), day + timedelta(days=spread), want_id)
            if found is not None:
                return found
        raise EventNotFound("This event is no longer in caldir.")

    def _search(self, calendar_id, uid, first, last, want_id):
        payload = self._json(
            ["events", "--calendar", calendar_id,
             "--from", first.isoformat(), "--to", last.isoformat()]
        )
        if not isinstance(payload, list):
            raise CaldirError("caldir events must return a JSON array")
        found = None
        for raw in payload:
            if str(raw.get("uid") or "") != uid:
                continue
            resource = to_event(raw)
            if want_id is None or resource["id"] == want_id:
                return resource
            found = found or resource
        return found

    def get(self, calendar_id, event_id):
        uid, start = split_event_id(event_id)
        return self._resource(calendar_id, uid, _day_of(start), event_id)

    # ---- Writes ------------------------------------------------------------

    def create(self, calendar_id, body, send_updates="none"):
        _refuse_unsupported(body, creating=True)
        start_node = body.get("start") or {}
        end_node = body.get("end") or start_node
        title = str(body.get("summary") or "") or "(no title)"

        args = ["new", "--calendar", calendar_id, "--no-reminders"]
        if "date" in start_node:
            args += ["--start", start_node["date"]]
        else:
            args += ["--start", self._local_stamp(start_node["dateTime"]),
                     "--end", self._local_stamp(end_node["dateTime"])]
        args += ["--", title]

        code, stdout, stderr = self._run(args)
        if code != 0:
            raise CaldirError("caldir could not make the event: %s" % (stderr or stdout).strip()[:200])
        match = _CREATED.search(_ANSI.sub("", stdout))
        if not match:
            raise CaldirError("caldir did not say which file it made")
        path = Path(match.group(1))

        try:
            original = path.read_bytes().decode("utf-8")
            uid = ics_edit.event_uid(original)
            text, final = self._edited(
                original, body, path, start_node, end_node, set_times=True,
                title=title,
            )
            path.write_bytes(text.encode("utf-8"))
            if final != path:
                os.replace(path, final)
            self._publish(calendar_id, undo=lambda: final.unlink(missing_ok=True))
        except BaseException:
            path.unlink(missing_ok=True)
            raise
        return self._resource(calendar_id, uid, _day_of(self._start_text(start_node)))

    def update(self, calendar_id, event_id, patch, send_updates="none"):
        uid, start = split_event_id(event_id)
        path = self._locate(calendar_id, uid)
        original = path.read_bytes().decode("utf-8")
        if ics_edit.is_repeating(original):
            raise CaldirError(REPEATING)
        _refuse_unsupported(patch, creating=False)

        current = self._resource(calendar_id, uid, _day_of(start), event_id)
        set_times = "start" in patch or "end" in patch
        start_node = patch.get("start", current.get("start")) or {}
        end_node = patch.get("end", current.get("end")) or start_node
        title = patch.get("summary", current.get("summary") or "")

        text, final = self._edited(
            original, patch, path, start_node, end_node, set_times=set_times, title=title,
        )
        path.write_bytes(text.encode("utf-8"))
        if final != path:
            os.replace(path, final)

        def undo():
            if final != path:
                os.replace(final, path)
            path.write_bytes(original.encode("utf-8"))

        self._publish(calendar_id, undo=undo)
        return self._resource(calendar_id, uid, _day_of(self._start_text(start_node)))

    def replace(self, calendar_id, event_id, whole, send_updates="none"):
        return self.update(calendar_id, event_id, whole, send_updates=send_updates)

    def delete(self, calendar_id, event_id, send_updates="none"):
        uid, _start = split_event_id(event_id)
        path = self._locate(calendar_id, uid)
        original = path.read_bytes().decode("utf-8")
        if ics_edit.is_repeating(original):
            raise CaldirError(REPEATING)
        path.unlink()
        self._publish(calendar_id, undo=lambda: path.write_bytes(original.encode("utf-8")))

    def _edited(self, original, fields, path, start_node, end_node, set_times, title):
        """The file's new text, and the name it should have now.

        fields holds the Google-shaped values the change sets. Times are
        written only when set_times is true, so an edit that leaves them alone
        leaves the file's own time text alone too. start_node and end_node are
        the event's times after the change, and name the file either way.
        """
        props = {}
        if "summary" in fields:
            props["SUMMARY"] = "SUMMARY:" + ics_edit.escape_text(fields["summary"] or "")
        if "location" in fields:
            props["LOCATION"] = _optional_line("LOCATION", fields["location"])
        if "description" in fields:
            props["DESCRIPTION"] = _optional_line("DESCRIPTION", fields["description"])
        if set_times:
            props["DTSTART"] = ics_edit.time_line("DTSTART", start_node, self.tz)
            props["DTEND"] = ics_edit.time_line("DTEND", end_node, self.tz)
            props["DURATION"] = None

        alarms = None
        default_reminders = None
        if "reminders" in fields:
            reminders = fields["reminders"] or {}
            if reminders.get("useDefault", True):
                alarms, default_reminders = [], True
            else:
                alarms = [int(o.get("minutes") or 0) for o in reminders.get("overrides") or []]
                default_reminders = False

        now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        text = ics_edit.update_event(
            original, props=props, alarms=alarms, default_reminders=default_reminders, now=now,
        )

        name = ics_edit.file_name(self._start_value(start_node), title, self.tz)
        final = path.with_name(name)
        if final != path and final.exists():
            final = path
        return text, final

    def _start_value(self, node):
        if "date" in node:
            return date.fromisoformat(node["date"])
        return datetime.fromisoformat(node["dateTime"])

    def _start_text(self, node):
        return node.get("date") or node["dateTime"]

    def _local_stamp(self, rfc3339):
        return datetime.fromisoformat(rfc3339).astimezone(self.tz).strftime("%Y-%m-%dT%H:%M")

    def _publish(self, calendar_id, undo):
        """Push the calendar. If that fails, undo puts the files back."""
        try:
            self._push(calendar_id)
        except CaldirError:
            undo()
            raise

    def _push(self, calendar_id):
        code, stdout, stderr = self._run(["push", "--calendar", calendar_id])
        if code != 0:
            excerpt = (stderr or stdout).strip()[:200] or "no output"
            raise CaldirError("Google did not accept the change, so it was not saved: %s" % excerpt)


def _refuse_unsupported(fields, creating):
    """Refuse a field caldir cannot store, instead of dropping it silently.

    An update sends only changed fields, and guests are never changed through
    the form (the calendar lacks them), so guests are checked on create only.
    """
    if creating and any(attendee.get("email") for attendee in fields.get("attendees") or []):
        raise CaldirError("caldir cannot store guests yet, so this event cannot be saved with them.")
    if fields.get("conferenceData"):
        raise CaldirError("caldir cannot add a Meet link yet.")
    if fields.get("colorId"):
        raise CaldirError("caldir cannot store event colours yet.")
    if fields.get("recurrence"):
        raise CaldirError(REPEATING)
    if fields.get("transparency") == "transparent":
        raise CaldirError("caldir cannot store the busy setting yet.")
    if fields.get("visibility") not in (None, "", "default"):
        raise CaldirError("caldir cannot store the visibility setting yet.")


def _instant(node):
    if not node:
        return None
    if "dateTime" in node:
        return datetime.fromisoformat(node["dateTime"])
    day = date.fromisoformat(node["date"])
    return datetime.combine(day, datetime.min.time()).astimezone()


def _overlaps(event, window_start, window_end):
    start = _instant(event.get("start"))
    end = _instant(event.get("end")) or start
    if start is None:
        return False
    return start < window_end and end > window_start
