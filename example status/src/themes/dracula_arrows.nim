## Dracula themed arrows
const
  RESET: string  = "\x1b[0m"


  BACKGROUND: string  = "\x1b[38;2;80;250;123m" #282a36
  CURRENTLINE: string = "\x1b[38;2;80;250;123m" #44475a
  FOREGROUND: string  = "\x1b[38;2;80;250;123m" #f8f8f2
  COMMENT: string     = "\x1b[38;2;80;250;123m" #6272a4

  CYAN_FG: string     = "\x1b[38;2;139;233;253m" #8be9fd
  GREEN_FG: string    = "\x1b[38;2;80;250;123m"  #50fa7b
  ORANGE_FG: string   = "\x1b[38;2;255;184;108m" #ffb86c
  PINK_FG:  string    = "\x1b[38;2;255;121;198m" #ff79c6
  PURPLE_FG: string   = "\x1b[38;2;189;147;249m" #bd93f9
  RED_FG: string      = "\x1b[38;2;255;85;85m"   #ff5555
  YELLOW_FG: string   = "\x1b[38;2;241;250;140m" #f1fa8c

  CYAN_BG: string     = "\x1b[48;2;139;233;253m" #8be9fd
  GREEN_BG: string    = "\x1b[48;2;80;250;123m"  #50fa7b
  ORANGE_BG:  string  = "\x1b[48;2;255;184;108m" #ffb86c
  PINK_BG: string     = "\x1b[48;2;255;121;198m" #ff79c6
  PURPLE_BG: string   = "\x1b[48;2;189;147;249m" #bd93f9
  RED_BG: string      = "\x1b[48;2;255;85;85m"   #ff5555
  YELLOW_BG: string   = "\x1b[48;2;241;250;140m" #f1fa8c

  ARROW_CYAN: string   = RESET & CYAN_FG & "" & RESET & CYAN_BG
  ARROW_GREEN: string  = RESET & GREEN_FG & "" & RESET & GREEN_BG
  ARROW_ORANGE: string = RESET & ORANGE_FG & "" & RESET & ORANGE_BG
  ARROW_PINK: string   = RESET & PINK_FG & "" & RESET & PINK_BG
  ARROW_PURPLE: string = RESET & PURPLE_FG & "" & RESET & PURPLE_BG
  ARROW_RED: string    = RESET & RED_FG & "" & RESET & RED_BG
  ARROW_YELLOW: string = RESET & YELLOW_FG & "" & RESET & YELLOW_BG


#[ Nimdow config.toml

  # Window settings
  borderWidth = 1
  borderColorUnfocused = "#6272a4"
  borderColorFocused = "#ff79c6"
  borderColorUrgent = "#ff5555"
  # Bar settings
  barHeight = 28
  windowTitlePosition = "center"
  barBackgroundColor = "#282a36"
  barForegroundColor = "#44475a"
  barSelectionColor = "#f1fa8c"
  barUrgentColor = "#ff5555"
  barFonts = [
    "DejaVu Sans:style=Bold:size=12:antialias=true",
    "FontAwesome:size=14:antialias=true",
    "JetBrainsMono Nerd Font:size=20:antialias=true",
  ]


]#




