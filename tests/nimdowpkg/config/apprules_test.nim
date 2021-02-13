import
  config/apprules,
  parsetoml

block validParsing:
  const testToml: string = """
  [[appRule]]
  class = "Element"
  instance = "element"
  monitor = 2
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  let rules: seq[AppRule] = parseTable(toml.tableVal)

  let firstRule = rules[0]
  doAssert firstRule.class == "Element"
  doAssert firstRule.instance == "element"
  doAssert firstRule.monitorID == 2.Positive
  doAssert firstRule.tagIDs == @[ 1.Positive, 9 ]

block hasInvalidClass:
  const testToml: string = """
  [[appRule]]
  class = 123
  instance = "element"
  monitor = 2
  tags = [ 1, 9 ]
  """

  let toml = parseString(testToml)
  assertRaises(Exception, "class must be a string!"):
    discard parseTable(toml.tableVal)


