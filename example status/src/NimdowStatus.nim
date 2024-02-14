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

#++++++++++++++++++++++++++++++++++++++++++#
#                  THEME                   #
#++++++++++++++++++++++++++++++++++++++++++#
# include themed arrows gruvbox or dracula, more to come
#include themes/gruvbox_arrows
#include themes/dracula_arrows
include themes/nord_arrows


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

# Main loop
proc main() =
  while true:
    #+++++++++++++++++++++++++++
    #  CREATE STATUS STRING    #
    #+++++++++++++++++++++++++++
    let sStatusString = fmt"{ARROW_6}{getArchUpdates()}{ARROW_7}{getWeather()}{ARROW_8}{getMemory()}{ARROW_9}{getBatStatus()}{ARROW_10}{getAlsa()}{ARROW_11}{getKeyboard()}{ARROW_12}{getDateTime()}{RESET}"
    #let sStatusString = fmt"{CIRCLE_GREEN_L}{getWeather()}{CIRCLE_GREEN_R}{CIRCLE_ORANGE_L}{getBatStatus()}{CIRCLE_ORANGE_R}{CIRCLE_BLUE_L}{getMemory()}{CIRCLE_BLUE_R}{CIRCLE_RED_L}{getDateTime()}{CIRCLE_RED_R}{RESET}"
    # set the status
    setStatus(sStatusString)
    # sleep for n seconds
    sleep(UPDATE_INTERVAL * 1000)


when isMainModule:
  main()
