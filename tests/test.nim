import unittest
import localize

type Language {.pure.} = enum
  en
  ru

var lang: Language

localizeInit Language, bindSym"lang"

test "hello, world":
  check tr"Hello, world" == "Hello, world"
  lang = Language.ru
  check tr"Hello, world" == "Привет, мир"

test "context":
  lang = Language.ru
  check:
    tr"it is working!" == "оно работает!"
    tr("it is working!", "") == "оно работает!"
    tr("it is working!", "code") == "он работает!"

updateTranslations()
