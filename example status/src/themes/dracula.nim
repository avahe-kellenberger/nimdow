## Dracula themed arrows
const
  RESET: string  = "\x1b[0m"
  FG: string = "\x1b[38;2;"
  BG: string = "\x1b[48;2;"


  DRACULA0: string  = "40;42;54m"    #282a36
  DRACULA1: string  = "68;71;90m"    #44475a
  DRACULA2: string  = "248;248;242m" #f8f8f2
  DRACULA3: string  = "98;114;164m"  #6272a4
  DRACULA4: string  = "139;233;253m" #8be9fd
  DRACULA5: string  = "80;250;123m"  #50fa7b
  DRACULA6: string  = "255;184;108m" #ffb86c
  DRACULA7: string  = "255;121;198m" #ff79c6
  DRACULA8: string  = "189;147;249m" #bd93f9
  DRACULA9: string = "255;85;85m"    #ff5555
  DRACULA10: string = "241;250;140m" #f1fa8c

  ARROW_0: string = RESET & FG&DRACULA0 & "" & RESET & BG&DRACULA0     #282A36
  ARROW_1: string = RESET & FG&DRACULA1 & "" & RESET & BG&DRACULA1     #44475a  
  ARROW_2: string = RESET & FG&DRACULA2 & "" & RESET & BG&DRACULA2     #f8f8f2  
  ARROW_3: string = RESET & FG&DRACULA3 & "" & RESET & BG&DRACULA3     #6272a4  
  ARROW_4: string = RESET & FG&DRACULA4 & "" & RESET & BG&DRACULA4     #8be9fd  
  ARROW_5: string = RESET & FG&DRACULA5 & "" & RESET & BG&DRACULA5     #50fa7b  
  ARROW_6: string = RESET & FG&DRACULA6 & "" & RESET & BG&DRACULA6     #ffb86c  
  ARROW_7: string = RESET & FG&DRACULA7 & "" & RESET & BG&DRACULA7     #ff79c6  
  ARROW_8: string = RESET & FG&DRACULA8 & "" & RESET & BG&DRACULA8     #bd93f9  
  ARROW_9: string = RESET & FG&DRACULA9 & "" & RESET & BG&DRACULA9     #ff5555 
  ARROW_10: string = RESET & FG&DRACULA10 & "" & RESET & BG&DRACULA10  #f1fa8c 

  CIRCLE_0: string = RESET & FG&DRACULA0 & "" & RESET & BG&DRACULA0    #282A36
  CIRCLE_1: string = RESET & FG&DRACULA1 & "" & RESET & BG&DRACULA1    #44475a  
  CIRCLE_2: string = RESET & FG&DRACULA2 & "" & RESET & BG&DRACULA2    #f8f8f2  
  CIRCLE_3: string = RESET & FG&DRACULA3 & "" & RESET & BG&DRACULA3    #6272a4  
  CIRCLE_4: string = RESET & FG&DRACULA4 & "" & RESET & BG&DRACULA4    #8be9fd  
  CIRCLE_5: string = RESET & FG&DRACULA5 & "" & RESET & BG&DRACULA5    #50fa7b  
  CIRCLE_6: string = RESET & FG&DRACULA6 & "" & RESET & BG&DRACULA6    #ffb86c  
  CIRCLE_7: string = RESET & FG&DRACULA7 & "" & RESET & BG&DRACULA7    #ff79c6  
  CIRCLE_8: string = RESET & FG&DRACULA8 & "" & RESET & BG&DRACULA8    #bd93f9  
  CIRCLE_9: string = RESET & FG&DRACULA9 & "" & RESET & BG&DRACULA9    #ff5555 
  CIRCLE_10: string = RESET & FG&DRACULA10 & "" & RESET & BG&DRACULA10 #f1fa8c 

  ANGLE_0: string = RESET & FG&DRACULA0 & "" & RESET & BG&DRACULA0     #282A36
  ANGLE_1: string = RESET & FG&DRACULA1 & "" & RESET & BG&DRACULA1     #44475a  
  ANGLE_2: string = RESET & FG&DRACULA2 & "" & RESET & BG&DRACULA2     #f8f8f2  
  ANGLE_3: string = RESET & FG&DRACULA3 & "" & RESET & BG&DRACULA3     #6272a4  
  ANGLE_4: string = RESET & FG&DRACULA4 & "" & RESET & BG&DRACULA4     #8be9fd  
  ANGLE_5: string = RESET & FG&DRACULA5 & "" & RESET & BG&DRACULA5     #50fa7b  
  ANGLE_6: string = RESET & FG&DRACULA6 & "" & RESET & BG&DRACULA6     #ffb86c  
  ANGLE_7: string = RESET & FG&DRACULA7 & "" & RESET & BG&DRACULA7     #ff79c6  
  ANGLE_8: string = RESET & FG&DRACULA8 & "" & RESET & BG&DRACULA8     #bd93f9  
  ANGLE_9: string = RESET & FG&DRACULA9 & "" & RESET & BG&DRACULA9     #ff5555 
  ANGLE_10: string = RESET & FG&DRACULA10 & "" & RESET & BG&DRACULA10  #f1fa8c 
  


#[ Nimdow config.toml

  # Window settings Dracula type theme
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




