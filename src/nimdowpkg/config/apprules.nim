import parsetoml

const tableName = "appRule"

type AppRule = ref object
  title*: string
  class*: string
  instance*: string
  monitorID*: Positive
  tagIDs*: seq[Positive]

proc newAppRule*(): AppRule =
  AppRule(
    title: "",
    class: "",
    instance: "",
    monitorID: 1,
    tagIDs: @[]
  )

proc getStringProperty(appRuleTable: TomlTable, property: string): string =
  ## Returns the string property if it exists.
  let prop = appRuleTable{property}
  if prop != nil:
    if prop.kind != TomlValueKind.String:
      raise newException(Exception, property & " must be a string!")
    return prop

proc getMonitorID(appRuleTable: TomlTable): Positive =
  const propertyName = "monitorID"
  let monitorIDToml = appRuleTable{propertyName}

  if monitorIDToml == nil:
    raise newException(Exception, propertyName & " must be provided!")

  if monitorIDToml.kind != TomlValueKind.Int:
    raise newException(Exception, propertyName & " must be a integer!")

  let monitorID = monitorIDToml.intVal
  if monitorID < 1:
    raise newException(Exception, propertyName & " must be a positive integer!")

  return monitorID

proc getTagIDs(appRuleTable: TomlTable): seq[Positive] =
  const propertyName = "tagIDs"
  let tagIDsToml = appRuleTable{propertyName}
  if tagIDsToml == nil:
    raise newException(Exception, propertyName & " must be provided!")
  if tagIDsToml.kind != TomlValueKind.Array:
    raise newException(Exception, propertyName & " must be an array!")

  if tagIDsToml.arrayVal.len < 1:
    raise newException(Exception, propertyName & " must contain at least one tag ID!")

  for tagIDToml in tagIDsToml.arrayVal:
    if tagIDToml.kind != TomlValueKind.Int:
      raise newException(Exception, propertyName & " must be an array of integers!")

    let tagID = tagIDToml.intVal
    if tagID < 1:
      raise newException(Exception, propertyName & " must be an array of positive integers!")

    result.add(tagID)

proc parseTable*(table: TomlTableRef): seq[AppRule] =
  ## Parses the table, looking for an array of "appRule" tables.
  let appRuleTables = table{tableName}
  if appRuleTables == nil:
    return result

  if appRuleTables.kind != TomlValueKind.Array:
    raise newException(Exception, "appRule must be an array of tables!")

  for appRuleTable in appRuleTables.arrayVal:
    if appRuleTable.kind != TomlValueKind.Table:
      raise newException(Exception, "appRule must be a table!")

    let appRule = newAppRule()
    appRule.title = appRuleTable.getStringProperty("title")
    appRule.class = appRuleTable.getStringProperty("class")
    appRule.instance= appRuleTable.getStringProperty("instance")
    appRule.monitorID = appRuleTable.getMonitorID()
    appRule.tagIDs = appRuleTable.getTagIDs()
    result.add(appRule)

