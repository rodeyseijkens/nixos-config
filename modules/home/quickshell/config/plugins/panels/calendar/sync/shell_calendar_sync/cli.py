"""The calendar backend and the atomic write the event command uses.

Reading the calendars into the widget file is shell-calendar-sync, a shell
script. This package keeps what the panel's write command needs.
"""

import json
import os
import tempfile
from pathlib import Path

from . import config as config_module
from .caldir import Caldir


def write_atomic(path, doc):
    """Write JSON so a reader never observes a partial file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    handle, temp_name = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(handle, "w") as stream:
            json.dump(doc, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
    except BaseException:
        Path(temp_name).unlink(missing_ok=True)
        raise


def build_client(cfg, local_tz=None):
    """The calendar source named by the config."""
    backend = str(cfg.get("backend") or "caldir").strip().lower()
    if backend == "caldir":
        return Caldir(binary=cfg["caldirPath"], pull=bool(cfg.get("caldirPull")), tz=local_tz)
    raise config_module.ConfigError("unknown backend %r; expected \"caldir\"" % backend)
