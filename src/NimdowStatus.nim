import std/[os, osproc, times, strutils, httpclient, options, strformat]
# import parsetoml  <--- WiP to move all the below settings to a toml file

#++++++++++++++++++++++++++++++++++++++++++#
#                SETTINGS                  #
#++++++++++++++++++++++++++++++++++++++++++#
const
  ## main refresh intervals in seconds
  UPDATE_INTERVAL = 10
  ## update weather in minutes
  UPDATE_WEATHER = 10
  ## update checkupdate(arch) intervals in minutes
  UPDATE_UPDATES = 20
  ## select city for weather, uses wttr.in
  CITY = "Perth" #
  ## date formatting
  DATE_FORMAT = "ddd d MMM "
  ## time formatting
  TIME_FORMAT = "HH:mm "
  ## date and time formatting
  DATETIME_FORMAT = "ddd d MMM HH:mm "
  ## Regions for clickable statusbar
  REGION: string = "\x1F" # Do not edit, use Nimdows config.toml to set actions

#++++++++++++++++++++++++++++++++++++++++++#
#                ICONS                     #
#++++++++++++++++++++++++++++++++++++++++++#  
  ## weather icon, be sure to include font in the nimdow config.toml
  WEATHER_ICON = "  "
  ## date icon to display
  DATE_ICON = "  "
  ## time icon to display
  TIME_ICON = "  "
  ## memory icon to display
  MEMORY_ICON = "  "
  ## Volume icon to display
  VOL_ICON = "  "
  ## Mute icon to display
  MUTE_ICON = " 󰖁 "
  ## Keyboard Icon to display
  KB_ICON = "  "
  ## Update Icon to display
  UPDATE_ICON = "   Updates: "
  ## Battery Icons to display (array)
  BATTERY_ICON = @["  ", "  ", "  ", "  ", "  ", "  "]
  
#++++++++++++++++++++++++++++++++++++++++++#
#                  THEME                   #
#++++++++++++++++++++++++++++++++++++++++++#
# include themed arrows/circles/angle in gruvbox, dracula, nord and catpuccin
#include themes/gruvbox
#include themes/dracula
#include themes/nord
include themes/catpuccin


#++++++++++++++++++++++++++++++++++++++++++#
#           INCLUDED FUNCTIONS             #
#++++++++++++++++++++++++++++++++++++++++++#
# include getDateTime function {getDateTime()}
include functions/getDateTime
# include getBatStatus function and battery icons {getBatStatus()}
include functions/getBatStatus
# include getMemory function {getMemory()}
include functions/getMemory
# include weather function {getWeather()}
include functions/getWeather
# include Alsa volume levels function {getAlsa()}
include functions/getAlsa
# include keyboard layout function {getKeyboard()}
include functions/getKeyboard
# include updates from arch, function {getArchUpdates()}
include functions/getArchUpdates


# Function to set the string
proc setStatus(sStatus: string) =
  discard execShellCmd("xsetroot -name " & "\"" & sStatus & "\"")
  #Debug/test from the terminal
  #echo sStatus

# Main loop
proc main() =
  while true:
    #+++++++++++++++++++++++++++
    #  CREATE STATUS STRING    #
    #+++++++++++++++++++++++++++

    # PowerLine(Arrows) with Battery
    #let sStatusString = fmt"{PLINE_4}{getArchUpdates()}{REGION}{PLINE_5}{getWeather()}{REGION}{PLINE_6}{getMemory()}{REGION}{PLINE_7}{getBatStatus()}{REGION}{PLINE_8}{getAlsa()}{REGION}{PLINE_9}{getKeyboard()}{REGION}{PLINE_10}{getDateTime()}{REGION}{RESET}"
    # PowerLine(Arrows) without Battery
    #let sStatusString = fmt"{PLINE_4}{getArchUpdates()}{REGION}{PLINE_5}{getWeather()}{REGION}{PLINE_6}{getMemory()}{REGION}{PLINE_8}{getAlsa()}{REGION}{PLINE_9}{getKeyboard()}{REGION}{PLINE_10}{getDateTime()}{REGION}{RESET}"

    # PowerLine(Circles) with Battery
    #let sStatusString = fmt"{CLINE_4}{getArchUpdates()}{REGION}{CLINE_5}{getWeather()}{REGION}{CLINE_6}{getMemory()}{REGION}{CLINE_7}{getBatStatus()}{REGION}{CLINE_8}{getAlsa()}{REGION}{CLINE_9}{getKeyboard()}{REGION}{CLINE_10}{getDateTime()}{REGION}{RESET}"
    # PowerLine(Circles) without Battery
    #let sStatusString = fmt"{CLINE_4}{getArchUpdates()}{REGION}{CLINE_5}{getWeather()}{REGION}{CLINE_6}{getMemory()}{REGION}{CLINE_8}{getAlsa()}{REGION}{CLINE_9}{getKeyboard()}{REGION}{CLINE_10}{getDateTime()}{REGION}{RESET}"

    # PowerLine(Angles) with Battery
    #let sStatusString = fmt"{ALINE_4}{getArchUpdates()}{REGION}{ALINE_5}{getWeather()}{REGION}{ALINE_6}{getMemory()}{REGION}{ALINE_7}{getBatStatus()}{REGION}{ALINE_8}{getAlsa()}{REGION}{ALINE_9}{getKeyboard()}{REGION}{ALINE_10}{getDateTime()}{REGION}{RESET}"
    # PowerLine(Angles) without Battery
    #let sStatusString = fmt"{ALINE_4}{getArchUpdates()}{REGION}{ALINE_5}{getWeather()}{REGION}{ALINE_6}{getMemory()}{REGION}{ALINE_8}{getAlsa()}{REGION}{ALINE_9}{getKeyboard()}{REGION}{ALINE_10}{getDateTime()}{REGION}{RESET}"

    # RIGHT ANGLES with Battery(uses =< _10 colours for Dracula theme)
    let sStatusString = fmt"{RANGLE_11L}{getArchUpdates()}{RANGLE_11R}{REGION}{RANGLE_13L}{getWeather()}{RANGLE_13R}{REGION}{RANGLE_7L}{getMemory()}{RANGLE_7R}{REGION}{RANGLE_15L}{getBatStatus()}{RANGLE_15R}{REGION}{RANGLE_14L}{getAlsa()}{RANGLE_14R}{REGION}{RANGLE_4L}{getKeyboard()}{RANGLE_4R}{REGION}{RANGLE_12L}{getDateTime()}{RANGLE_12R}{REGION}{RESET}"
    # RIGHT ANGLES without Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{RANGLE_13L}{getArchUpdates()}{RANGLE_13R}{REGION}{RANGLE_14L}{getWeather()}{RANGLE_14R}{REGION}{RANGLE_11L}{getMemory()}{RANGLE_11R}{REGION}{RANGLE_4L}{getAlsa()}{RANGLE_4R}{REGION}{RANGLE_7L}{getKeyboard()}{RANGLE_7R}{REGION}{RANGLE_12L}{getDateTime()}{RANGLE_12R}{REGION}{RESET}"

    # LEFT ANGLES with Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{LANGLE_11L}{getArchUpdates()}{LANGLE_11R}{REGION}{LANGLE_13L}{getWeather()}{LANGLE_13R}{REGION}{LANGLE_7L}{getMemory()}{LANGLE_7R}{REGION}{LANGLE_15L}{getBatStatus()}{LANGLE_15R}{REGION}{LANGLE_14L}{getAlsa()}{LANGLE_14R}{REGION}{LANGLE_4L}{getKeyboard()}{LANGLE_4R}{REGION}{LANGLE_12L}{getDateTime()}{LANGLE_12R}{REGION}{RESET}"
    # LEFT ANGLES without Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{LANGLE_13L}{getArchUpdates()}{LANGLE_13R}{REGION}{LANGLE_14L}{getWeather()}{LANGLE_14R}{REGION}{LANGLE_11L}{getMemory()}{LANGLE_11R}{REGION}{LANGLE_4L}{getAlsa()}{LANGLE_4R}{REGION}{LANGLE_7L}{getKeyboard()}{LANGLE_7R}{REGION}{LANGLE_12L}{getDateTime()}{LANGLE_12R}{REGION}{RESET}"

    # ARROWS with Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{ARROW_11L}{getArchUpdates()}{ARROW_11R}{REGION}{ARROW_13L}{getWeather()}{ARROW_13R}{REGION}{ARROW_7L}{getMemory()}{ARROW_7R}{REGION}{ARROW_15L}{getBatStatus()}{ARROW_15R}{REGION}{ARROW_14L}{getAlsa()}{ARROW_14R}{REGION}{ARROW_4L}{getKeyboard()}{ARROW_4R}{REGION}{ARROW_12L}{getDateTime()}{ARROW_12R}{REGION}{RESET}"
    # ARROWS without Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{ARROW_11L}{getArchUpdates()}{ARROW_11R}{REGION}{ARROW_13L}{getWeather()}{ARROW_13R}{REGION}{ARROW_7L}{getMemory()}{ARROW_7R}{REGION}{ARROW_14L}{getAlsa()}{ARROW_14R}{REGION}{ARROW_4L}{getKeyboard()}{ARROW_4R}{REGION}{ARROW_12L}{getDateTime()}{ARROW_12R}{REGION}{RESET}"
    
    # CIRCLES with Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{CIRCLE_11L}{getArchUpdates()}{CIRCLE_11R}{REGION}{CIRCLE_13L}{getWeather()}{CIRCLE_13R}{REGION}{CIRCLE_7L}{getMemory()}{CIRCLE_7R}{REGION}{CIRCLE_15L}{getBatStatus()}{CIRCLE_15R}{REGION}{CIRCLE_14L}{getAlsa()}{CIRCLE_14R}{REGION}{CIRCLE_4L}{getKeyboard()}{CIRCLE_4R}{REGION}{CIRCLE_12L}{getDateTime()}{CIRCLE_12R}{REGION}{RESET}"
    # CIRCLES without Battery(uses =< _10 colours for Dracula theme)
    #let sStatusString = fmt"{CIRCLE_11L}{getArchUpdates()}{CIRCLE_11R}{REGION}{CIRCLE_13L}{getWeather()}{CIRCLE_13R}{REGION}{CIRCLE_7L}{getMemory()}{CIRCLE_7R}{REGION}{CIRCLE_14L}{getAlsa()}{CIRCLE_14R}{REGION}{CIRCLE_4L}{getKeyboard()}{CIRCLE_4R}{REGION}{CIRCLE_12L}{getDateTime()}{CIRCLE_12R}{REGION}{RESET}"

    # set the status
    setStatus(sStatusString)
    # sleep for n seconds
    sleep(UPDATE_INTERVAL * 1000)


when isMainModule:
  main()
