{
  lib,
  stdenv,
  fetchFromGitHub,
  gnu-efi,
  imagemagick,
  dejavu_fonts,
  librsvg,
  fontconfig,
  # Stylix colours without the leading "#", e.g. "3c3836".
  palette,
}:
# One derivation for both consumers: the boot menu files live in
# share/aarambh, and share/plymouth/themes/aarambh is a Plymouth theme
# (boot.plymouth themePackages). The splash images carry the Stylix palette.
stdenv.mkDerivation {
  pname = "aarambh";
  version = "0.1.7";

  # Fork-free: the upstream release tag, plus the patches in this directory.
  # Bumps are deliberate: rebuild, run tests/aarambh, then activate.
  src = fetchFromGitHub {
    owner = "NarkAgni";
    repo = "aarambh";
    rev = "v0.1.7";
    hash = "sha256-0WvGOud6dFJioV/V8/2r8BIAGZu/zru8YUbT3wCRzfE=";
  };

  patches = [
    ./patches/0001-discovery.patch
    ./patches/0002-editorial-gruvbox.patch
  ];

  nativeBuildInputs = [imagemagick librsvg fontconfig dejavu_fonts];

  postPatch = ''
    # The editorial-gruvbox palette comes from the Stylix colours at build
    # time. printf, not a heredoc: an indented EOF inside a Nix indented
    # string loses its indentation and the heredoc never terminates.
    header=src/themes/editorial/editorial_gruvbox_palette.h
    printf '%s\n' '/* Generated from config.lib.stylix.colors by package.nix. */' >$header
    printf '%s\n' "#define EDITORIAL_GRUVBOX_PAPER  0x${palette.paper}" >>$header
    printf '%s\n' "#define EDITORIAL_GRUVBOX_INK    0x${palette.ink}" >>$header
    printf '%s\n' "#define EDITORIAL_GRUVBOX_ACCENT 0x${palette.accent}" >>$header

    # Re-render the NixOS assets in the same palette. Upstream's generator is
    # kept as-is; only its inputs change. The upstream NixOS row is commented
    # out, and the new row goes in after an empty line because the upstream
    # file ends without a newline.
    sed -i "s#^FONT_DIR=.*#FONT_DIR=${dejavu_fonts}/share/fonts/truetype#" scripts/make-assets.sh
    sed -i 's/^nixos|/#&/' assets/distros.conf
    printf '\nnixos|NixOS|#%s|#%s|#%s\n' "${palette.accent}" "${palette.paper}" "${palette.paperDark}" \
        >>assets/distros.conf

    # Splash text in ink instead of white; quoted, or the # starts a comment.
    sed -i 's/ 100 3 white/ 100 3 "#${palette.ink}"/g; s/ 40 2 .#e8e4ee./ 40 2 "#${palette.ink}"/' scripts/make-assets.sh
    sed -i \
        -e "s/render_wallpaper settings '[^']*' '[^']*' '[^']*'/render_wallpaper settings '#${palette.paper}' '#151312' '#9a9284'/" \
        -e "s/render_wallpaper restart  '[^']*' '[^']*' '[^']*'/render_wallpaper restart  '#1c3614' '#0d1a0a' '#${palette.accent}'/" \
        -e "s/render_wallpaper power   '[^']*' '[^']*' '[^']*'/render_wallpaper power   '#4a1414' '#120404' '#c0392b'/" \
        scripts/make-assets.sh

    # The generator calls ImageMagick for text renders, which wants fontconfig
    # even in the build sandbox, and a writable cache directory.
    export FONTCONFIG_FILE=${fontconfig}/etc/fonts/fonts.conf
    export XDG_CACHE_HOME=$PWD/.cache
    patchShebangs ./scripts/make-assets.sh
    ./scripts/make-assets.sh generated-assets
  '';

  buildInputs = [gnu-efi];

  # Freestanding UEFI code: the wrapper's fortify and stack protector flags
  # would call libc symbols that do not exist in the image.
  hardeningDisable = ["all"];

  # The Makefile looks for gnu-efi under /usr/lib; point it at the store paths.
  makeFlags = [
    "CRT0=${gnu-efi}/lib/crt0-efi-x86_64.o"
    "LDS=${gnu-efi}/lib/elf_x86_64_efi.lds"
    "LIBDIR=${gnu-efi}/lib"
    "EFI_INC=${gnu-efi}/include/efi"
  ];

  # Only the loader and its assets. `make install` would write to /boot/efi.
  installPhase = ''
    runHook preInstall

    install -Dm644 build/aarambh.efi $out/share/aarambh/aarambh.efi
    cp -r --no-preserve=mode generated-assets/fonts generated-assets/logos \
        generated-assets/backgrounds $out/share/aarambh/

    # Plymouth theme: the upstream template (script and plugin selection) with
    # the generated NixOS art. The still-* files are the shutdown and reboot
    # frames the script wants; Nix versions the theme, so a boot-time sync
    # service is not needed.
    dir=$out/share/plymouth/themes/aarambh
    install -Dm644 assets/plymouth/template/aarambh.plymouth $dir/aarambh.plymouth
    install -Dm644 assets/plymouth/template/aarambh.script $dir/aarambh.script
    for f in bg logo dot prompt title title-reboot title-shutdown; do
        install -Dm644 generated-assets/plymouth/nixos/$f.png $dir/$f.png
    done
    cp $dir/bg.png $dir/still-bg.png
    cp $dir/title-reboot.png $dir/still-reboot.png
    cp $dir/title-shutdown.png $dir/still-shutdown.png
    cp $dir/dot.png $dir/still-dot.png

    runHook postInstall
  '';

  meta = {
    description = "Graphical UEFI boot menu with the Editorial Gruvbox theme";
    homepage = "https://github.com/NarkAgni/aarambh";
    license = lib.licenses.gpl3Plus;
    platforms = ["x86_64-linux"];
  };
}
