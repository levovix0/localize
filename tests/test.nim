import unittest, tables, json
import localize

requireLocalesToBeTranslated ("ru", "")

test "hello, world":
  check tr"Hello, world" == "Hello, world"
  globalLocale = locale "ru"
  check tr"Hello, world" == "Привет, мир"

test "context":
  globalLocale = locale "ru"
  check:
    tr"it is working!" == "оно работает!"
    tr("it is working!", "") == "оно работает!"
    tr("it is working!", "code") == "он работает!"

test "formating":
  globalLocale = locale "ru"
  let res = 88305 * 24314 / 21
  check tr"Result is {res}" == "Результат: 102240370.0"

test "method call syntax":
  globalLocale = locale "ru"
  check "abc".tr == "абв"
  check "abc".tr("") == "абв"
  check "abc".tr("d") == "абвгд"

test "locale table":
  globalLocale = (
    ("zh", ""),
    parseLocaleTable %*{
      "localize": {
        "tests/test.nim": {
          "Hello, world": {
            "": "你好，世界",
          },
        },
      },
    }
  )
  check tr"Hello, world" == "你好，世界"
  check tr"it is working!" == "it is working!"

  let localLocale = (
    ("ru", ""),
    parseLocaleTable %*{
      "localize": {
        "tests/test.nim": {
          "Hello, world": {
            "": "Другой \"Привет, мир\".",
          },
        },
      },
    }
  )
  check localLocale.tr"Hello, world" == "Другой \"Привет, мир\"."
  check localLocale.tr"it is working!" == "оно работает!"

updateTranslations()
