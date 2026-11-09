//@ pragma ShellId shell
import Quickshell
import "plugins/bar"
import "plugins/panels/clock"
import "plugins/osd"
import "plugins/notifications"
import "plugins/polkit"
import "plugins/lock"
import "services"

ShellRoot {
  Bar {}
  PanelHost {}
  ToastHost {}
  PolkitDialog {}
  LockService {}
  Calendar {}
  Osd {}
}
