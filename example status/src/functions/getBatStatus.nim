# get the current battery status and battery level of laptop
proc getBatStatus(): string =
  # Make sure we are running on a laptop with BAT0, change to BAT1 if needed
  if not fileExists("/sys/class/power_supply/BAT0/capacity"):
    return BATTERY_ICON[1] & "N/A" #isEmpty
  else:
    # Read the first line of the these files

    let sBatStats = readLines("/sys/class/power_supply/BAT0/status", 1)
    let sCapacity = readLines("/sys/class/power_supply/BAT0/capacity", 1)

  # Place holder for the battery icon
    var sBatIcon = ""

    # Check if battery status is in charging mode
    if sBatStats[0] == "Charging":
      sBatIcon = BATTERY_ICON[0] #isPlg
    else:
      case parseInt(sCapacity[0]):
      of 10..35:
        sBatIcon = BATTERY_ICON[2] #isLow
      of 36..59:
        sBatIcon = BATTERY_ICON[3] #isHalf
      of 60..85:
        sBatIcon = BATTERY_ICON[4] #is3Qrt
      of 86..100:
        sBatIcon = BATTERY_ICON[5] #isFull
      else:
        sBatIcon = BATTERY_ICON[1] #isEmpty
    # return the corresponding icon and battery level 
    return sBatIcon & sCapacity[0] & "% "
