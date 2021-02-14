import
  parsetoml,
  strutils

import ../taginfo

const tableName = "appRule"
const globChar = '*'

type AppRule* = ref object
  title*: string
  class*: string
  instance*: string
  monitorID*: Positive
  tagIDs*: seq[TagID]

proc newAppRule*(): AppRule =
  AppRule(
    title: "",
    class: "",
    instance: "",
    monitorID: 1,
    tagIDs: @[]
  )

proc getStringProperty(appRuleTable: TomlTableRef, property: string): string =
  ## Returns the string property if it exists.
  if appRuleTable.hasKey(property):
    let prop = appRuleTable[property]
    if prop.kind != TomlValueKind.String:
      raise newException(Exception, property & " must be a string!")
    return prop.stringVal

proc getMonitorID(appRuleTable: TomlTableRef): Positive =
  result = 1
  const propertyName = "monitor"
  if not appRuleTable.hasKey(propertyName):
    raise newException(Exception, propertyName & " must be provided!")

  let monitorIDToml = appRuleTable[propertyName]
  if monitorIDToml.kind != TomlValueKind.Int:
    raise newException(Exception, propertyName & " must be an integer!")

  let monitorID = monitorIDToml.intVal
  if monitorID < 1:
    raise newException(Exception, propertyName & " must be a positive integer!")

  return monitorID

proc getTagIDs(appRuleTable: TomlTableRef): seq[TagID] =
  const propertyName = "tags"
  if not appRuleTable.hasKey(propertyName):
    raise newException(Exception, propertyName & " must be provided!")

  let tagIDsToml = appRuleTable[propertyName]
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

    if tagID > tagCount:
      raise newException(Exception, propertyName & " cannot be greater than " & $tagCount & "!")

    result.add(tagID)

proc parseAppRules*(table: TomlTable): seq[AppRule] =
  ## Parses the table, looking for an array of "appRule" tables.
  if not table.hasKey(tableName):
    return result

  let appRuleTables = table[tableName]
  if appRuleTables.kind != TomlValueKind.Array:
    raise newException(Exception, "appRule must be an array of tables!")

  for appRuleTableToml in appRuleTables.arrayVal:
    if appRuleTableToml.kind != TomlValueKind.Table:
      raise newException(Exception, "appRule must be a table!")

    let appRuleTable = appRuleTableToml.tableVal
    let appRule = newAppRule()
    appRule.title = appRuleTable.getStringProperty("title")
    appRule.class = appRuleTable.getStringProperty("class")
    appRule.instance= appRuleTable.getStringProperty("instance")
    appRule.monitorID = appRuleTable.getMonitorID()
    appRule.tagIDs = appRuleTable.getTagIDs()
    result.add(appRule)

proc globMatches*(str, sub: string): bool =
  if sub.len == 0 or str == sub:
    return true

  if sub.startsWith(globChar):
    var substring = sub
    substring.removePrefix(globChar)

    if sub.endsWith(globChar):
      # sub is "*bar*" type of search
      substring.removeSuffix(globChar)
      return str.contains(substring)

    # sub is "*bar" type of search
    return str.endsWith(substring)

  elif sub.endsWith(globChar):
    var substring = sub
    substring.removeSuffix(globChar)

    if sub.startsWith(globChar):
      # sub is "*foo*" type of search
      substring.removePrefix(globChar)
      return str.contains(substring)

    # sub is "foo*" type of search
    return str.startsWith(substring)

  return false

proc matches*(this: AppRule, title, instance, class: string): bool =
  return
    globMatches(instance, this.instance) and
    globMatches(class, this.class) and
    globMatches(title, this.title)

