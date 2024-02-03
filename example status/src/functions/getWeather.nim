import std/[httpclient, options]


const
  # set refresh frequency in minutes
  INTERVALS: int = 10
  CITY: string = "Perth"
  ICON: string = "  "

var
  dTimeStamp: Option[DateTime]
  sWeather: string = ""

proc getWeather(): string =
  if dTimeStamp.isSome and dTimeStamp.get() + initDuration(minutes = INTERVALS) > now():
    result = sWeather # Do something with the weather information
  else:
    dTimeStamp = some(now())
    var hClient = newHttpClient()
    try:
      sWeather = ICON & hClient.getContent("http://wttr.in/" & CITY & "?format=%t")
      result = sWeather
    finally:
      hClient.close()
