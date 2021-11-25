Simply localize your apps

src/config.nim
```nim
import localize
type Language* {.pure.} = enum
  en
  ru

var lang*: Language

initLocalize Language, bindSym"lang"
```

src/app.nim
```nim
import config

echo tr"Hello, world"  # "Hello, world"
lang = Language.ru
echo tr"Hello, world"  # "Привет, мир"

when isMainModule:
  updateTranslations()  # traslations is readed and updated when compiling
  # (current implementation needs to create `traslations` dir manualy for the first time)
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


## known issues
* recompilation without changing code is not updating translations
* translations directory needs to be created manually
