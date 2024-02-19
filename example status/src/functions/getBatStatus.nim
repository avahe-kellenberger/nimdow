
## Battery Icons
const
  ## Below icons are from the front awesome package
  isPlg =   "  "
  is3Qrt =  "  "
  isFull =  "  "
  isHalf =  "  "
  isLow =   "  "
  isEmpty = "  "

# get the current battery status and battery level of laptop
proc getBatStatus(): string =
  # Make sure we are running on a laptop with BAT0, change to BAT1 if needed
  if not fileExists("/sys/class/power_supply/BAT0/capacity"):
    return isEmpty & "N/A "
  else:
    # Read the first line of the these files
    let sCapacity = "/sys/class/power_supply/BAT0/capacity".readLines()
    let sBatStats = "/sys/class/power_supply/BAT0/status".readLines()

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
    # return the corresponding icon and battery level 
    return sBatIcon & sCapacity[0] & "% "
