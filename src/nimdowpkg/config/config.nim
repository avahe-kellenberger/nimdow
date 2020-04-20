import parsetoml

let defaultConfig = parsetoml.parseFile("config.default.toml")

proc printActionMapping(action: string) =
  let key = defaultConfig[action]["key"]
  echo("Key: \n  ", key)
  let modifiers = defaultConfig[action]["modifiers"].arrayVal
  echo("Modifiers: ")
  for modifier in modifiers:
    echo "  ", modifier

printActionMapping("testAction")

