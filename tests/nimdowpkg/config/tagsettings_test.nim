import
  tag,
  config/tagsettings,
  parsetoml

test "valid tags table":
  let testToml: string = """
  [1]
  displayString = "one"
  numMasterWindows = 2
  """

  var settings = createDefaultTagSettings()
  let toml = parseString(testToml)
  populateTagSettings(settings, toml.tableVal)

  assert settings[1].displayString == "one"
  assert settings[1].numMasterWindows == 2

  for i in 2 .. tagCount:
    assert settings[i].displayString == $i
    assert settings[i].numMasterWindows == 1

test "valid all tags table":
  let testToml: string = """
  [all]
  displayString = "[]"
  numMasterWindows = 2
  """

  var settings = createDefaultTagSettings()
  let toml = parseString(testToml)
  populateTagSettings(settings, toml.tableVal)


  for i in 1 .. tagCount:
    assert settings[i].displayString == "[]"
    assert settings[i].numMasterWindows == 2



