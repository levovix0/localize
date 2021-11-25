import unittest
import localize

type Language {.pure.} = enum
  en
  ru

var lang: Language

initLocalize Language, bindSym"lang"

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

test "formating":
  lang = Language.ru
  let res = 88305 * 24314 / 21
  check tr"Result is {res}" == "Результат: 102240370.0"

test "method call syntax":
  lang = Language.ru
  check "abc".tr == "абв"
  check "abc".tr("") == "абв"
  check "abc".tr("d") == "абвгд"

updateTranslations()
