#!/bin/bash
set -euo pipefail
package_dir=$(cd "$(dirname "$0")" && pwd)
source_plugin="$package_dir/CameraReference.lrplugin"
if [ ! -d "$source_plugin" ]; then
  echo 'Run this installer from the mounted Camera Reference disk image.' >&2
  exit 1
fi
plugin_parent="$HOME/Library/Application Support/Camera Reference/Plugins"
plugin_destination="$plugin_parent/CameraReference.lrplugin"
mkdir -p "$plugin_parent"
if [ -e "$plugin_destination" ]; then
  backup_path="${plugin_destination}.backup-$(date +%Y%m%d-%H%M%S)-$$"
  mv "$plugin_destination" "$backup_path"
  echo "Previous plugin kept at: $backup_path"
fi
ditto "$source_plugin" "$plugin_destination"
echo "Installed: $plugin_destination"
echo 'In Lightroom: File → Plug-in Manager → Add, select this folder, then enable it.'
echo 'Disable the old Camera Reference bridge entry if it points elsewhere.'
echo 'Then File → Plug-in Extras → Start / restart Camera Reference bridge.'
open -R "$plugin_destination"
read -r -p 'Press Return to close. ' _reply
