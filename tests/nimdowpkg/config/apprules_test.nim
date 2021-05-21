import
  taginfo,
  config/apprules,
  parsetoml

test "valid single app rule":
  let testToml: string = """
  [[appRule]]
  title = "Element | Billybob"
  class = "Element"
  instance = "element"
  monitor = 2
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  let rules: seq[AppRule] = parseAppRules(toml.tableVal[])

  let firstRule = rules[0]
  doAssert firstRule.title == "Element | Billybob"
  doAssert firstRule.class == "Element"
  doAssert firstRule.instance == "element"
  doAssert firstRule.monitorID == 2.Positive
  doAssert firstRule.tagIDs == @[ 1.TagID, 9 ]

test "valid multiple app rules":
  let testToml: string = """
  [[appRule]]
  title = "Element | Foobar"
  class = "Element"
  instance = "element"
  monitor = 2
  tags = [ 1, 9 ]
  state = "Fullscreen"

  [[appRule]]
  class = "st"
  instance = "st"
  monitor = 1
  tags = [ 3, 7, 8 ]
  state = "FLOATING"

  [[appRule]]
  class = "st"
  instance = "st"
  monitor = 1
  tags = [ 3, 7, 8 ]
  state = "normal"

  [[appRule]]
  class = "st"
  instance = "st"
  monitor = 1
  tags = [ 3, 7, 8 ]
  state = "fooBAR"

  [[appRule]]
  class = "st"
  instance = "st"
  monitor = 1
  tags = [ 3, 7, 8 ]
  """

  let toml = parseString(testToml)
  let rules: seq[AppRule] = parseAppRules(toml.tableVal[])

  assert rules.len == 5

  let firstRule = rules[0]
  doAssert firstRule.title == "Element | Foobar"
  doAssert firstRule.class == "Element"
  doAssert firstRule.instance == "element"
  doAssert firstRule.monitorID == 2.Positive
  doAssert firstRule.tagIDs == @[ 1.TagID, 9 ]
  doAssert firstRule.state == wsFullscreen

  let secondRule = rules[1]
  doAssert secondRule.class == "st"
  doAssert secondRule.instance == "st"
  doAssert secondRule.monitorID == 1.Positive
  doAssert secondRule.tagIDs == @[ 3.TagID, 7, 8 ]
  doAssert secondRule.state == wsFloating

  let thirdRule = rules[2]
  doAssert thirdRule.class == "st"
  doAssert thirdRule.instance == "st"
  doAssert thirdRule.monitorID == 1.Positive
  doAssert thirdRule.tagIDs == @[ 3.TagID, 7, 8 ]
  doAssert thirdRule.state == wsNormal

  let fourthRule = rules[3]
  doAssert fourthRule.class == "st"
  doAssert fourthRule.instance == "st"
  doAssert fourthRule.monitorID == 1.Positive
  doAssert fourthRule.tagIDs == @[ 3.TagID, 7, 8 ]
  doAssert fourthRule.state == wsNormal

  let fifthRule = rules[4]
  doAssert fifthRule.class == "st"
  doAssert fifthRule.instance == "st"
  doAssert fifthRule.monitorID == 1.Positive
  doAssert fifthRule.tagIDs == @[ 3.TagID, 7, 8 ]
  doAssert fifthRule.state == wsNormal

test "no app rules does not raise an exception":
  let testToml: string = ""

  let toml = parseString(testToml)
  let rules: seq[AppRule] = parseAppRules(toml.tableVal[])
  assert rules.len == 0

test "has an invalid title":
  let testToml: string = """
  [[appRule]]
  title = 9009
  class = "123"
  instance = "element"
  monitor = 2
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  assertRaises(Exception, "title must be a string!"):
    discard parseAppRules(toml.tableVal[])


test "has an invalid class":
  let testToml: string = """
  [[appRule]]
  class = 123
  instance = "element"
  monitor = 2
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  assertRaises(Exception, "class must be a string!"):
    discard parseAppRules(toml.tableVal[])

test "has an invalid instance":
  let testToml: string = """
  [[appRule]]
  class = "Element"
  instance = 142
  monitor = 2
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  assertRaises(Exception, "instance must be a string!"):
    discard parseAppRules(toml.tableVal[])

test "has an invalid monitor":
  let testToml: string = """
  [[appRule]]
  class = "Element"
  instance = "element"
  monitor = "2"
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  assertRaises(Exception, "monitor must be an integer!"):
    discard parseAppRules(toml.tableVal[])

test "has an invalid tags array":
  let testToml: string = """
  [[appRule]]
  class = "Element"
  instance = "element"
  monitor = 2
  tags = 1
  """

  let toml = parseString(testToml)
  assertRaises(Exception, "tags must be an array!"):
    discard parseAppRules(toml.tableVal[])

test "globMatches":
  assert globMatches("", "") == true
  assert globMatches("foo", "") == true
  assert globMatches("", "foo") == false

  assert globMatches("foobar", "foo*") == true
  assert globMatches("foobar", "*bar") == true
  assert globMatches("foobar", "*oo*") == true
  assert globMatches("foobar", "bar*") == false

  assert globMatches("foobar", "Foobar") == false
  assert globMatches("Foobar", "foobar") == false
  assert globMatches("Foobar", "Foobar") == true

