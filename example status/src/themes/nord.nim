## Nord themed arrows
const
  RESET: string  = "\x1b[0m"
  FG: string = "\x1b[38;2;"
  BG: string = "\x1b[48;2;"


  NORD0: string  = "46;52;64m"    #2E3440
  NORD1: string  = "59;66;83m"    #3B4252
  NORD2: string  = "67;76;94m"    #434C5E
  NORD3: string  = "76;86;106m"   #4C566A
  NORD4: string  = "216;222;233m" #D8DEE9
  NORD5: string  = "229;233;240m" #E5E9F0
  NORD6: string  = "236;239;244m" #ECEFF4
  NORD7: string  = "143;188;187m" #8FBCBB
  NORD8: string  = "136;192;208m" #88C0D0
  NORD9: string  = "129;161;193m" #81A1C1
  NORD10: string = "94;129;172m"  #5E81AC
  NORD11: string = "191;97;106m"  #BF616A
  NORD12: string = "208;135;112m" #D08770
  NORD13: string = "235;203;139m" #EBCB8B
  NORD14: string = "163;190;140m" #A3BE8C
  NORD15: string = "180;142;173m" #B48EAD


  ARROW_0: string = RESET & FG&NORD0 & "" & RESET & BG&NORD0     #2E3440  
  ARROW_1: string = RESET & FG&NORD1 & "" & RESET & BG&NORD1     #3B4252  
  ARROW_2: string = RESET & FG&NORD2 & "" & RESET & BG&NORD2     #434C5E  
  ARROW_3: string = RESET & FG&NORD3 & "" & RESET & BG&NORD3     #4C566A  
  ARROW_4: string = RESET & FG&NORD4 & "" & RESET & BG&NORD4     #D8DEE9  
  ARROW_5: string = RESET & FG&NORD5 & "" & RESET & BG&NORD5     #E5E9F0  
  ARROW_6: string = RESET & FG&NORD6 & "" & RESET & BG&NORD6     #ECEFF4  
  ARROW_7: string = RESET & FG&NORD7 & "" & RESET & BG&NORD7     #8FBCBB  
  ARROW_8: string = RESET & FG&NORD8 & "" & RESET & BG&NORD8     #88C0D0  
  ARROW_9: string = RESET & FG&NORD9 & "" & RESET & BG&NORD9     #81A1C1  
  ARROW_10: string = RESET & FG&NORD10 & "" & RESET & BG&NORD10  #5E81AC 
  ARROW_11: string = RESET & FG&NORD11 & "" & RESET & BG&NORD11  #BF616A 
  ARROW_12: string = RESET & FG&NORD12 & "" & RESET & BG&NORD12  #D08770 
  ARROW_13: string = RESET & FG&NORD13 & "" & RESET & BG&NORD13  #EBCB8B 
  ARROW_14: string = RESET & FG&NORD14 & "" & RESET & BG&NORD14  #A3BE8C 
  ARROW_15: string = RESET & FG&NORD15 & "" & RESET & BG&NORD15  #B48EAD 

  CIRCLE_0: string = RESET & FG&NORD0 & "" & RESET & BG&NORD0    #2E3440  
  CIRCLE_1: string = RESET & FG&NORD1 & "" & RESET & BG&NORD1    #3B4252  
  CIRCLE_2: string = RESET & FG&NORD2 & "" & RESET & BG&NORD2    #434C5E  
  CIRCLE_3: string = RESET & FG&NORD3 & "" & RESET & BG&NORD3    #4C566A  
  CIRCLE_4: string = RESET & FG&NORD4 & "" & RESET & BG&NORD4    #D8DEE9  
  CIRCLE_5: string = RESET & FG&NORD5 & "" & RESET & BG&NORD5    #E5E9F0  
  CIRCLE_6: string = RESET & FG&NORD6 & "" & RESET & BG&NORD6    #ECEFF4  
  CIRCLE_7: string = RESET & FG&NORD7 & "" & RESET & BG&NORD7    #8FBCBB  
  CIRCLE_8: string = RESET & FG&NORD8 & "" & RESET & BG&NORD8    #88C0D0  
  CIRCLE_9: string = RESET & FG&NORD9 & "" & RESET & BG&NORD9    #81A1C1  
  CIRCLE_10: string = RESET & FG&NORD10 & "" & RESET & BG&NORD10 #5E81AC 
  CIRCLE_11: string = RESET & FG&NORD11 & "" & RESET & BG&NORD11 #BF616A 
  CIRCLE_12: string = RESET & FG&NORD12 & "" & RESET & BG&NORD12 #D08770 
  CIRCLE_13: string = RESET & FG&NORD13 & "" & RESET & BG&NORD13 #EBCB8B 
  CIRCLE_14: string = RESET & FG&NORD14 & "" & RESET & BG&NORD14 #A3BE8C 
  CIRCLE_15: string = RESET & FG&NORD15 & "" & RESET & BG&NORD15 #B48EAD 

  ANGLE_0: string = RESET & FG&NORD0 & "" & RESET & BG&NORD0     #2E3440  
  ANGLE_1: string = RESET & FG&NORD1 & "" & RESET & BG&NORD1     #3B4252  
  ANGLE_2: string = RESET & FG&NORD2 & "" & RESET & BG&NORD2     #434C5E  
  ANGLE_3: string = RESET & FG&NORD3 & "" & RESET & BG&NORD3     #4C566A  
  ANGLE_4: string = RESET & FG&NORD4 & "" & RESET & BG&NORD4     #D8DEE9  
  ANGLE_5: string = RESET & FG&NORD5 & "" & RESET & BG&NORD5     #E5E9F0  
  ANGLE_6: string = RESET & FG&NORD6 & "" & RESET & BG&NORD6     #ECEFF4  
  ANGLE_7: string = RESET & FG&NORD7 & "" & RESET & BG&NORD7     #8FBCBB  
  ANGLE_8: string = RESET & FG&NORD8 & "" & RESET & BG&NORD8     #88C0D0  
  ANGLE_9: string = RESET & FG&NORD9 & "" & RESET & BG&NORD9     #81A1C1  
  ANGLE_10: string = RESET & FG&NORD10 & "" & RESET & BG&NORD10  #5E81AC 
  ANGLE_11: string = RESET & FG&NORD11 & "" & RESET & BG&NORD11  #BF616A 
  ANGLE_12: string = RESET & FG&NORD12 & "" & RESET & BG&NORD12  #D08770 
  ANGLE_13: string = RESET & FG&NORD13 & "" & RESET & BG&NORD13  #EBCB8B 
  ANGLE_14: string = RESET & FG&NORD14 & "" & RESET & BG&NORD14  #A3BE8C 
  ANGLE_15: string = RESET & FG&NORD15 & "" & RESET & BG&NORD15  #B48EAD 


#[
[settings]
  # Window settings - Nord type theme
  borderWidth = 1
  borderColorUnfocused = "#4c566a"
  borderColorFocused = "#eceff4"
  borderColorUrgent = "#bf616a"
  # Bar settings
  barHeight = 26
  windowTitlePosition = "center"
  barBackgroundColor = "#4c566a"
  barForegroundColor = "#2e3440"
  barSelectionColor = "#d8dee9"
  barUrgentColor = "#bf616a"
  barFonts = ["Noto:style=Bold:size=11:antialias=true", 
              "JetBrainsMono Nerd Font Mono:size=19:antialias=true"]

]#




