---
name: verify-app
description: Проверить изменение в запущенном Cyrano руками агента — перезапустить свежую сборку, открыть панель на тексте из TextEdit, нажимать кнопки и пункты меню, читать карточки и Settings через Accessibility. Использовать перед тем, как сказать, что изменение в App готово, и когда пользователь просит проверить в приложении. Здесь же — что делать, если macOS отозвала разрешения Accessibility или Screen Recording.
---

# Проверка в запущенном Cyrano

Агент управляет приложением через Accessibility: утилита `.build/ax` (исходник [ax.swift](ax.swift)) читает дерево элементов, нажимает кнопки, открывает контекстные меню и выбирает пункты; [capture.sh](capture.sh) открывает панель на тексте из TextEdit. Текст карточек читается как текст, без распознавания скриншотов.

## Правила безопасности

Пользователь в это время может работать за компьютером, а клавиатура и мышь общие.

- Перед началом скажи пользователю, что ближайшие минуты будешь нажимать клавиши и двигать мышь, и попроси не переключать окна.
- Клавиши (`osascript … keystroke`) уходят в окно, которое впереди. Отправляй их, только убедившись, что впереди нужное приложение: `capture.sh` проверяет TextEdit; для Cyrano — `osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'` должно вернуть `Cyrano`. Если впереди другое — не нажимай, скажи об этом.
- Check нажимай, только если первая строка `.build/ax windows` — `Proofreading — TextEdit`. Иначе панель могла забрать текст из окна пользователя: не читай её и не отправляй на проверку.
- Словарь и настройки — настоящие данные пользователя. Перед проверкой сохрани копию `~/Library/Application Support/Cyrano/dictionary.json` (или запомни, что файла нет), после — закрой Cyrano и верни как было. Пока Cyrano запущен, он держит словарь в памяти и запишет его обратно при следующем изменении.
- Системные настройки (разрешения) меняет только пользователь.

## Подготовка

```bash
xcodebuild -project App/Cyrano.xcodeproj -scheme Cyrano -configuration Debug -derivedDataPath .build/xcode -quiet build
swiftc -O .claude/skills/verify-app/ax.swift -o .build/ax
pkill -x Cyrano; sleep 1; open .build/xcode/Build/Products/Debug/Cyrano.app; sleep 3
.build/ax windows    # без ошибки — Accessibility есть
```

Если `.build/ax` пишет `Accessibility is not granted to this process` или `osascript` — `not allowed assistive access`, см. «Разрешения» ниже.

## Команды `ax`

| Команда | Что делает |
|---|---|
| `ax windows` | заголовки окон Cyrano, переднее первым |
| `ax tree [окно]` | дерево: `роль \| подпись \| значение \| подсказка`; окно — подстрока заголовка (`Dictionary`) |
| `ax wait <текст> [сек]` | ждёт, пока текст появится в подписи или значении (по умолчанию 30 с) |
| `ax press <подпись>` | нажимает кнопку или ссылку (`Check`, `Send`, `Copy`, `Undo`, `▸ 1 fix`, `Add Term`) |
| `ax select <текст>` | выделяет текст в тексте карточки |
| `ax menu <текст>` | открывает меню выделения (`AXShowMenu`) и печатает пункты |
| `ax rightclick <текст>` | настоящий правый клик по элементу с этим текстом в подписи или значении; печатает пункты |
| `ax pick <пункт>` | выбирает пункт открытого контекстного меню |
| `ax appmenu <пункт>` | пункт меню приложения или иконки в строке меню (`Settings…`, `Check Text…`) |
| `ax set <плейсхолдер/подпись> <значение>` | вводит значение в поле (`Search`, `Term`) |
| `ax rows` | строки таблиц |
| `ax selectrow <значение>` | выбирает строку таблицы |
| `ax doubleclick <значение>` | двойной клик по элементу с этим значением |

Вывод `ax tree` сохраняй в файл и ищи в нём: при `ax tree | head` утилита может умереть от SIGPIPE и ничего не напечатать.

## Сценарий

1. Открыть панель: `.claude/skills/verify-app/capture.sh "I pushed the fix to Github, can you review it when you have a minute?"`. Подожди 10–12 с: Cyrano читает контекст со скриншота, Check до этого неактивна.
2. `.build/ax press Check`, `.build/ax wait "Version 1" 60`, затем `.build/ax tree > …` — текст карточки в строке `AXTextArea`: удалённое и добавленное идут подряд (`Github, can GitHub. Can`). Пояснения приходят ещё через 5–15 с: сводка меняется с `Explaining…` на `1 fix`.
3. Проверяй то, что видит пользователь: подписи, сводку, строку статуса (`AXStaticText` внизу), файлы, которые пишет приложение.

Примеры, которые `gpt-6.1-sol` стабильно исправляет (удобно для словаря): `Github → GitHub`, `kibana → Kibana`, `grafana → Grafana`. Модель в контексте сообщения может не тронуть сленг (`tmrw`, `pls`), так что на них не полагайся.

Settings: `.build/ax appmenu "Settings…"`, вкладка — `.build/ax press Dictionary`, дальше `ax tree Dictionary`, `ax rows`.

## Особенности

- Подписи кнопок SwiftUI лежат в `AXAttributedDescription`; System Events (AppleScript, JXA) их не читает, поэтому `ax` написан на `AXUIElement`.
- `AXShowMenu` работает для текста карточки (`NSTextView`), но не для SwiftUI `.contextMenu` (ошибка -25204) — там `ax rightclick`. Правый клик попадает в центр элемента; если меню не открылось, проверь, что у строки есть `.contentShape`, иначе пустое место не ловит клик.
- Кнопка, которая открывает модальное окно (Import…, Export…), не возвращается из `AXPress`, пока окно открыто: запускай `ax press` в фоне (`… &`). Окну сохранения нужен ввод пути с клавиатуры (⇧⌘G) — только когда впереди Cyrano; иначе закрой его `ax press Cancel`.
- После проверки закрой лишние панели и TextEdit: `osascript -e 'tell application "TextEdit" to close every document saving no'`.

## Разрешения

Нужны **Accessibility** (клавиши, клики, чтение дерева) и **Screen Recording** (скриншоты для вёрстки, `screencapture`). Их выдают не `osascript` и не `ax`, а процессу Claude Code, который запускает оболочку:

```
Claude.app → disclaimer → ~/Library/Application Support/Claude/claude-code/<версия>/<хеш>/claude.app → zsh
```

Найти точный путь: пройти `ps -o ppid=,comm= -p <pid>` вверх от `$$`.

Признаки, что разрешения нет: `ax` — `Accessibility is not granted to this process`; `osascript` — `not allowed assistive access (-1719)`; `screencapture -x file.png` — `could not create image from display`. После обновления Claude Code путь меняется, и macOS может попросить разрешения снова.

Как восстановить:

1. Скажи пользователю, какого разрешения нет и зачем оно. Сам в System Settings ничего не включай.
2. Вызови системный запрос: `swift .claude/skills/verify-app/permissions.swift`. Открой нужную панель: `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"` (или `?Privacy_ScreenCapture`).
3. Попроси пользователя включить строку **claude** (иконка Claude Code, не Claude.app). Если её нет — **+**, ⇧⌘G, путь к `claude.app` из шага выше.
4. Accessibility начинает действовать сразу. Screen Recording — только после перезапуска Claude Code (на «Quit & Reopen» лучше ответить Later и перезапустить потом, иначе прервётся сессия); до этого проверяй через `ax`, без скриншотов.
5. Проверь: `swift .claude/skills/verify-app/permissions.swift` печатает `true` для нужного разрешения.

Права широкие: с Accessibility команды сессии управляют любым приложением, со Screen Recording видят весь экран. Пользователь может выключить их после проверки.

## Отчёт

Скажи, что проверено в приложении и чем (`ax`, скриншот), что не удалось проверить и почему, и вернул ли словарь и настройки как было.
