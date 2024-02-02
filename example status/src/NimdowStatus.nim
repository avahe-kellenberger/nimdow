import std/[os, times, strutils]

# Set the refresh intervals(seconds)
const
  UPDATE_INTERVAL = 40

# include themed arrows gruvbox
include themes/gruvbox_arrows

# include getDateTime function
include functions/getDateTime

# include getBatStatus function and battery icons
include functions/getBatStatus

# include getMemory function
include functions/getMemory

# include weather function
include functions/getWeather


# Function to set the string aka status
proc setStatus(sStatus: string) = 
  discard execShellCmd("xsetroot -name " & "\"" & sStatus & "\"")

# Main loop
proc main() =
  while true:
    # create the string using themed arrows and functions
    let sStatusString = ARROW_BROWN & ARROW_GREEN & getWeather() & ARROW_BLUE & getBatStatus() & ARROW_ORANGE & getMemory() & ARROW_RED & getDateTime()
    # set the status
    setStatus(sStatusString)
    # sleep for n seconds
    sleep(UPDATE_INTERVAL * 1000)


when isMainModule:
  main()
