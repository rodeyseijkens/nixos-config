<h1 align="center">
   <img src="./.github/assets/logo/nixos-logo.png  " width="100px" /> 
   <br>
      Rodey's Flakes 
   <br>
      <img src="./.github/assets/pallet/pallet-0.png" width="600px" /> <br>

   <div align="center">
      <p></p>
      <div align="center">
         <a href="https://github.com/rodeyseijkens/nixos-config/stargazers">
            <img src="https://img.shields.io/github/stars/rodeyseijkens/nixos-config?color=FABD2F&labelColor=282828&style=for-the-badge&logo=starship&logoColor=FABD2F">
         </a>
         <a href="https://github.com/rodeyseijkens/nixos-config/">
            <img src="https://img.shields.io/github/repo-size/rodeyseijkens/nixos-config?color=B16286&labelColor=282828&style=for-the-badge&logo=github&logoColor=B16286">
         </a>
         <a = href="https://nixos.org">
            <img src="https://img.shields.io/badge/NixOS-unstable-blue.svg?style=for-the-badge&labelColor=282828&logo=NixOS&logoColor=458588&color=458588">
         </a>
         <a href="https://github.com/rodeyseijkens/nixos-config/blob/main/LICENSE">
            <img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&colorA=282828&colorB=98971A&logo=unlicense&logoColor=98971A&"/>
         </a>
      </div>
      <br>
   </div>
</h1>

### 🖼️ Gallery

<p align="center">
   <img src="./.github/assets/screenshots/1.png" style="margin-bottom: 10px;"/> <br>
   <img src="./.github/assets/screenshots/2.png" style="margin-bottom: 10px;"/> <br>
   <img src="./.github/assets/screenshots/3.png" style="margin-bottom: 10px;"/> <br>
   Screenshots last updated <b>2024-08-24</b>
</p>

<details>
<summary>
Hyprlock (EXPAND)
</summary>
<p align="center">
   <img src="./.github/assets/screenshots/hyprlock.png" style="margin-bottom: 10px;" /> <br>
</p>
</details>
<br/>
<br/>

# 🗃️ Overview

## 📚 Layout

- [flake.nix](flake.nix) base of the configuration
- [hosts](hosts) 🌳 per-host configurations that contain machine specific configurations
  - [desktop](hosts/desktop/) 🖥️ Desktop specific configuration
  - [laptop](hosts/laptop/) 💻 Laptop specific configuration
  - [vm](hosts/vm/) 🗄️ VM specific configuration
- [modules](modules) 🍱 modularized NixOS configurations
  - [core](modules/core/) ⚙️ Core NixOS configuration
  - [homes](modules/home/) 🏠 my [Home-Manager](https://github.com/nix-community/home-manager) config
- [pkgs](flake/pkgs) 📦 Packages Build from source
- [wallpapers](wallpapers/) 🌄 wallpapers collection

## 📓 Components

|                             |                                  NixOS + Hyprland                                   |
| --------------------------- | :---------------------------------------------------------------------------------: |
| **Window Manager**          |                                [Hyprland][Hyprland]                                 |
| **Bar**                     |                                  [Waybar][Waybar]                                   |
| **Application Launcher**    |                                    [rofi][rofi]                                     |
| **Notification Daemon**     |                                  [swaync][swaync]                                   |
| **Terminal Emulator**       |                         [Kitty][Kitty] + [Ghostty][Ghostty]                         |
| **Shell**                   |                         [zsh][zsh] + [oh-my-zsh][oh-my-zsh]                         |
| **Text Editor**             |                         [VSCode][VSCode] + [Neovim][Neovim]                         |
| **network management tool** | [NetworkManager][NetworkManager] + [network-manager-applet][network-manager-applet] |
| **System resource monitor** |                                    [Btop][Btop]                                     |
| **Browser**                 |                   [Firefox][Firefox] + [Zen Browser][zen-browser]                   |
| **File Manager**            |                         [Nautilus][Nautilus] + [yazi][yazi]                         |
| **Fonts**                   |                              [Maple Mono][Maple Mono]                               |
| **Color Scheme**            |                            [Gruvbox Dark Hard][Gruvbox]                             |
| **Cursor**                  |                       [Bibata-Modern-Ice][Bibata-Modern-Ice]                        |
| **Icons**                   |                            [Papirus-Dark][Papirus-Dark]                             |
| **Lockscreen**              |                                [Hyprlock][Hyprlock]                                 |
| **Image Viewer**            |                                   [qview][qview]                                    |
| **Media Player**            |                                     [mpv][mpv]                                      |
| **Screenshot Software**     |                               [grimblast][grimblast]                                |
| **Screen Recording**        |                             [wf-recorder][wf-recorder]                              |
| **Color Picker**            |                              [hyprpicker][hyprpicker]                               |

## 📝 Shell aliases

<details>
<summary>
Utils (EXPAND)
</summary>

- `c` $\rightarrow$ `clear`
- `cd` $\rightarrow$ `z`
- `vim` $\rightarrow$ `nvim`
- `cat` $\rightarrow$ `bat`
- `nano` $\rightarrow$ `micro`
- `code` $\rightarrow$ `codium`
- `py` $\rightarrow$ `python`
- `icat` $\rightarrow$ `kitten icat`
- `dsize` $\rightarrow$ `du -hs`
- `pdf` $\rightarrow$ `tdf`
- `open` $\rightarrow$ `xdg-open`
- `space` $\rightarrow$ `ncdu`
- `man` $\rightarrow$ `BAT_THEME='default' batman`
- `l` $\rightarrow$ `eza --icons  -a --group-directories-first -1`
- `ll` $\rightarrow$ `eza --icons  -a --group-directories-first -1 --no-user --long`
- `tree` $\rightarrow$ `eza --icons --tree --group-directories-first`
</details>

<details>
<summary>
Nixos (EXPAND)
</summary>

- `cdnix` $\rightarrow$ `cd ~/nixos-config && codium ~/nixos-config`
- `ns` $\rightarrow$ `nom-shell --run zsh`
- `nix-test` $\rightarrow$ `nh os test`
- `nix-switch` $\rightarrow$ `nh os switch`
- `nix-update` $\rightarrow$ `nh os switch --update`
- `nix-clean` $\rightarrow$ `nh clean all --keep 5`
- `nix-search` $\rightarrow$ `nh search`
</details>

<details>
<summary>
Git (EXPAND)
</summary>

- `g` $\rightarrow$ `lazygit`
- `gf` $\rightarrow$ `onefetch --number-of-file-churns 0 --no-color-palette`
- `ga` $\rightarrow$ `git add`
- `gaa` $\rightarrow$ `git add --all`
- `gs` $\rightarrow$ `git status`
- `gb` $\rightarrow$ `git branch`
- `gm` $\rightarrow$ `git merge`
- `gd` $\rightarrow$ `git diff`
- `gpl` $\rightarrow$ `git pull`
- `gplo` $\rightarrow$ `git pull origin`
- `gps` $\rightarrow$ `git push`
- `gpsf` $\rightarrow$ `git push --force`
- `gpso` $\rightarrow$ `git push origin`
- `gpst` $\rightarrow$ `git push --follow-tags`
- `gcl` $\rightarrow$ `git clone`
- `gc` $\rightarrow$ `git commit`
- `gcm` $\rightarrow$ `git commit -m`
- `gcma` $\rightarrow$ `git add --all && git commit -m`
- `gtag` $\rightarrow$ `git tag -ma`
- `gch` $\rightarrow$ `git checkout`
- `gchb` $\rightarrow$ `git checkout -b`
- `glog` $\rightarrow$ `git log --oneline --decorate --graph`
- `glol` $\rightarrow$ `git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'`
- `glola` $\rightarrow$ `git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --all`
- `glols` $\rightarrow$ `git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --stat`

</details>

## 🛠️ Scripts

All the scripts are in `modules/home/scripts/scripts/` and are exported as packages in `modules/home/scripts/default.nix`

<details>
<summary>
extract.sh 
</summary>

**Description:** This script extract `tar.gz` archives in the current directory.

**Usage:** `extract <archive_file>`

</details>

<details>
<summary>
compress.sh 
</summary>

**Description:** This script compress a file or a folder into a `tar.gz` archives which is created in the current directory with the name of the chosen file or folder.

**Usage:** `compress <file>` or `compress <folder>`

</details>

<details>
<summary>
toggle-blur.sh 
</summary>

**Description:** This script toggles the Hyprland blur effect. If the blur is currently enabled, it will be disabled, and if it's disabled, it will be turned on.

**Usage:** `toggle-blur`

</details>

<details>
<summary>
toggle-opacity.sh 
</summary>

**Description:** This script toggles the Hyperland oppacity effect. If the oppacity is currently set to 0.90, it will be set to 1, and if it's set to 1, it will be set to 0.90.

**Usage:** `toggle-opacity`

</details>

<details>
<summary>
runbg.sh 
</summary>

**Description:** This script runs a provided command along with its arguments and detaches it from the terminal. Handy for launching apps from the command line without blocking it.

**Usage:** `runbg <command> <arg1> <arg2> <...>`

</details>

## ⌨️ Keybinds

View all keybinds by pressing `$mainMod F1` and wallpaper picker by pressing `$mainMod w`. By default `$mainMod` is the `SUPER` key.

<details>
<summary>
Keybindings 
</summary>

##### show keybinds list

- `$mainMod, F1, exec, show-keybinds`

##### keybindings

- `$mainMod, Return, exec, [float; center] kitty start --always-new-process`
- `$mainMod SHIFT, Return, exec, kitty start --always-new-process`
- `$mainMod ALT, Return, exec, [fullscreen] kitty start --always-new-process`
- `$mainMod, B, exec, firefox`
- `$mainMod, Q, killactive,`
- `$mainMod, F, fullscreen, 0`
- `$mainMod SHIFT, F, fullscreen, 1`
- `$mainMod, G, toggle-float,`
- `$mainMod, Space, exec, rofi -show drun`
- `$mainMod SHIFT, D, exec, hyprctl dispatch exec '[workspace 4 silent] discord --enable-features=UseOzonePlatform --ozone-platform=wayland'`
- `$mainMod SHIFT, Escape, exec, power-menu`
- `$mainMod, P, pseudo,`
- `$mainMod, J, togglesplit,`
- `$mainMod, T, exec, toggle-opacity`
- `$mainMod SHIFT, B, exec, toggle-waybar`
- `$mainMod, C ,exec, hyprpicker -a`
- `$mainMod, W,exec, wallpaper-picker`
- `$mainMod, N, exec, swaync-client -t -sw`
- `$mainMod SHIFT, W, exec, vm-start`

##### screenshot

- `$mainMod, Print, exec, grimblast --notify --cursor --freeze save area ~/Pictures/$(date +'%Y-%m-%d-At-%Ih%Mm%Ss').png`
- `,Print, exec, grimblast --notify --cursor --freeze copy area`

##### switch focus

- `$mainMod, left, movefocus, l`
- `$mainMod, right, movefocus, r`
- `$mainMod, up, movefocus, u`
- `$mainMod, down, movefocus, d`

##### switch workspace

- `$mainMod, 1, workspace, 1`
- `$mainMod, 2, workspace, 2`
- `$mainMod, 3, workspace, 3`
- `$mainMod, 4, workspace, 4`
- `$mainMod, 5, workspace, 5`
- `$mainMod, 6, workspace, 6`
- `$mainMod, 7, workspace, 7`
- `$mainMod, 8, workspace, 8`
- `$mainMod, 9, workspace, 9`
- `$mainMod, 0, workspace, 10`

##### same as above, but move to the workspace

- `$mainMod SHIFT, 1, movetoworkspacesilent, 1 # movetoworkspacesilent`
- `$mainMod SHIFT, 2, movetoworkspacesilent, 2`
- `$mainMod SHIFT, 3, movetoworkspacesilent, 3`
- `$mainMod SHIFT, 4, movetoworkspacesilent, 4`
- `$mainMod SHIFT, 5, movetoworkspacesilent, 5`
- `$mainMod SHIFT, 6, movetoworkspacesilent, 6`
- `$mainMod SHIFT, 7, movetoworkspacesilent, 7`
- `$mainMod SHIFT, 8, movetoworkspacesilent, 8`
- `$mainMod SHIFT, 9, movetoworkspacesilent, 9`
- `$mainMod SHIFT, 0, movetoworkspacesilent, 10`
- `$mainMod CTRL, c, movetoworkspace, empty"`

##### window control

- `$mainMod SHIFT, left, movewindoworgroup, l`
- `$mainMod SHIFT, right, movewindoworgroup, r`
- `$mainMod SHIFT, up, movewindoworgroup, u`
- `$mainMod SHIFT, down, movewindoworgroup, d`
- `$mainMod CTRL, left, resizeactive, -80 0`
- `$mainMod CTRL, right, resizeactive, 80 0`
- `$mainMod CTRL, up, resizeactive, 0 -80`
- `$mainMod CTRL, down, resizeactive, 0 80`
- `$mainMod ALT, left, moveactive,  -80 0`
- `$mainMod ALT, right, moveactive, 80 0`
- `$mainMod ALT, up, moveactive, 0 -80`
- `$mainMod ALT, down, moveactive, 0 80`

#### window tabbed grouping

- `$mainMod SHIFT, T, togglegroup # toggle tabbed group`
- `$mainMod ALT, left, changegroupactive, b # change active tab back`
- `$mainMod ALT, right, changegroupactive, f # change active tab forward`
- `$mainMod ALT, j, changegroupactive, b # change active tab back`
- `$mainMod ALT, l, changegroupactive, f # change active tab forward`

#### mouse bindings

- `$mainMod, mouse:274, movewindoworgroup`
- `$mainMod SHIFT, mouse:274, resizewindow`

##### media and volume controls

- `,XF86AudioRaiseVolume,exec, pamixer -i 2`
- `,XF86AudioLowerVolume,exec, pamixer -d 2`
- `,XF86AudioMute,exec, pamixer -t`
- `,XF86AudioPlay,exec, playerctl play-pause`
- `,XF86AudioNext,exec, playerctl next`
- `,XF86AudioPrev,exec, playerctl previous`
- `,XF86AudioStop, exec, playerctl stop`
- `$mainMod, mouse_down, workspace, e-1`
- `$mainMod, mouse_up, workspace, e+1`

##### laptop brigthness

- `,XF86MonBrightnessUp, exec, brightnessctl set 5%+`
- `,XF86MonBrightnessDown, exec, brightnessctl set 5%-`
- `$mainMod, XF86MonBrightnessUp, exec, brightnessctl set 100%+`
- `$mainMod, XF86MonBrightnessDown, exec, brightnessctl set 100%-`
</details>

# 🚀 Installation

> [!CAUTION]
> Applying custom configurations, especially those related to your operating system, can have unexpected consequences and may interfere with your system's normal behavior. While I have tested these configurations on my own setup, there is no guarantee that they will work flawlessly for you.
> **I am not responsible for any issues that may arise from using this configuration.**

> [!NOTE]
> It is highly recommended to review the configuration contents and make necessary modifications to customize it to your needs before attempting the installation.

#### 1. **Install NixOs**

First install nixos using any [graphical ISO image](https://nixos.org/download.html#nixos-iso).

> [!NOTE]
> Only been tested using the Gnome graphical installer and choosing the `No desktop` option durring instalation.

#### 2. **Clone the repo**

```bash
nix-shell -p git
git clone https://github.com/rodeyseijkens/nixos-config
cd nixos-config
```

#### 3. **Install script**

> [!CAUTION]
> For some computers, the default rebuild command might get stuck due to CPU cores running out of RAM. To fix that modify the install script line: `sudo nixos-rebuild switch --flake .#${HOST}` to `sudo nixos-rebuild switch --cores <less than your max number of cores> --flake .#${HOST}`

> [!TIP]
> As it is better to know what a script does before running it, you are advised to read it or at least see the [Install script walkthrough](#Install-script-walkthrough) section before execution.

Execute and follow the installation script :

```bash
./install.sh
```

#### 4. **Reboot**

After rebooting, the config should be applied, you'll be greeted by hyprlock prompting for your password.

#### 5. **Manual config**

Even though I use home manager, there is still a little bit of manual configuration to do:

- Enable Discord theme (in Discord settings under VENCORD > Themes).
- Configure the browser (for now, all browser configuration is done manually).
- Change the git account information in `./modules/home/git.nix`

```nix
programs.git = {
   ...
   userName = "rodeyseijkens";
   userEmail = "me@rodey.nl";
   ...
};
```

## Install script walkthrough

A brief walkthrough of what the install script does.

#### 1. **Get username**

You will receive a prompt to enter your username, with a confirmation check.

#### 2. **Set username**

The script will replace all occurancies of the default usename `CURRENT_USERNAME` by the given one stored in `$username`

#### 3. Create basic directories

The following directories will be created:

- `~/Downloads`
- `~/Documents`
- `~/Pictures/wallpapers/others`
- `~/Projects`

#### 4. Copy the wallpapers

Then the wallpapers will be copied into `~/Pictures/wallpapers/others` which is the folder in which the `wallpaper-picker.sh` script will be looking for them.

#### 5. Get the hardware configuration

It will also automatically copy the hardware configuration from `/etc/nixos/hardware-configuration.nix` to `./hosts/${host}/hardware-configuration.nix` so that the hardware configuration used is yours and not the default one.

#### 6. Choose a host (desktop / laptop)

Now you will need to choose the host you want. It depend on whether you are using a desktop or laptop (or a VM altho it can be realy buggy).

#### 7. Build the system

Lastly, it will build the system using [nh](https://github.com/viperML/nh), which includes both the flake config and home-manager config.

# 👥 Credits

Special thanks to **Frost-Phoenix**

I forked this project from: [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config)

Other dotfiles that I learned / copy from:

- Nix Flakes

  - [nomadics9/NixOS-Flake](https://github.com/nomadics9/NixOS-Flake)
  - [samiulbasirfahim/Flakes](https://github.com/samiulbasirfahim/Flakes): General flake / files structure
  - [justinlime/dotfiles](https://github.com/justinlime/dotfiles): Mainly waybar (old design)
  - [skiletro/nixfiles](https://github.com/skiletro/nixfiles): Vscodium config (that prevent it to crash)
  - [fufexan/dotfiles](https://github.com/fufexan/dotfiles)
  - [tluijken/.dotfiles](https://github.com/tluijken/.dotfiles): base rofi config
  - [mrh/dotfiles](https://codeberg.org/mrh/dotfiles): base waybar config

- README
  - [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)
  - [NotAShelf/nyx](https://github.com/NotAShelf/nyx)
  - [sioodmy/dotfiles](https://github.com/sioodmy/dotfiles)
  - [Ruixi-rebirth/flakes](https://github.com/Ruixi-rebirth/flakes)

<!-- # ✨ Stars History -->

<!-- <p align="center"><img src="https://api.star-history.com/svg?repos=rodeyseijkens/nixos-config&type=Timeline&theme=dark" /></p> -->

<p align="center"><img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/footers/gray0_ctp_on_line.svg?sanitize=true" /></p>

<!-- end of page, send back to the top -->

<div align="right">
  <a href="#readme">Back to the Top</a>
</div>

<!-- Links -->

[Hyprland]: https://github.com/hyprwm/Hyprland
[Kitty]: https://sw.kovidgoyal.net/kitty/
[Ghostty]: https://ghostty.org/
[Waybar]: https://github.com/Alexays/Waybar
[rofi]: https://github.com/lbonn/rofi
[Btop]: https://github.com/aristocratos/btop
[Nautilus]: https://apps.gnome.org/Nautilus/
[yazi]: https://github.com/sxyazi/yazi
[zsh]: https://ohmyz.sh/
[oh-my-zsh]: https://ohmyz.sh/
[Hyprlock]: https://github.com/hyprwm/hyprlock
[mpv]: https://github.com/mpv-player/mpv
[VSCode]: https://code.visualstudio.com/
[Neovim]: https://github.com/neovim/neovim
[grimblast]: https://github.com/hyprwm/contrib
[qview]: https://interversehq.com/qview/
[swaync]: https://github.com/ErikReider/SwayNotificationCenter
[NetworkManager]: https://wiki.gnome.org/Projects/NetworkManager
[network-manager-applet]: https://gitlab.gnome.org/GNOME/network-manager-applet/
[wf-recorder]: https://github.com/ammen99/wf-recorder
[hyprpicker]: https://github.com/hyprwm/hyprpicker
[Gruvbox]: https://github.com/morhetz/gruvbox
[Papirus-Dark]: https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
[Bibata-Modern-Ice]: https://www.gnome-look.org/p/1197198
[Firefox]: https://www.mozilla.org
[zen-browser]: https://github.com/zen-browser/desktop
[Maple Mono]: https://github.com/subframe7536/maple-font
