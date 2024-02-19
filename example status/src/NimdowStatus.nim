import std/[os, osproc, times, strutils, httpclient, options, strformat]
# import parsetoml  <--- WiP to move all the below settings to a toml file

#++++++++++++++++++++++++++++++++++++++++++#
#                SETTINGS                  #
#++++++++++++++++++++++++++++++++++++++++++#
const
  ## main refresh intervals in seconds
  UPDATE_INTERVAL = 10
  ## not used yet, more themes to come, see below theme section
  #THEME = "gruvbox_arrows"
  ## select city for weather, uses wttr.in
  CITY = "Perth" #
  ## update weather in minutes
  UPDATE_WEATHER = 10
  ## update checkupdate intervals in minutes
  UPDATE_UPDATES = 20
  ## typically its either BAT0 or BAT1, not used yet, see getBatStatus.nim to change
  #BAT = "BAT0"
  ## date formatting
  DATE_FORMAT = "ddd d MMM "
  ## time formatting
  TIME_FORMAT = "HH:mm "
  ## date and time formatting
  DATETIME_FORMAT = "ddd d MMM HH:mm "
  ## weather icon, be sure to include font in the nimdow config.toml
  WEATHER_ICON = "  "
  ## date icon to display
  DATE_ICON = "  "
  ## time icon to display
  TIME_ICON = "  "
  ## memory icon to display
  MEMORY_ICON = "  "
  ## Volume icon to display
  VOL_ICON = " 󰕾 "
  ## Mute icon to display
  MUTE_ICON = " 󰖁 "
  ## Keyboard Icon to display
  KB_ICON = "  "
  ## Update Icon to display
  UPDATE_ICON = "   Updates: "
  ## Regions for clickable statusbar
  REGION: string = "\x1F" # Do not edit, use Nimdows config.toml to set

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

    # ARROWS with Battery
    #let sStatusString = fmt"{ARROW_4}{getArchUpdates()}{REGION}{ARROW_5}{getWeather()}{REGION}{ARROW_6}{getMemory()}{REGION}{ARROW_7}{getBatStatus()}{REGION}{ARROW_8}{getAlsa()}{REGION}{ARROW_9}{getKeyboard()}{REGION}{ARROW_10}{getDateTime()}{RESET}"

    # ARROWS without Battery
    #let sStatusString = fmt"{ARROW_4}{getArchUpdates()}{REGION}{ARROW_5}{getWeather()}{REGION}{ARROW_6}{getMemory()}{REGION}{ARROW_8}{getAlsa()}{REGION}{ARROW_9}{getKeyboard()}{REGION}{ARROW_10}{getDateTime()}{RESET}"
    
    # CIRCLES with Battery
    let sStatusString = fmt"{CIRCLE_11}{getArchUpdates()}{REGION}{CIRCLE_13}{getWeather()}{REGION}{CIRCLE_7}{getMemory()}{REGION}{CIRCLE_15}{getBatStatus()}{REGION}{CIRCLE_11}{getAlsa()}{REGION}{CIRCLE_4}{getKeyboard()}{REGION}{CIRCLE_12}{getDateTime()}{RESET}"

    # CIRCLES without Battery
    #let sStatusString = fmt"{CIRCLE_4}{getArchUpdates()}{REGION}{CIRCLE_5}{getWeather()}{REGION}{CIRCLE_6}{getMemory()}{REGION}{CIRCLE_8}{getAlsa()}{REGION}{CIRCLE_9}{getKeyboard()}{REGION}{CIRCLE_10}{getDateTime()}{RESET}"

    # ANGLES with Battery
    #let sStatusString = fmt"{ANGLE_11}{getArchUpdates()}{REGION}{ANGLE_13}{getWeather()}{REGION}{ANGLE_7}{getMemory()}{REGION}{ANGLE_15}{getBatStatus()}{REGION}{ANGLE_11}{getAlsa()}{REGION}{ANGLE_4}{getKeyboard()}{REGION}{ANGLE_12}{getDateTime()}{RESET}"

    # ANGLES without Battery
    #let sStatusString = fmt"{ANGLE_4}{getArchUpdates()}{REGION}{ANGLE_5}{getWeather()}{REGION}{ANGLE_6}{getMemory()}{REGION}{ANGLE_8}{getAlsa()}{REGION}{ANGLE_9}{getKeyboard()}{REGION}{ANGLE_10}{getDateTime()}{RESET}"

    # set the status
    setStatus(sStatusString)
    # sleep for n seconds
    sleep(UPDATE_INTERVAL * 1000)


when isMainModule:
  main()
