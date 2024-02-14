# Localize
<img alt="sigui" width="100%" src="http://levovix.ru:8000/docs/localize/banner.png">
<p align="center">
  Localize your applications at compile-time
</p>

app.nim
```nim
import localize

requireLocalesToBeTranslated ("ru", "")

echo tr"Hello, world"  # "Hello, world"
globalLocale = locale "ru"
echo tr"Hello, world"  # "Привет, мир"

when isMainModule:
  updateTranslations()  # traslations is readed and updated when compiling
```

translations/ru.json
```json
{
  "app.nim": {
    "Hello, world": {
      "": "Привет, мир"
    }
  }
}
```
* Static translations are generated for each **nimble packege** that uses localize, in package root directory

## specifing context
```nim
"it is working!".tr          # same as "" context
"it is working!".tr("")      # "оно работает!"
"it is working!".tr("code")  # "он работает!"
```

```json
{
  "app.nim": {
    "it is working!": {
      "": "оно работает!",
      "code": "он работает!"
    }
  }
}
```

## formating
tr is auto-calling fmt 
```nim
let name = stdin.readline
echo tr"Hi, {name}"
```

```json
{
  "app.nim": {
    "Hi, {name}": {
      "": "Привет, {name}",
    }
  }
}
```

## detecting system language
```nim
globalLocale[0] = systemLocale()
```
* system locale values are based on linux's LANG env variable

## dynamic translations
```nim
import json

globalLocale = (
  ("zh", ""),
  parseLocaleTable %*{
    "mypackage": {
      "src/myapp.nim": {
        "Hello, world": {
          "": "你好，世界",
        },
      },
    },
  }
)
```
* Dynamic translations files are diffirent from static translations files: they contain table for modules  
* For now, dynamic translations are not formated

## known issues
* for now, dynamicly loaded translations cannot be formated at all
