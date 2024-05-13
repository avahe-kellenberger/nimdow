import parsetoml

type
  LayoutSettings* = ref object of RootObj

method parseLayoutCommand*(this: LayoutSettings, command: string): string {.base.} =
  echo "parseLayoutCommand not implemented for base class"

method populateLayoutSettings*(this: var LayoutSettings, config: TomlTableRef) {.base.} =
  echo "populateLayoutSettings not implemented for base class"
