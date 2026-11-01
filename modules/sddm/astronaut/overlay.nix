# Ryoku visual overlay for sddm-astronaut — postInstall fragment.
# Shared by modules/desktop.nix and pkgs/sddm-ryoku-theme-build.nix.
#
# Input.qml is patched in place (visual lines only) so login/auth logic stays
# upstream-owned; --replace-fail breaks the build if upstream changes them.
{ schemeName }:
''
  themeDir="$out/share/sddm/themes/sddm-astronaut-theme"
  chmod u+w "$themeDir" "$themeDir/Main.qml"
  chmod -R u+w "$themeDir/Components"

  cp -f ${./Main.qml} "$themeDir/Main.qml"
  cp -f ${./Clock.qml} "$themeDir/Components/Clock.qml"
  cp -f ${./SystemButtons.qml} "$themeDir/Components/SystemButtons.qml"

  # Username/password fields: translucent fill (alpha in color) + subtle border.
  substituteInPlace "$themeDir/Components/Input.qml" \
    --replace-fail $'opacity: 0.2\n                border.color: "transparent"' \
                   $'opacity: 1\n                border.color: config.RyokuFieldBorderColor || "transparent"'

  # Login button: tonal glass, visible disabled state, clear focus ring.
  substituteInPlace "$themeDir/Components/Input.qml" \
    --replace-fail $'opacity: 0.2\n                radius: config.RoundCorners || 0' \
                   $'opacity: 0.55\n                border.width: loginButton.activeFocus ? 2 : 1\n                border.color: loginButton.activeFocus ? config.HighlightBorderColor : (config.RyokuLoginButtonBorderColor || "transparent")\n                radius: config.RoundCorners || 0'

  printf '%s\n' "${schemeName}" > "$themeDir/ryoku-contrast-scheme"
''
