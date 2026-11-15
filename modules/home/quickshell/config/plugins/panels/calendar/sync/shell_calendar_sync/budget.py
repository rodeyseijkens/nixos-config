"""How much one sync may hold, whatever its sources send.

The window bounds the days of one event, and the body cap bounds the bytes
of one answer. Neither bounds how many events a feed lists.
"""

import contextlib
import resource
import signal

from .errors import SyncError

# The panel gives up on the event command after 60 s.
EVENT_SECONDS = 55
# What one helper process (the caldir CLI) may take.
HELPER_SECONDS = 60
# The heap of one run. A sync peaks under 60 MB.
MAX_MEMORY_BYTES = 512 * 1024 * 1024


class TookTooLong(SyncError):
    """The run passed its deadline."""


@contextlib.contextmanager
def deadline(seconds):
    """Raises TookTooLong in the main thread once seconds have passed,
    whatever it waits on: a socket, a helper process or a loop."""

    def expire(_signum, _frame):
        raise TookTooLong("gave up after %d s" % seconds)

    previous = signal.signal(signal.SIGALRM, expire)
    signal.alarm(seconds)
    try:
        yield
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, previous)


def cap_memory():
    """Caps the heap of this process, whatever started it: the timer, the
    setup's test sync, the panel or a terminal. Past it Python raises
    MemoryError. Only the soft limit, so helpers can lift it (uncap_memory)."""
    _soft, hard = resource.getrlimit(resource.RLIMIT_DATA)
    if hard == resource.RLIM_INFINITY or hard > MAX_MEMORY_BYTES:
        resource.setrlimit(resource.RLIMIT_DATA, (MAX_MEMORY_BYTES, hard))


def uncap_memory():
    """For subprocess preexec_fn: a helper such as caldir gets its own limits,
    not the sync's."""
    _soft, hard = resource.getrlimit(resource.RLIMIT_DATA)
    resource.setrlimit(resource.RLIMIT_DATA, (hard, hard))
