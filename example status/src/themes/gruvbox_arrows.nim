## Gruvbox themed arrows
const
  RESET: string  = "\x1b[0m\x1b[0m"
  RESET_O: string  = "\x1b[48;2;40;42;54m"

  GREEN_FG: string  = "\x1b[38;2;104;157;106m"
  BLUE_FG:  string  = "\x1b[38;2;69;133;136m"
  ORANGE_FG: string = "\x1b[38;2;249;188;47m"
  RED_FG: string    = "\x1b[38;2;231;104;97m"
  WHITE_FG: string  = "\x1b[38;2;235;219;178m"
  BROWN_FG: string  = "\x1b[38;2;49;51;66m"

  GREEN_BG: string  = "\x1b[48;2;104;157;106m"
  BLUE_BG:  string  = "\x1b[48;2;69;133;136m"
  ORANGE_BG: string = "\x1b[48;2;249;188;47m"
  RED_BG: string    = "\x1b[48;2;231;104;97m"
  WHITE_BG: string  = "\x1b[48;2;235;219;178m"
  BROWN_BG: string  = "\x1b[48;2;49;51;66m"


#                
  ARROW_GREEN: string  = RESET & GREEN_FG & "" & RESET & GREEN_BG
  ARROW_BLUE: string   = RESET & BLUE_FG & "" & RESET & BLUE_BG
  ARROW_ORANGE: string = RESET & ORANGE_FG & "" & RESET & ORANGE_BG
  ARROW_RED: string    = RESET & RED_FG & "" & RESET & RED_BG
  ARROW_WHITE: string  = RESET & WHITE_FG & "" & RESET & WHITE_BG
  ARROW_BROWN: string  = RESET & BROWN_FG & "" & RESET & BROWN_BG

  CIRCLE_GREEN_L: string  = RESET & GREEN_FG & "" & RESET & GREEN_BG
  CIRCLE_GREEN_R: string  = RESET & GREEN_FG & "" & RESET
  CIRCLE_BLUE_L: string   = RESET & BLUE_FG & "" & RESET & BLUE_BG
  CIRCLE_BLUE_R: string   = RESET & BLUE_FG & "" & RESET
  CIRCLE_ORANGE_L: string = RESET & ORANGE_FG & "" & RESET & ORANGE_BG
  CIRCLE_ORANGE_R: string = RESET & ORANGE_FG & "" & RESET
  CIRCLE_RED_L: string    = RESET & RED_FG & "" & RESET & RED_BG
  CIRCLE_RED_R: string    = RESET & RED_FG & "" & RESET
  CIRCLE_WHITE_L: string  = RESET & WHITE_FG & "" & RESET & WHITE_BG
  CIRCLE_WHITE_R: string  = RESET & WHITE_FG & "" & RESET
  CIRCLE_BROWN_L: string  = RESET & BROWN_FG & "" & RESET & BROWN_BG
  CIRCLE_BROWN_R: string  = RESET & BROWN_FG & "" & RESET


#[ Nimdow config.toml

  # Window settings
  borderWidth = 1
  borderColorUnfocused = "#282a36"
  borderColorFocused = "#8ec07c"
  borderColorUrgent = "#cc241d"
  # Bar settings
  barHeight = 28
  windowTitlePosition = "center"
  barBackgroundColor = "#918273" #"#282a36"
  barForegroundColor = "#313338" #"#f8f8f2"
  barSelectionColor = "ebdbb2"#"#f9bc2f" #"#50fa7b"
  barUrgentColor = "#cc241d"
  barFonts = [
    "DejaVu Sans:style=Bold:size=12:antialias=true"
    "FontAwesome:size=14:antialias=true"
    "JetBrainsMono Nerd Font:size=20:antialias=true",
  ]


]#

