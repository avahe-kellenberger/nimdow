import
  nimtest,
  tag,
  config/tagsettings,
  layouts/layout,
  layouts/masterstacklayout,
  parsetoml

describe "Tag settings":

  it "parses a valid tags table":
    let testToml: string = """
    [1]
    displayString = "one"
    numMasterWindows = 2
    """

    var settings = createDefaultTagSettings()
    for i in 1 .. tagCount:
      settings[i].layoutSettings = MasterStackLayoutSettings()
      settings[i].layoutSettings.populateLayoutSettings(nil)
    let toml = parseString(testToml)
    populateTagSettings(settings, toml.tableVal)

    assert settings[1].displayString == "one"
    assert settings[1].layoutSettings.MasterStackLayoutSettings.numMasterWindows == 2

    for i in 2 .. tagCount:
      assert settings[i].displayString == $i
      assert settings[i].layoutSettings.MasterStackLayoutSettings.numMasterWindows == 1

  it "parses a valid [all] tags table":
    let testToml: string = """
    [all]
    displayString = "[]"
    numMasterWindows = 2

    [7]
    displayString = "Seven"
    numMasterWindows = 3
    """

    var settings = createDefaultTagSettings()
    for i in 1 .. tagCount:
      settings[i].layoutSettings = MasterStackLayoutSettings()
      settings[i].layoutSettings.populateLayoutSettings(nil)
    let toml = parseString(testToml)
    populateTagSettings(settings, toml.tableVal)

    for i in 1 .. tagCount:
      if i == 7:
        assert settings[i].displayString == "Seven"
        assert settings[i].layoutSettings.MasterStackLayoutSettings.numMasterWindows == 3
      else:
        assert settings[i].displayString == "[]"
        assert settings[i].layoutSettings.MasterStackLayoutSettings.numMasterWindows == 2

