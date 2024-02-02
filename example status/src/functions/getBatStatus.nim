
## Battery Icons
const
  isPlg   = " "   #" 󰚥 "#Nerd fonts
  is3Qrt  = "  " 
  isFull  = "  "
  isHalf  = "  "
  isLow   = ORANGE_FG & "  " & RESET
  isEmpty = RED_FG & "  " & RESET


# get the current battery status and battery level of laptop
proc getBatStatus(): string =
   #Battery Level Percentage, change to BAT1 if needed
  let fCapacity = open("/sys/class/power_supply/BAT0/capacity")
  defer: fCapacity.close
  #Battery Status
  let fBatStatus = open("/sys/class/power_supply/BAT0/status")
  defer: fBatStatus.close

  # Read the first line
  let
    sCapacity = fCapacity.readline()
    sBatStats = fBatStatus.readline()

  # Place holder for the battery icon
  var sBatIcon = ""

  # Check if battery status is in charging mode
  if sBatStats == "Charging":
    sBatIcon = isPlg
  else:
    case parseInt(sCapacity):
    of 10..35:
      sBatIcon = isLow
    of 36..59:
      sBatIcon = isHalf
    of 60..85:
      sBatIcon = is3Qrt
    of 86..100:
      sBatIcon = isFull
    else:
      sBatIcon = isEmpty

  # return the corrisponding icon and battery level percentage
  return sBatIcon & sCapacity & "% "
