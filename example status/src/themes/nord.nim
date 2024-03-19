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

  PLINE_0: string = FG&NORD0 & "" & RESET & BG&NORD0     #2E3440  
  PLINE_1: string = FG&NORD1 & "" & RESET & BG&NORD1     #3B4252  
  PLINE_2: string = FG&NORD2 & "" & RESET & BG&NORD2     #434C5E  
  PLINE_3: string = FG&NORD3 & "" & RESET & BG&NORD3     #4C566A  
  PLINE_4: string = FG&NORD4 & "" & RESET & BG&NORD4     #D8DEE9  
  PLINE_5: string = FG&NORD5 & "" & RESET & BG&NORD5     #E5E9F0  
  PLINE_6: string = FG&NORD6 & "" & RESET & BG&NORD6     #ECEFF4  
  PLINE_7: string = FG&NORD7 & "" & RESET & BG&NORD7     #8FBCBB  
  PLINE_8: string = FG&NORD8 & "" & RESET & BG&NORD8     #88C0D0  
  PLINE_9: string = FG&NORD9 & "" & RESET & BG&NORD9     #81A1C1  
  PLINE_10: string = FG&NORD10 & "" & RESET & BG&NORD10  #5E81AC 
  PLINE_11: string = FG&NORD11 & "" & RESET & BG&NORD11  #BF616A 
  PLINE_12: string = FG&NORD12 & "" & RESET & BG&NORD12  #D08770 
  PLINE_13: string = FG&NORD13 & "" & RESET & BG&NORD13  #EBCB8B 
  PLINE_14: string = FG&NORD14 & "" & RESET & BG&NORD14  #A3BE8C 
  PLINE_15: string = FG&NORD15 & "" & RESET & BG&NORD15  #B48EAD

  CLINE_0: string = FG&NORD0 & "" & RESET & BG&NORD0    #2E3440  
  CLINE_1: string = FG&NORD1 & "" & RESET & BG&NORD1    #3B4252  
  CLINE_2: string = FG&NORD2 & "" & RESET & BG&NORD2    #434C5E  
  CLINE_3: string = FG&NORD3 & "" & RESET & BG&NORD3    #4C566A  
  CLINE_4: string = FG&NORD4 & "" & RESET & BG&NORD4    #D8DEE9  
  CLINE_5: string = FG&NORD5 & "" & RESET & BG&NORD5    #E5E9F0  
  CLINE_6: string = FG&NORD6 & "" & RESET & BG&NORD6    #ECEFF4  
  CLINE_7: string = FG&NORD7 & "" & RESET & BG&NORD7    #8FBCBB  
  CLINE_8: string = FG&NORD8 & "" & RESET & BG&NORD8    #88C0D0  
  CLINE_9: string = FG&NORD9 & "" & RESET & BG&NORD9    #81A1C1  
  CLINE_10: string = FG&NORD10 & "" & RESET & BG&NORD10 #5E81AC 
  CLINE_11: string = FG&NORD11 & "" & RESET & BG&NORD11 #BF616A 
  CLINE_12: string = FG&NORD12 & "" & RESET & BG&NORD12 #D08770 
  CLINE_13: string = FG&NORD13 & "" & RESET & BG&NORD13 #EBCB8B 
  CLINE_14: string = FG&NORD14 & "" & RESET & BG&NORD14 #A3BE8C 
  CLINE_15: string = FG&NORD15 & "" & RESET & BG&NORD15 #B48EAD 

  ALINE_0: string = FG&NORD0 & "" & RESET & BG&NORD0     #2E3440  
  ALINE_1: string = FG&NORD1 & "" & RESET & BG&NORD1     #3B4252  
  ALINE_2: string = FG&NORD2 & "" & RESET & BG&NORD2     #434C5E  
  ALINE_3: string = FG&NORD3 & "" & RESET & BG&NORD3     #4C566A  
  ALINE_4: string = FG&NORD4 & "" & RESET & BG&NORD4     #D8DEE9  
  ALINE_5: string = FG&NORD5 & "" & RESET & BG&NORD5     #E5E9F0  
  ALINE_6: string = FG&NORD6 & "" & RESET & BG&NORD6     #ECEFF4  
  ALINE_7: string = FG&NORD7 & "" & RESET & BG&NORD7     #8FBCBB  
  ALINE_8: string = FG&NORD8 & "" & RESET & BG&NORD8     #88C0D0  
  ALINE_9: string = FG&NORD9 & "" & RESET & BG&NORD9     #81A1C1  
  ALINE_10: string = FG&NORD10 & "" & RESET & BG&NORD10  #5E81AC 
  ALINE_11: string = FG&NORD11 & "" & RESET & BG&NORD11  #BF616A 
  ALINE_12: string = FG&NORD12 & "" & RESET & BG&NORD12  #D08770 
  ALINE_13: string = FG&NORD13 & "" & RESET & BG&NORD13  #EBCB8B 
  ALINE_14: string = FG&NORD14 & "" & RESET & BG&NORD14  #A3BE8C 
  ALINE_15: string = FG&NORD15 & "" & RESET & BG&NORD15  #B48EAD 



  ARROW_0L: string = RESET & FG&NORD0 & "" & RESET & BG&NORD0     #2E3440  
  ARROW_1L: string = RESET & FG&NORD1 & "" & RESET & BG&NORD1     #3B4252  
  ARROW_2L: string = RESET & FG&NORD2 & "" & RESET & BG&NORD2     #434C5E  
  ARROW_3L: string = RESET & FG&NORD3 & "" & RESET & BG&NORD3     #4C566A  
  ARROW_4L: string = RESET & FG&NORD4 & "" & RESET & BG&NORD4     #D8DEE9  
  ARROW_5L: string = RESET & FG&NORD5 & "" & RESET & BG&NORD5     #E5E9F0  
  ARROW_6L: string = RESET & FG&NORD6 & "" & RESET & BG&NORD6     #ECEFF4  
  ARROW_7L: string = RESET & FG&NORD7 & "" & RESET & BG&NORD7     #8FBCBB  
  ARROW_8L: string = RESET & FG&NORD8 & "" & RESET & BG&NORD8     #88C0D0  
  ARROW_9L: string = RESET & FG&NORD9 & "" & RESET & BG&NORD9     #81A1C1  
  ARROW_10L: string = RESET & FG&NORD10 & "" & RESET & BG&NORD10  #5E81AC 
  ARROW_11L: string = RESET & FG&NORD11 & "" & RESET & BG&NORD11  #BF616A 
  ARROW_12L: string = RESET & FG&NORD12 & "" & RESET & BG&NORD12  #D08770 
  ARROW_13L: string = RESET & FG&NORD13 & "" & RESET & BG&NORD13  #EBCB8B 
  ARROW_14L: string = RESET & FG&NORD14 & "" & RESET & BG&NORD14  #A3BE8C 
  ARROW_15L: string = RESET & FG&NORD15 & "" & RESET & BG&NORD15  #B48EAD 

  ARROW_0R: string = RESET & FG&NORD0 & "" & RESET     #2E3440  
  ARROW_1R: string = RESET & FG&NORD1 & "" & RESET     #3B4252  
  ARROW_2R: string = RESET & FG&NORD2 & "" & RESET     #434C5E  
  ARROW_3R: string = RESET & FG&NORD3 & "" & RESET     #4C566A  
  ARROW_4R: string = RESET & FG&NORD4 & "" & RESET     #D8DEE9  
  ARROW_5R: string = RESET & FG&NORD5 & "" & RESET     #E5E9F0  
  ARROW_6R: string = RESET & FG&NORD6 & "" & RESET     #ECEFF4  
  ARROW_7R: string = RESET & FG&NORD7 & "" & RESET     #8FBCBB  
  ARROW_8R: string = RESET & FG&NORD8 & "" & RESET     #88C0D0  
  ARROW_9R: string = RESET & FG&NORD9 & "" & RESET     #81A1C1  
  ARROW_10R: string = RESET & FG&NORD10 & "" & RESET   #5E81AC 
  ARROW_11R: string = RESET & FG&NORD11 & "" & RESET   #BF616A 
  ARROW_12R: string = RESET & FG&NORD12 & "" & RESET   #D08770 
  ARROW_13R: string = RESET & FG&NORD13 & "" & RESET   #EBCB8B 
  ARROW_14R: string = RESET & FG&NORD14 & "" & RESET   #A3BE8C 
  ARROW_15R: string = RESET & FG&NORD15 & "" & RESET   #B48EAD 

  CIRCLE_0L: string = RESET & FG&NORD0 & "" & RESET & BG&NORD0    #2E3440  
  CIRCLE_1L: string = RESET & FG&NORD1 & "" & RESET & BG&NORD1    #3B4252  
  CIRCLE_2L: string = RESET & FG&NORD2 & "" & RESET & BG&NORD2    #434C5E  
  CIRCLE_3L: string = RESET & FG&NORD3 & "" & RESET & BG&NORD3    #4C566A  
  CIRCLE_4L: string = RESET & FG&NORD4 & "" & RESET & BG&NORD4    #D8DEE9  
  CIRCLE_5L: string = RESET & FG&NORD5 & "" & RESET & BG&NORD5    #E5E9F0  
  CIRCLE_6L: string = RESET & FG&NORD6 & "" & RESET & BG&NORD6    #ECEFF4  
  CIRCLE_7L: string = RESET & FG&NORD7 & "" & RESET & BG&NORD7    #8FBCBB  
  CIRCLE_8L: string = RESET & FG&NORD8 & "" & RESET & BG&NORD8    #88C0D0  
  CIRCLE_9L: string = RESET & FG&NORD9 & "" & RESET & BG&NORD9    #81A1C1  
  CIRCLE_10L: string = RESET & FG&NORD10 & "" & RESET & BG&NORD10 #5E81AC 
  CIRCLE_11L: string = RESET & FG&NORD11 & "" & RESET & BG&NORD11 #BF616A 
  CIRCLE_12L: string = RESET & FG&NORD12 & "" & RESET & BG&NORD12 #D08770 
  CIRCLE_13L: string = RESET & FG&NORD13 & "" & RESET & BG&NORD13 #EBCB8B 
  CIRCLE_14L: string = RESET & FG&NORD14 & "" & RESET & BG&NORD14 #A3BE8C 
  CIRCLE_15L: string = RESET & FG&NORD15 & "" & RESET & BG&NORD15 #B48EAD 

  CIRCLE_0R: string = RESET & FG&NORD0 & "" & RESET    #2E3440  
  CIRCLE_1R: string = RESET & FG&NORD1 & "" & RESET    #3B4252  
  CIRCLE_2R: string = RESET & FG&NORD2 & "" & RESET    #434C5E  
  CIRCLE_3R: string = RESET & FG&NORD3 & "" & RESET    #4C566A  
  CIRCLE_4R: string = RESET & FG&NORD4 & "" & RESET    #D8DEE9  
  CIRCLE_5R: string = RESET & FG&NORD5 & "" & RESET    #E5E9F0  
  CIRCLE_6R: string = RESET & FG&NORD6 & "" & RESET    #ECEFF4  
  CIRCLE_7R: string = RESET & FG&NORD7 & "" & RESET    #8FBCBB  
  CIRCLE_8R: string = RESET & FG&NORD8 & "" & RESET    #88C0D0  
  CIRCLE_9R: string = RESET & FG&NORD9 & "" & RESET    #81A1C1  
  CIRCLE_10R: string = RESET & FG&NORD10 & "" & RESET  #5E81AC 
  CIRCLE_11R: string = RESET & FG&NORD11 & "" & RESET  #BF616A 
  CIRCLE_12R: string = RESET & FG&NORD12 & "" & RESET  #D08770 
  CIRCLE_13R: string = RESET & FG&NORD13 & "" & RESET  #EBCB8B 
  CIRCLE_14R: string = RESET & FG&NORD14 & "" & RESET  #A3BE8C 
  CIRCLE_15R: string = RESET & FG&NORD15 & "" & RESET  #B48EAD 

  ANGLE_0L: string = RESET & FG&NORD0 & "" & RESET & BG&NORD0     #2E3440  
  ANGLE_1L: string = RESET & FG&NORD1 & "" & RESET & BG&NORD1     #3B4252  
  ANGLE_2L: string = RESET & FG&NORD2 & "" & RESET & BG&NORD2     #434C5E  
  ANGLE_3L: string = RESET & FG&NORD3 & "" & RESET & BG&NORD3     #4C566A  
  ANGLE_4L: string = RESET & FG&NORD4 & "" & RESET & BG&NORD4     #D8DEE9  
  ANGLE_5L: string = RESET & FG&NORD5 & "" & RESET & BG&NORD5     #E5E9F0  
  ANGLE_6L: string = RESET & FG&NORD6 & "" & RESET & BG&NORD6     #ECEFF4  
  ANGLE_7L: string = RESET & FG&NORD7 & "" & RESET & BG&NORD7     #8FBCBB  
  ANGLE_8L: string = RESET & FG&NORD8 & "" & RESET & BG&NORD8     #88C0D0  
  ANGLE_9L: string = RESET & FG&NORD9 & "" & RESET & BG&NORD9     #81A1C1  
  ANGLE_10L: string = RESET & FG&NORD10 & "" & RESET & BG&NORD10  #5E81AC 
  ANGLE_11L: string = RESET & FG&NORD11 & "" & RESET & BG&NORD11  #BF616A 
  ANGLE_12L: string = RESET & FG&NORD12 & "" & RESET & BG&NORD12  #D08770 
  ANGLE_13L: string = RESET & FG&NORD13 & "" & RESET & BG&NORD13  #EBCB8B 
  ANGLE_14L: string = RESET & FG&NORD14 & "" & RESET & BG&NORD14  #A3BE8C 
  ANGLE_15L: string = RESET & FG&NORD15 & "" & RESET & BG&NORD15  #B48EAD 

  ANGLE_0R: string = RESET & FG&NORD0 & "" & RESET     #2E3440  
  ANGLE_1R: string = RESET & FG&NORD1 & "" & RESET     #3B4252  
  ANGLE_2R: string = RESET & FG&NORD2 & "" & RESET     #434C5E  
  ANGLE_3R: string = RESET & FG&NORD3 & "" & RESET     #4C566A  
  ANGLE_4R: string = RESET & FG&NORD4 & "" & RESET     #D8DEE9  
  ANGLE_5R: string = RESET & FG&NORD5 & "" & RESET     #E5E9F0  
  ANGLE_6R: string = RESET & FG&NORD6 & "" & RESET     #ECEFF4  
  ANGLE_7R: string = RESET & FG&NORD7 & "" & RESET     #8FBCBB  
  ANGLE_8R: string = RESET & FG&NORD8 & "" & RESET     #88C0D0  
  ANGLE_9R: string = RESET & FG&NORD9 & "" & RESET     #81A1C1  
  ANGLE_10R: string = RESET & FG&NORD10 & "" & RESET   #5E81AC 
  ANGLE_11R: string = RESET & FG&NORD11 & "" & RESET   #BF616A 
  ANGLE_12R: string = RESET & FG&NORD12 & "" & RESET   #D08770 
  ANGLE_13R: string = RESET & FG&NORD13 & "" & RESET   #EBCB8B 
  ANGLE_14R: string = RESET & FG&NORD14 & "" & RESET   #A3BE8C 
  ANGLE_15R: string = RESET & FG&NORD15 & "" & RESET   #B48EAD 


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
  barFonts = [
    "DejaVu Sans:style=Bold:size=10:antialias=true",
    "FontAwesome:size=14:antialias=true",
    "JetBrainsMono Nerd Font:size=16:antialias=true",
  ]

]#




