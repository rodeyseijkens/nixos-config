#!/usr/bin/env bash

# Install herdr plugins.
#
# herdr has no declarative plugin config: plugins are registered by the herdr
# CLI and live in ~/.config/herdr/plugins.json. Add one `herdr plugin install`
# line per plugin.

herdr plugin install rodeyseijkens/codey --yes
