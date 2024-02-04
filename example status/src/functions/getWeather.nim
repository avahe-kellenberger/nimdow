var
  dTimeStamp: Option[DateTime]
  sWeather: string = ""

proc getWeather(): string =
  if dTimeStamp.isSome and dTimeStamp.get() + initDuration(minutes = UPDATE_WEATHER) > now():
    result = sWeather # Do something with the weather information
  else:
    dTimeStamp = some(now())
    var hClient = newHttpClient()
    try:
      sWeather = WEATHER_ICON & hClient.getContent("http://wttr.in/" & CITY & "?format=%t")
      result = sWeather
    except CatchableError as e:
      echo "An error: " , e.repr
      sWeather = WEATHER_ICON & " N/A "
      result = sWeather
    finally:
      hClient.close()
