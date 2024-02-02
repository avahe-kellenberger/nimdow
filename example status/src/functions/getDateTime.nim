
const
  DATE_ICON: string = "  "
  TIME_ICON: string = "  "

# get the date and time
proc getDateTime(): string =
  result = DATE_ICON & format(now(), " ddd, dd MMM HH:mm ")

proc getDate(): string =
  result = DATE_ICON & format(now(), " ddd, dd MMM ")

proc getTime(): string =
  result =  TIME_ICON & format(now(), " HH:mm ")
