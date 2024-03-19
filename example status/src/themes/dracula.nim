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


  PLINE_0: string = FG&DRACULA0 & "" & RESET & BG&DRACULA0     #282A36
  PLINE_1: string = FG&DRACULA1 & "" & RESET & BG&DRACULA1     #44475a  
  PLINE_2: string = FG&DRACULA2 & "" & RESET & BG&DRACULA2     #f8f8f2  
  PLINE_3: string = FG&DRACULA3 & "" & RESET & BG&DRACULA3     #6272a4  
  PLINE_4: string = FG&DRACULA4 & "" & RESET & BG&DRACULA4     #8be9fd  
  PLINE_5: string = FG&DRACULA5 & "" & RESET & BG&DRACULA5     #50fa7b  
  PLINE_6: string = FG&DRACULA6 & "" & RESET & BG&DRACULA6     #ffb86c  
  PLINE_7: string = FG&DRACULA7 & "" & RESET & BG&DRACULA7     #ff79c6  
  PLINE_8: string = FG&DRACULA8 & "" & RESET & BG&DRACULA8     #bd93f9  
  PLINE_9: string = FG&DRACULA9 & "" & RESET & BG&DRACULA9     #ff5555 
  PLINE_10: string = FG&DRACULA10 & "" & RESET & BG&DRACULA10  #f1fa8c 

  CLINE_0: string = FG&DRACULA0 & "" & RESET & BG&DRACULA0    #282A36
  CLINE_1: string = FG&DRACULA1 & "" & RESET & BG&DRACULA1    #44475a  
  CLINE_2: string = FG&DRACULA2 & "" & RESET & BG&DRACULA2    #f8f8f2  
  CLINE_3: string = FG&DRACULA3 & "" & RESET & BG&DRACULA3    #6272a4  
  CLINE_4: string = FG&DRACULA4 & "" & RESET & BG&DRACULA4    #8be9fd  
  CLINE_5: string = FG&DRACULA5 & "" & RESET & BG&DRACULA5    #50fa7b  
  CLINE_6: string = FG&DRACULA6 & "" & RESET & BG&DRACULA6    #ffb86c  
  CLINE_7: string = FG&DRACULA7 & "" & RESET & BG&DRACULA7    #ff79c6  
  CLINE_8: string = FG&DRACULA8 & "" & RESET & BG&DRACULA8    #bd93f9  
  CLINE_9: string = FG&DRACULA9 & "" & RESET & BG&DRACULA9    #ff5555 
  CLINE_10: string = FG&DRACULA10 & "" & RESET & BG&DRACULA10 #f1fa8c 

  ALINE_0: string = FG&DRACULA0 & "" & RESET & BG&DRACULA0     #282A36
  ALINE_1: string = FG&DRACULA1 & "" & RESET & BG&DRACULA1     #44475a  
  ALINE_2: string = FG&DRACULA2 & "" & RESET & BG&DRACULA2     #f8f8f2  
  ALINE_3: string = FG&DRACULA3 & "" & RESET & BG&DRACULA3     #6272a4  
  ALINE_4: string = FG&DRACULA4 & "" & RESET & BG&DRACULA4     #8be9fd  
  ALINE_5: string = FG&DRACULA5 & "" & RESET & BG&DRACULA5     #50fa7b  
  ALINE_6: string = FG&DRACULA6 & "" & RESET & BG&DRACULA6     #ffb86c  
  ALINE_7: string = FG&DRACULA7 & "" & RESET & BG&DRACULA7     #ff79c6  
  ALINE_8: string = FG&DRACULA8 & "" & RESET & BG&DRACULA8     #bd93f9  
  ALINE_9: string = FG&DRACULA9 & "" & RESET & BG&DRACULA9     #ff5555 
  ALINE_10: string = FG&DRACULA10 & "" & RESET & BG&DRACULA10  #f1fa8c 

  ARROW_0L: string = RESET & FG&DRACULA0 & "" & RESET & BG&DRACULA0     #282A36
  ARROW_1L: string = RESET & FG&DRACULA1 & "" & RESET & BG&DRACULA1     #44475a  
  ARROW_2L: string = RESET & FG&DRACULA2 & "" & RESET & BG&DRACULA2     #f8f8f2  
  ARROW_3L: string = RESET & FG&DRACULA3 & "" & RESET & BG&DRACULA3     #6272a4  
  ARROW_4L: string = RESET & FG&DRACULA4 & "" & RESET & BG&DRACULA4     #8be9fd  
  ARROW_5L: string = RESET & FG&DRACULA5 & "" & RESET & BG&DRACULA5     #50fa7b  
  ARROW_6L: string = RESET & FG&DRACULA6 & "" & RESET & BG&DRACULA6     #ffb86c  
  ARROW_7L: string = RESET & FG&DRACULA7 & "" & RESET & BG&DRACULA7     #ff79c6  
  ARROW_8L: string = RESET & FG&DRACULA8 & "" & RESET & BG&DRACULA8     #bd93f9  
  ARROW_9L: string = RESET & FG&DRACULA9 & "" & RESET & BG&DRACULA9     #ff5555 
  ARROW_10L: string = RESET & FG&DRACULA10 & "" & RESET & BG&DRACULA10  #f1fa8c 

  ARROW_0R: string = RESET & FG&DRACULA0 & "" & RESET    #282A36
  ARROW_1R: string = RESET & FG&DRACULA1 & "" & RESET    #44475a  
  ARROW_2R: string = RESET & FG&DRACULA2 & "" & RESET    #f8f8f2  
  ARROW_3R: string = RESET & FG&DRACULA3 & "" & RESET    #6272a4  
  ARROW_4R: string = RESET & FG&DRACULA4 & "" & RESET    #8be9fd  
  ARROW_5R: string = RESET & FG&DRACULA5 & "" & RESET    #50fa7b  
  ARROW_6R: string = RESET & FG&DRACULA6 & "" & RESET    #ffb86c  
  ARROW_7R: string = RESET & FG&DRACULA7 & "" & RESET    #ff79c6  
  ARROW_8R: string = RESET & FG&DRACULA8 & "" & RESET    #bd93f9  
  ARROW_9R: string = RESET & FG&DRACULA9 & "" & RESET    #ff5555 
  ARROW_10R: string = RESET & FG&DRACULA10 & "" & RESET  #f1fa8c

  CIRCLE_0L: string = RESET & FG&DRACULA0 & "" & RESET & BG&DRACULA0    #282A36
  CIRCLE_1L: string = RESET & FG&DRACULA1 & "" & RESET & BG&DRACULA1    #44475a  
  CIRCLE_2L: string = RESET & FG&DRACULA2 & "" & RESET & BG&DRACULA2    #f8f8f2  
  CIRCLE_3L: string = RESET & FG&DRACULA3 & "" & RESET & BG&DRACULA3    #6272a4  
  CIRCLE_4L: string = RESET & FG&DRACULA4 & "" & RESET & BG&DRACULA4    #8be9fd  
  CIRCLE_5L: string = RESET & FG&DRACULA5 & "" & RESET & BG&DRACULA5    #50fa7b  
  CIRCLE_6L: string = RESET & FG&DRACULA6 & "" & RESET & BG&DRACULA6    #ffb86c  
  CIRCLE_7L: string = RESET & FG&DRACULA7 & "" & RESET & BG&DRACULA7    #ff79c6  
  CIRCLE_8L: string = RESET & FG&DRACULA8 & "" & RESET & BG&DRACULA8    #bd93f9  
  CIRCLE_9L: string = RESET & FG&DRACULA9 & "" & RESET & BG&DRACULA9    #ff5555 
  CIRCLE_10L: string = RESET & FG&DRACULA10 & "" & RESET & BG&DRACULA10 #f1fa8c 

  CIRCLE_0R: string = RESET & FG&DRACULA0 & "" & RESET   #282A36
  CIRCLE_1R: string = RESET & FG&DRACULA1 & "" & RESET   #44475a  
  CIRCLE_2R: string = RESET & FG&DRACULA2 & "" & RESET   #f8f8f2  
  CIRCLE_3R: string = RESET & FG&DRACULA3 & "" & RESET   #6272a4  
  CIRCLE_4R: string = RESET & FG&DRACULA4 & "" & RESET   #8be9fd  
  CIRCLE_5R: string = RESET & FG&DRACULA5 & "" & RESET   #50fa7b  
  CIRCLE_6R: string = RESET & FG&DRACULA6 & "" & RESET   #ffb86c  
  CIRCLE_7R: string = RESET & FG&DRACULA7 & "" & RESET   #ff79c6  
  CIRCLE_8R: string = RESET & FG&DRACULA8 & "" & RESET   #bd93f9  
  CIRCLE_9R: string = RESET & FG&DRACULA9 & "" & RESET   #ff5555 
  CIRCLE_10R: string = RESET & FG&DRACULA10 & "" & RESET #f1fa8c 

  ANGLE_0L: string = RESET & FG&DRACULA0 & "" & RESET & BG&DRACULA0     #282A36
  ANGLE_1L: string = RESET & FG&DRACULA1 & "" & RESET & BG&DRACULA1     #44475a  
  ANGLE_2L: string = RESET & FG&DRACULA2 & "" & RESET & BG&DRACULA2     #f8f8f2  
  ANGLE_3L: string = RESET & FG&DRACULA3 & "" & RESET & BG&DRACULA3     #6272a4  
  ANGLE_4L: string = RESET & FG&DRACULA4 & "" & RESET & BG&DRACULA4     #8be9fd  
  ANGLE_5L: string = RESET & FG&DRACULA5 & "" & RESET & BG&DRACULA5     #50fa7b  
  ANGLE_6L: string = RESET & FG&DRACULA6 & "" & RESET & BG&DRACULA6     #ffb86c  
  ANGLE_7L: string = RESET & FG&DRACULA7 & "" & RESET & BG&DRACULA7     #ff79c6  
  ANGLE_8L: string = RESET & FG&DRACULA8 & "" & RESET & BG&DRACULA8     #bd93f9  
  ANGLE_9L: string = RESET & FG&DRACULA9 & "" & RESET & BG&DRACULA9     #ff5555 
  ANGLE_10L: string = RESET & FG&DRACULA10 & "" & RESET & BG&DRACULA10  #f1fa8c 

  ANGLE_0R: string = RESET & FG&DRACULA0 & "" & RESET    #282A36
  ANGLE_1R: string = RESET & FG&DRACULA1 & "" & RESET    #44475a  
  ANGLE_2R: string = RESET & FG&DRACULA2 & "" & RESET    #f8f8f2  
  ANGLE_3R: string = RESET & FG&DRACULA3 & "" & RESET    #6272a4  
  ANGLE_4R: string = RESET & FG&DRACULA4 & "" & RESET    #8be9fd  
  ANGLE_5R: string = RESET & FG&DRACULA5 & "" & RESET    #50fa7b  
  ANGLE_6R: string = RESET & FG&DRACULA6 & "" & RESET    #ffb86c  
  ANGLE_7R: string = RESET & FG&DRACULA7 & "" & RESET    #ff79c6  
  ANGLE_8R: string = RESET & FG&DRACULA8 & "" & RESET    #bd93f9  
  ANGLE_9R: string = RESET & FG&DRACULA9 & "" & RESET    #ff5555 
  ANGLE_10R: string = RESET & FG&DRACULA10 & "" & RESET  #f1fa8c 
  


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
    "DejaVu Sans:style=Bold:size=10:antialias=true",
    "FontAwesome:size=14:antialias=true",
    "JetBrainsMono Nerd Font:size=16:antialias=true",
  ]


]#




