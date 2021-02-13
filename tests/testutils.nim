template test*(description: string, test: untyped) =
  block:
    test

template assertRaises*(exception: typedesc, errorMessage: string, code: untyped) =
  ## Raises ``AssertionDefect`` if specified ``code`` does not raise the
  ## specified exception. Example:
  ##
  ## .. code-block:: nim
  ##  doAssertRaisesSpecific(ValueError, "wrong value!"):
  ##    raise newException(ValueError, "Hello World")
  var wrong = false
  when Exception is exception:
    try:
      if true:
        code
      wrong = true
    except Exception as e:
      if e.msg != errorMessage:
        raiseAssert("Wrong exception was raised: " & e.msg)
      discard
  else:
    try:
      if true:
        code
      wrong = true
    except exception:
      discard
    except Exception:
      raiseAssert(astToStr(exception) &
                  " wasn't raised, another error was raised instead by:\n"&
                  astToStr(code))
  if wrong:
    raiseAssert(astToStr(exception) & " wasn't raised by:\n" & astToStr(code))

