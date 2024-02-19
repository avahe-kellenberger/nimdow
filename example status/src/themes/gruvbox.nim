## Gruvbox themed arrows
const
  RESET: string  = "\x1b[0m"
  FG: string = "\x1b[38;2;"
  BG: string = "\x1b[48;2;"

  GRUVBOX0: string  = "40;40;40m"     #282828
  GRUVBOX1: string  = "204;36;29m"    #cc241d
  GRUVBOX2: string  = "152;151;26m"   #98971a
  GRUVBOX3: string  = "215;153;33m"   #d79921
  GRUVBOX4: string  = "69;133;136m"   #458588
  GRUVBOX5: string  = "177;98;134m"   #b16286
  GRUVBOX6: string  = "104;157;106m"  #689d6a
  GRUVBOX7: string  = "168;153;132m"  #a89984
  GRUVBOX8: string  = "146;131;116m"  #928374
  GRUVBOX9: string  = "251;73;52m"    #fb4934
  GRUVBOX10: string = "184;187;38m"   #b8bb26
  GRUVBOX11: string = "250;189;47m"   #fabd2f
  GRUVBOX12: string = "131;165;152m"  #83a598
  GRUVBOX13: string = "211;134;155m"  #d3869b
  GRUVBOX14: string = "142;192;124m"  #8ec07c
  GRUVBOX15: string = "235;219;178m"  #ebdbb2


  ARROW_0: string = RESET & FG&GRUVBOX0 & "" & RESET & BG&GRUVBOX0    #282828  
  ARROW_1: string = RESET & FG&GRUVBOX1 & "" & RESET & BG&GRUVBOX1    #cc241d  
  ARROW_2: string = RESET & FG&GRUVBOX2 & "" & RESET & BG&GRUVBOX2    #98971a  
  ARROW_3: string = RESET & FG&GRUVBOX3 & "" & RESET & BG&GRUVBOX3    #d79921  
  ARROW_4: string = RESET & FG&GRUVBOX4 & "" & RESET & BG&GRUVBOX4    #458588  
  ARROW_5: string = RESET & FG&GRUVBOX5 & "" & RESET & BG&GRUVBOX5    #b16286  
  ARROW_6: string = RESET & FG&GRUVBOX6 & "" & RESET & BG&GRUVBOX6    #689d6a  
  ARROW_7: string = RESET & FG&GRUVBOX7 & "" & RESET & BG&GRUVBOX7    #a89984  
  ARROW_8: string = RESET & FG&GRUVBOX8 & "" & RESET & BG&GRUVBOX8    #928374  
  ARROW_9: string = RESET & FG&GRUVBOX9 & "" & RESET & BG&GRUVBOX9    #fb4934  
  ARROW_10: string = RESET & FG&GRUVBOX10 & "" & RESET & BG&GRUVBOX10 #b8bb26 
  ARROW_11: string = RESET & FG&GRUVBOX11 & "" & RESET & BG&GRUVBOX11 #fabd2f 
  ARROW_12: string = RESET & FG&GRUVBOX12 & "" & RESET & BG&GRUVBOX12 #83a598 
  ARROW_13: string = RESET & FG&GRUVBOX13 & "" & RESET & BG&GRUVBOX13 #d3869b 
  ARROW_14: string = RESET & FG&GRUVBOX14 & "" & RESET & BG&GRUVBOX14 #8ec07c 
  ARROW_15: string = RESET & FG&GRUVBOX15 & "" & RESET & BG&GRUVBOX15 #ebdbb2 

  CIRCLE_0: string = RESET & FG&GRUVBOX0 & "" & RESET & BG&GRUVBOX0    #282828  
  CIRCLE_1: string = RESET & FG&GRUVBOX1 & "" & RESET & BG&GRUVBOX1    #cc241d  
  CIRCLE_2: string = RESET & FG&GRUVBOX2 & "" & RESET & BG&GRUVBOX2    #98971a  
  CIRCLE_3: string = RESET & FG&GRUVBOX3 & "" & RESET & BG&GRUVBOX3    #d79921  
  CIRCLE_4: string = RESET & FG&GRUVBOX4 & "" & RESET & BG&GRUVBOX4    #458588  
  CIRCLE_5: string = RESET & FG&GRUVBOX5 & "" & RESET & BG&GRUVBOX5    #b16286  
  CIRCLE_6: string = RESET & FG&GRUVBOX6 & "" & RESET & BG&GRUVBOX6    #689d6a  
  CIRCLE_7: string = RESET & FG&GRUVBOX7 & "" & RESET & BG&GRUVBOX7    #a89984  
  CIRCLE_8: string = RESET & FG&GRUVBOX8 & "" & RESET & BG&GRUVBOX8    #928374  
  CIRCLE_9: string = RESET & FG&GRUVBOX9 & "" & RESET & BG&GRUVBOX9    #fb4934  
  CIRCLE_10: string = RESET & FG&GRUVBOX10 & "" & RESET & BG&GRUVBOX10 #b8bb26 
  CIRCLE_11: string = RESET & FG&GRUVBOX11 & "" & RESET & BG&GRUVBOX11 #fabd2f 
  CIRCLE_12: string = RESET & FG&GRUVBOX12 & "" & RESET & BG&GRUVBOX12 #83a598 
  CIRCLE_13: string = RESET & FG&GRUVBOX13 & "" & RESET & BG&GRUVBOX13 #d3869b 
  CIRCLE_14: string = RESET & FG&GRUVBOX14 & "" & RESET & BG&GRUVBOX14 #8ec07c 
  CIRCLE_15: string = RESET & FG&GRUVBOX15 & "" & RESET & BG&GRUVBOX15 #ebdbb2 

  ANGLE_0: string = RESET & FG&GRUVBOX0 & "" & RESET & BG&GRUVBOX0    #282828  
  ANGLE_1: string = RESET & FG&GRUVBOX1 & "" & RESET & BG&GRUVBOX1    #cc241d  
  ANGLE_2: string = RESET & FG&GRUVBOX2 & "" & RESET & BG&GRUVBOX2    #98971a  
  ANGLE_3: string = RESET & FG&GRUVBOX3 & "" & RESET & BG&GRUVBOX3    #d79921  
  ANGLE_4: string = RESET & FG&GRUVBOX4 & "" & RESET & BG&GRUVBOX4    #458588  
  ANGLE_5: string = RESET & FG&GRUVBOX5 & "" & RESET & BG&GRUVBOX5    #b16286  
  ANGLE_6: string = RESET & FG&GRUVBOX6 & "" & RESET & BG&GRUVBOX6    #689d6a  
  ANGLE_7: string = RESET & FG&GRUVBOX7 & "" & RESET & BG&GRUVBOX7    #a89984  
  ANGLE_8: string = RESET & FG&GRUVBOX8 & "" & RESET & BG&GRUVBOX8    #928374  
  ANGLE_9: string = RESET & FG&GRUVBOX9 & "" & RESET & BG&GRUVBOX9    #fb4934  
  ANGLE_10: string = RESET & FG&GRUVBOX10 & "" & RESET & BG&GRUVBOX10 #b8bb26 
  ANGLE_11: string = RESET & FG&GRUVBOX11 & "" & RESET & BG&GRUVBOX11 #fabd2f 
  ANGLE_12: string = RESET & FG&GRUVBOX12 & "" & RESET & BG&GRUVBOX12 #83a598 
  ANGLE_13: string = RESET & FG&GRUVBOX13 & "" & RESET & BG&GRUVBOX13 #d3869b 
  ANGLE_14: string = RESET & FG&GRUVBOX14 & "" & RESET & BG&GRUVBOX14 #8ec07c 
  ANGLE_15: string = RESET & FG&GRUVBOX15 & "" & RESET & BG&GRUVBOX15 #ebdbb2 
  

#[ Nimdow config.toml

  # Window settings  Gruvbox type theme
  borderWidth = 1
  borderColorUnfocused = "#282828"
  borderColorFocused = "#b8bb26"
  borderColorUrgent = "#fb4934"
  # Bar settings
  barHeight = 28
  windowTitlePosition = "center"
  barBackgroundColor = "#a89984"
  barForegroundColor = "#282828"
  barSelectionColor = "#fabd2f"
  barUrgentColor = "#fb4934"
  barFonts = [
    "DejaVu Sans:style=Bold:size=12:antialias=true"
    "FontAwesome:size=14:antialias=true"
    "JetBrainsMono Nerd Font:size=20:antialias=true",
  ]


]#



#                
#  ARROW_GREEN: string  = RESET & FG&GREEN & "" & RESET & BG&GREEN
#  ARROW_BLUE: string   = RESET & FG&BLUE & "" & RESET & BG&BLUE
#  ARROW_ORANGE: string = RESET & FG&ORANGE & "" & RESET & BG&ORANGE
#  ARROW_RED: string    = RESET & FG&RED & "" & RESET & BG&RED
#  ARROW_WHITE: string  = RESET & FG&WHITE & "" & RESET & BG&WHITE
#  ARROW_BROWN: string  = RESET & FG&BROWN & "" & RESET & BG&BROWN

#  CIRCLE_GREEN_L: string  = RESET & FG&GREEN & "" & RESET & BG&GREEN
#  CIRCLE_GREEN_R: string  = RESET & FG&GREEN & "" & RESET
#  CIRCLE_BLUE_L: string   = RESET & FG&BLUE & "" & RESET & BG&BLUE
#  CIRCLE_BLUE_R: string   = RESET & FG&BLUE & "" & RESET
#  CIRCLE_ORANGE_L: string = RESET & FG&ORANGE & "" & RESET & BG&ORANGE
#  CIRCLE_ORANGE_R: string = RESET & FG&ORANGE & "" & RESET
#  CIRCLE_RED_L: string    = RESET & FG&RED & "" & RESET & BG&RED
#  CIRCLE_RED_R: string    = RESET & FG&RED & "" & RESET
#  CIRCLE_WHITE_L: string  = RESET & FG&WHITE & "" & RESET & BG&WHITE
#  CIRCLE_WHITE_R: string  = RESET & FG&WHITE & "" & RESET
#  CIRCLE_BROWN_L: string  = RESET & FG&BROWN & "" & RESET & BG&BROWN
#  CIRCLE_BROWN_R: string  = RESET & FG&BROWN & "" & RESET




