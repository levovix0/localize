import tables, os, macros, json, strformat, sets, strutils, sequtils
import fusion/astdsl

type
  Locale* = tuple
    lang: string
    variant: string
  
  LocaleTable* = Table[string, Table[string, Table[string, Table[string, string]]]]
    ## dynamically loaded translations are stored in this table
    ## key order is:
    ##   nimble module -> file -> text -> context -> translation
  
  LangVar* = tuple
    locale: Locale
    table: LocaleTable

var
  globalLocale*: LangVar

  toTranslate {.compileTime.}: HashSet[tuple[text, context, file, module: string]]
  compileTimeTranslations {.compileTime.}: Table[string, Table[Locale, tuple[files: Table[string, Table[string, Table[string, string]]], trFile: string]]]
    ## key order is:
    ##   nimble module -> locale -> file -> text -> context -> translation
  translationsAccepted {.compileTime.} = false


proc locale*(lang="", variant="", localeTable: LocaleTable = LocaleTable.default): LangVar =
  ((lang, variant), localeTable)


proc hasTranslation(t: LocaleTable; text: static string; context, file, module: string): bool =
  t.hasKey(module) and t[module].hasKey(file) and t[module][file].hasKey(text) and t[module][file][text].hasKey(context)

proc getTranslation(t: LocaleTable; text: static string; context, file, module: string): string =
  ## todo: formating
  t[module][file][text][context]


proc findNimbleModule(startPath: string): tuple[name, translationsPath, fileRoot: string] =
  ## searches for *.nimble in startPath and dirs those are upper
  ## returns name of the module and path where translations is stored
  ## also, if dir contains `*.localize-translations` file, result name will be name of this file and path to translations dir same as path to file dir
  ## if no dir was found, module name will be "", and path to translations will be translations dir in startPath
  var path = startPath
  while not path.isRootDir:
    defer: path = path.splitPath.head
    for k, file in path.walkDir:
      if k notin {pcFile, pcLinkToFile}:
        continue
      
      let (_, name, ext) = file.splitFile
      
      if ext == ".localize-translations":
        return (name, path, path)
      if ext == ".nimble":
        return (name, path & "/" & "translations", path)  # todo: use compilation-time os specific separator

  return ("", startPath & "/" & "translations", startPath)


proc loadCompileTimeLocale(module, file: string, locale: Locale) {.compileTime.} =
  compileTimeTranslations[module][locale] = (Table[string, Table[string, Table[string, string]]].default, file)
  try:
    for file, text in file.staticRead.parseJson:
      try:
        compileTimeTranslations[module][locale].files[file] = Table[string, Table[string, string]].default
        for text, context in text:
          try:
            compileTimeTranslations[module][locale].files[file][text] = Table[string, string].default
            for context, translation in context:
              try:
                compileTimeTranslations[module][locale].files[file][text][context] = translation.to(string)
              except KeyError: discard
          except KeyError: discard
      except KeyError: discard
  except CatchableError: discard

proc loadCompileTimeLocales(module, translationsDir: string) {.compileTime.} =
  compileTimeTranslations[module] = Table[Locale, tuple[files: Table[string, Table[string, Table[string, string]]], trFile: string]].default
  for k, file in translationsDir.walkDir:
    if k notin {pcFile, pcLinkToFile}:
      continue
    
    let (_, name, ext) = file.splitFile
    if ext != ".json":
      continue
    
    let l = name.split("_")
    if l.len == 1:
      loadCompileTimeLocale(module, file, (name, ""))
    elif l.len >= 2:
      loadCompileTimeLocale(module, file, (l[0], l[1]))


proc trImpl2(text, context, file, module, translationsDir: string, langVar: NimNode): NimNode =
  if translationsAccepted: error("translations was accepted, put `updateTranslations()` under `tr` call, make sure you use updateTranslations in `when isMainModule` block")

  toTranslate.incl (text, context, file, module)
  
  if module notin compileTimeTranslations:
    loadCompileTimeLocales(module, translationsDir)

  result = buildAst(ifStmt):
    template checkHasKey: bool {.dirty.} =
      (compileTimeTranslations[module][locale].files.hasKey file) and
      (compileTimeTranslations[module][locale].files[file].hasKey text) and
      (compileTimeTranslations[module][locale].files[file][text].hasKey context)
    
    elifBranch:
      call bindSym"hasTranslation":
        bracketExpr(langVar, 1.newLit)
        newLit text
        newLit context
        newLit file
        newLit module
      call bindSym"getTranslation":
        bracketExpr(langVar, 1.newLit)
        newLit text
        newLit context
        newLit file
        newLit module

    for locale in compileTimeTranslations[module].keys:
      if locale.variant == "": continue
      if checkHasKey:
        elifBranch:
          call bindSym"==":
            bracketExpr(langVar, 0.newLit)
            tupleConstr(locale.lang.newLit, locale.variant.newLit)
          call bindSym"fmt":
            newLit: compileTimeTranslations[module][locale].files[file][text][context]

    for locale in compileTimeTranslations[module].keys:
      if locale.variant != "": continue
      if checkHasKey:
        elifBranch:
          call bindSym"==":
            bracketExpr(bracketExpr(langVar, 0.newLit), 0.newLit)
            locale.lang.newLit
          call bindSym"fmt":
            newLit: compileTimeTranslations[module][locale].files[file][text][context]

    Else:
      call bindSym"fmt":
        text.newLit
  
  if result.len == 1:
    result = result[0][0]


macro trImpl(text, context, file: static string, langVar: LangVar): string =
  let (name, translationsDir, fileRoot) = findNimbleModule(file.splitPath.head)
  trImpl2(text, context, file.relativePath(fileRoot, '/'), name, translationsDir, langVar)


template tr*(text: static string, context: static string = "", langVar: LangVar = globalLocale): string =
  bind trImpl
  let langv {.cursor.} = langVar
  trImpl(text, context, instantiationInfo(index=0, fullPaths=true).filename, langv)


template tr*(langVar: LangVar, text: static string, context: static string = ""): string =
  bind trImpl
  let langv {.cursor.} = langVar
  trImpl(text, context, instantiationInfo(index=0, fullPaths=true).filename, langv)


macro requireLocalesToBeTranslatedImpl(locales: static seq[Locale], file: static string) =
  let (_, translationsDir, _) = findNimbleModule(file.splitPath.head)
  if not translationsDir.dirExists:
    var tdQuoted = ""
    tdQuoted.addQuoted translationsDir
    when defined(mingw):
      discard staticExec("mkdir " & tdQuoted)
    when defined(windows):
      discard staticExec("md " & tdQuoted)
    elif defined(linux):
      discard staticExec("mkdir " & tdQuoted)
    else:
      error("please, create " & tdQuoted & " directory manually")

  for x in locales:
    if x.variant == "":
      if not fileExists(translationsDir & "/" & (x.lang & ".json")):
        writeFile translationsDir & "/" & (x.lang & ".json"), ""
    
    else:
      if not fileExists(translationsDir & "/" & (x.lang & "_" & x.variant & ".json")):
        writeFile translationsDir & "/" & (x.lang & "_" & x.variant & ".json"), ""

template requireLocalesToBeTranslated*(locales: varargs[Locale]) =
  bind requireLocalesToBeTranslatedImpl
  bind toSeq
  requireLocalesToBeTranslatedImpl(toSeq(locales), instantiationInfo(index=0, fullPaths=true).filename)


proc parseLocaleTable*(json: JsonNode): LocaleTable =
  result = LocaleTable.default
  for module, file in json:
    result[module] = Table[string, Table[string, Table[string, string]]].default
    for file, text in file:
      result[module][file] = Table[string, Table[string, string]].default
      for text, context in text:
        result[module][file][text] = Table[string, string].default
        for context, translation in context:
          result[module][file][text][context] = translation.to(string)


macro updateTranslations* =
  translationsAccepted = true

  for module, locales in compileTimeTranslations:
    for locale, (files, trFile) in locales:
      var t: Table[string, Table[string, Table[string, string]]]

      for (text, context, file, module2) in toTranslate:
        if module2 != module: continue

        if not(t.hasKey file):
          t[file] = Table[string, Table[string, string]].default
        if not(t[file].hasKey text):
          t[file][text] = Table[string, string].default
        if not(t[file][text].hasKey context):
          t[file][text][context] = text

        if 
          (compileTimeTranslations[module][locale].files.hasKey file) and
          (compileTimeTranslations[module][locale].files[file].hasKey text) and
          (compileTimeTranslations[module][locale].files[file][text].hasKey context)
        :
          t[file][text][context] = compileTimeTranslations[module][locale].files[file][text][context]
        else:
          t[file][text][context] = text

      writeFile trFile, (%*t).pretty


when defined(windows):
  const
    Chinese = 4
    German = 7
    English = 9
    Spanish = 10
    Japanese = 11
    French = 12
    Italian = 16
    Polish = 21
    Russian = 25
  
  # TODO: seems like this method is deprecated
  proc GetUserDefaultLangID(): int {.importc, dynlib: "Kernel32.dll".}

  proc systemLocale*: Locale =
    let lang = GetUserDefaultLangID() and 0x00FF
    case lang
    of Chinese: ("zh", "")
    of German: ("de", "")
    of English: ("en", "")
    of Spanish: ("es", "")
    of Japanese: ("ja", "")
    of French: ("fr", "")
    of Italian: ("it", "")
    of Polish: ("pl", "")
    of Russian: ("ru", "")
    else: ("en", "")

else:
  proc systemLocale*: Locale =
    ## returns system locale
    ## parses "en_US.UTF-8" as ("en", "us")
    var lang = getEnv("LANG", "en_US.UTF-8")
    if lang.endsWith(".UTF-8"):
      lang = lang[0..^7]
    let l = lang.split("_")
    (l[0].toLower, l[1..^1].join("_").toLower)
