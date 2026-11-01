# Ryoku SDDM contrast — deterministic wallpaper luminance → astronaut themeConfig.
#
# Hybrid model:
#   1) Sample luminance of wallpaper regions matching astronaut layout
#      (FormPosition=left → left ~40% column holds clock + form + system buttons).
#   2) Pick light-on-dark vs dark-on-light from the form-column mean.
#   3) Always enable a translucent glass panel behind the form column so
#      controls stay readable; a light global DimBackground stabilizes the rest.
#
# No runtime QML Canvas sampling (fragile under greeter). Analysis runs in
# Nix at build time — wallpaper Apply already rebuilds the theme.

{
  lib,
  runCommand,
  imagemagick,
  wallpaper, # path / store path to image
  threshold ? 0.55,
}:

let
  # Crop geometry: width%xheight%+x%+y%  (ImageMagick percent offsets)
  # Left column ≈ LoginForm width (parent.width / 2.5 ≈ 40%).
  samples = runCommand "ryoku-sddm-luminance" {
    nativeBuildInputs = [ imagemagick ];
    inherit wallpaper;
  } ''
    set -euo pipefail
    sample() {
      magick "$wallpaper" -crop "$1" +repage -colorspace Gray -format '%[fx:mean]' info:
    }
    full=$(sample '100%x100%')
    # Form column (left ~40%)
    left=$(sample '40%x100%+0+0')
    top=$(sample '40%x30%+0+0')
    mid=$(sample '40%x35%+0+32%')
    bot=$(sample '40%x25%+0+72%')
    cat > "$out" <<EOF
{
  "full": $full,
  "left": $left,
  "top": $top,
  "mid": $mid,
  "bot": $bot
}
EOF
  '';

  luma = builtins.fromJSON (builtins.readFile samples);

  # Primary decision: form-column mid (inputs). Fallback to left mean.
  decisionLuma =
    if luma ? mid then luma.mid else luma.left;

  # dark-on-light when the region behind the form is bright.
  isLightBg = decisionLuma >= threshold;

  schemeName = if isLightBg then "dark-on-light" else "light-on-dark";

  # Light global scrim — the glass panel carries form readability.
  dimOpacity =
    if luma.full >= 0.62 then "0.10"
    else if luma.full <= 0.28 then "0.04"
    else "0.07";

  # Colors with alpha MUST be Qt #AARRGGBB (not CSS #RRGGBBAA).
  # Glass alpha: more opaque when the form region sits closer to the threshold.
  darkGlassAlpha =
    if decisionLuma <= 0.30 then "47"       # 0.28
    else if decisionLuma <= 0.45 then "54"  # 0.33
    else "61";                              # 0.38

  lightGlassAlpha =
    if decisionLuma >= 0.80 then "38"       # 0.22
    else if decisionLuma >= 0.65 then "45"  # 0.27
    else "52";                              # 0.32

  lightOnDark = {
    # Foreground on dark glass
    HeaderTextColor = "#f5f5f7";
    DateTextColor = "#e8e8ed";
    TimeTextColor = "#f5f5f7";
    RyokuClockShadowColor = "#000000";
    RyokuClockShadowOpacity = "0.30";

    FormBackgroundColor = "#${darkGlassAlpha}16171f";
    BackgroundColor = "#16171f";
    DimBackgroundColor = "#000000";
    DimBackground = dimOpacity;
    RyokuGlassBorderColor = "#29ffffff";
    RyokuGlassHighlightColor = "#14ffffff";

    LoginFieldBackgroundColor = "#1affffff";
    PasswordFieldBackgroundColor = "#1affffff";
    RyokuFieldBorderColor = "#33ffffff";
    LoginFieldTextColor = "#f5f5f7";
    PasswordFieldTextColor = "#f5f5f7";
    UserIconColor = "#c8c8d0";
    PasswordIconColor = "#c8c8d0";
    PlaceholderTextColor = "#a8a8b6";
    WarningColor = "#ffb4ab";

    LoginButtonTextColor = "#f5f5f7";
    LoginButtonBackgroundColor = "#38c8d6ff";
    RyokuLoginButtonBorderColor = "#40c8d6ff";

    SystemButtonsIconsColor = "#e8e8ed";
    SessionButtonTextColor = "#e8e8ed";
    VirtualKeyboardButtonTextColor = "#e8e8ed";
    SystemButtonsBackgroundColor = "#1affffff";
    RyokuSystemButtonsHoverBackgroundColor = "#2effffff";
    RyokuSystemButtonsPressedBackgroundColor = "#3dffffff";
    RyokuSystemButtonsBorderColor = "#26ffffff";

    DropdownTextColor = "#f5f5f7";
    DropdownSelectedBackgroundColor = "#3a3b48";
    DropdownBackgroundColor = "#1e1f28";

    HighlightTextColor = "#c8d6ff";
    HighlightBackgroundColor = "#2a2b36";
    HighlightBorderColor = "#c8d6ff";

    HoverUserIconColor = "#c8d6ff";
    HoverPasswordIconColor = "#c8d6ff";
    HoverSystemButtonsIconsColor = "#ffffff";
    HoverSessionButtonTextColor = "#c8d6ff";
    HoverVirtualKeyboardButtonTextColor = "#c8d6ff";
  };

  darkOnLight = {
    HeaderTextColor = "#1c1c1e";
    DateTextColor = "#2c2c2e";
    TimeTextColor = "#1c1c1e";
    RyokuClockShadowColor = "#ffffff";
    RyokuClockShadowOpacity = "0.35";

    FormBackgroundColor = "#${lightGlassAlpha}f2f2f4";
    BackgroundColor = "#f2f2f4";
    DimBackgroundColor = "#000000";
    DimBackground = dimOpacity;
    RyokuGlassBorderColor = "#1a000000";
    RyokuGlassHighlightColor = "#40ffffff";

    LoginFieldBackgroundColor = "#8cffffff";
    PasswordFieldBackgroundColor = "#8cffffff";
    RyokuFieldBorderColor = "#1f000000";
    LoginFieldTextColor = "#1c1c1e";
    PasswordFieldTextColor = "#1c1c1e";
    UserIconColor = "#3a3a3c";
    PasswordIconColor = "#3a3a3c";
    PlaceholderTextColor = "#5f5f66";
    WarningColor = "#b3261e";

    LoginButtonTextColor = "#15233d";
    LoginButtonBackgroundColor = "#2e2c4a7c";
    RyokuLoginButtonBorderColor = "#402c4a7c";

    SystemButtonsIconsColor = "#1c1c1e";
    SessionButtonTextColor = "#1c1c1e";
    VirtualKeyboardButtonTextColor = "#1c1c1e";
    SystemButtonsBackgroundColor = "#14000000";
    RyokuSystemButtonsHoverBackgroundColor = "#24000000";
    RyokuSystemButtonsPressedBackgroundColor = "#33000000";
    RyokuSystemButtonsBorderColor = "#1f000000";

    DropdownTextColor = "#1c1c1e";
    DropdownSelectedBackgroundColor = "#d8d8dc";
    DropdownBackgroundColor = "#ffffff";

    HighlightTextColor = "#2c4a7c";
    HighlightBackgroundColor = "#e8e8ec";
    HighlightBorderColor = "#2c4a7c";

    HoverUserIconColor = "#2c4a7c";
    HoverPasswordIconColor = "#2c4a7c";
    HoverSystemButtonsIconsColor = "#000000";
    HoverSessionButtonTextColor = "#2c4a7c";
    HoverVirtualKeyboardButtonTextColor = "#2c4a7c";
  };

  colors = if isLightBg then darkOnLight else lightOnDark;

  # Structural readability — always on.
  structure = {
    HaveFormBackground = "true";
    PartialBlur = "false";
    FullBlur = "false";
    FormPosition = "left";
    CropBackground = "true";
  };

  themeConfig = structure // colors;
in
{
  inherit
    luma
    schemeName
    isLightBg
    decisionLuma
    threshold
    themeConfig
    samples
    ;
}
