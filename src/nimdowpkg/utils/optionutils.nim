import
  options

template withSome*(option: Option, value, body: untyped) =
  ## Executes the body with the value in `option`.
  if option.isSome:
    var value = option.get
    body

