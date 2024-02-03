# get the date and time
proc getDateTime(): string =
  result = DATE_ICON & format(now(), DATETIME_FORMAT)

proc getDate(): string =
  result = DATE_ICON & format(now(), DATE_FORMAT)

proc getTime(): string =
  result =  TIME_ICON & format(now(), TIME_FORMAT)
