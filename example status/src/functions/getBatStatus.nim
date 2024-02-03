
## Battery Icons
const
  ## Below icons are from the front awesome package
  isPlg   = " "
  is3Qrt  = "  " 
  isFull  = "  "
  isHalf  = "  "
  isLow   = ORANGE_FG & "  " & RESET
  isEmpty = RED_FG & "  " & RESET

# get the current battery status and battery level of laptop
proc getBatStatus(): string =
  # Read the first line
  let
    sCapacity = "/sys/class/power_supply/BAT0/capacity".readLines()
    sBatStats = "/sys/class/power_supply/BAT0/status".readLines()

  # Place holder for the battery icon
  var sBatIcon = ""

  # Check if battery status is in charging mode
  if sBatStats[0] == "Charging":
    sBatIcon = isPlg
  else:
    case parseInt(sCapacity[0]):
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

  # return the corresponding icon and battery level percentage
  return sBatIcon & sCapacity[0] & "% "
