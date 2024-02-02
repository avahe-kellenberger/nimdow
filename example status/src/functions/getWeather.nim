import std/httpclient


const
  CITY: string = "Perth"
  ICON: string = "  "
  
proc getWeather(): string =
  var hClient = newHttpClient()
  try:
    result = ICON & hClient.getContent("http://wttr.in/" & CITY & "?format=%t")
  finally:
    hClient.close()
