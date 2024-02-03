import std/[os, times, strutils, httpclient, options, strformat]
# import parsetoml  <--- WiP to move all the below settings to a toml file


#++++++++++++++++++++++++++++++++++++++++++#
#                SETTINGS                  #
#++++++++++++++++++++++++++++++++++++++++++#
const
  ## main refresh intervals in seconds
  UPDATE_INTERVAL = 40
  ## not used yet, more themes to come, see below theme section
  #THEME = "gruvbox_arrows"
  ## select city for weather, uses wttr.in
  CITY = "Perth" #
  ## update weather in minutes
  UPDATE_WEATHER = 10
  ## typically its either BAT0 or BAT1, not used yet, see getBatStatus.nim to change
  #BAT = "BAT0"
  ## date formatting
  DATE_FORMAT = "ddd d MMM"
  ## time formatting
  TIME_FORMAT = "HH:mm"
  ## date and time formatting
  DATETIME_FORMAT = "ddd d MMM HH:mm"
  ## weather icon, be sure to include font in the nimdow config.toml
  WEATHER_ICON = "  "
  ## date icon to display
  DATE_ICON = "  "
  ## time icon to display
  TIME_ICON = "  "
  ## memory icon to display
  MEMORY_ICON = "  "

#++++++++++++++++++++++++++++++++++++++++++#
#                  THEME                   #
#++++++++++++++++++++++++++++++++++++++++++#
# include themed arrows gruvbox, only one for now, more to come
include themes/gruvbox_arrows


#++++++++++++++++++++++++++++++++++++++++++#
#           INCLUDED FUNCTIONS             #
#++++++++++++++++++++++++++++++++++++++++++#
# include getDateTime function
include functions/getDateTime
# include getBatStatus function and battery icons
include functions/getBatStatus
# include getMemory function
include functions/getMemory
# include weather function
include functions/getWeather


#++++++++++++++++++++++++++++++++++++++++++#
#          STATUS FORMATTING               #
#++++++++++++++++++++++++++++++++++++++++++#
var
  STATUS_STRING = fmt"{ARROW_BROWN}{ARROW_GREEN}{getWeather()}{ARROW_BLUE}{getBatStatus()}{ARROW_ORANGE}{getMemory()}{ARROW_RED}{getDateTime()}{RESET}"


#++++++++++++++++++++++++++++++++++++++++++#
#     DO NOT EDIT BELOW THIS SECTION       #
#++++++++++++++++++++++++++++++++++++++++++#

# Function to set the string
proc setStatus(sStatus: string) = 
  discard execShellCmd("xsetroot -name " & "\"" & sStatus & "\"")

# Main loop
proc main() =
  while true:
    # create the string using themed arrows and functions
    let sStatusString = STATUS_STRING
    # set the status
    setStatus(sStatusString)
    # sleep for n seconds
    sleep(UPDATE_INTERVAL * 1000)


when isMainModule:
  main()
