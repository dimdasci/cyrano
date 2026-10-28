# Качество кода

Статус: **принято** 2026-10-27.

Цель: после каждой итерации разработки можно одной командой убедиться, что код читаемый и поддерживаемый, а хаос не растёт. Идея взята у Боба Мартина ([ub-mode](https://github.com/unclebob/ub-mode), [crapper](https://github.com/unclebob/crapper), [dryer](https://github.com/unclebob/dryer), [mutator](https://github.com/unclebob/mutator)): агент пишет код, детерминированные инструменты проверяют его по жёстким порогам. Его инструменты Swift не поддерживают, поэтому используем аналоги для Swift.

## Запуск

```bash
scripts/check          # всё сразу; печатает все провалы, exit 1 если есть хоть один
scripts/check --fix    # сначала переформатировать Swift-файлы, потом проверить
```

Инструменты: `swift format` входит в Xcode, остальные ставятся один раз:

```bash
brew install swiftlint periphery
npm install -g jscpd
```

Проверяется код продукта: `App/` и `Packages/`. `evals/cloud-runner` — прототип раннера, в проверку не входит.

В CI тот же `scripts/check` запускается на каждый push в `main` и на каждый pull request: [.github/workflows/check.yml](../.github/workflows/check.yml). Раннер — `xcode-27` (preview-образ GitHub с Xcode 27, нужен для SDK macOS 27). SwiftLint и Periphery ставятся из Homebrew последних версий, jscpd закреплён на той же версии, что локально.

## Что проверяется

| Шаг | Инструмент | Конфиг | Что ловит |
|---|---|---|---|
| Форматирование | `swift format lint --strict` | [.swift-format](../.swift-format) | Стиль: 2 пробела, строка до 100 символов, порядок импортов. Исправляется `--fix` |
| Компиляция | `swift build` | [Package.swift](../Packages/CyranoCore/Package.swift) | Предупреждения — ошибки; strict concurrency (Swift 6); `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`; функции и выражения, которые тайпчекаются дольше 200 мс |
| Тесты | `swift test` | — | Поведение CyranoCore |
| Неиспользуемый код | Periphery | [.periphery.yml](../Packages/CyranoCore/.periphery.yml) | Неиспользуемые типы, функции, свойства, параметры. Публичный API CyranoCore считается используемым: это контракт с App |
| Сложность и размеры | SwiftLint | [.swiftlint.yml](../.swiftlint.yml) | Пороги ниже; плюс `!`, `try!`, `as!`, IUO |
| Дубликаты | jscpd | [.jscpd.json](../.jscpd.json) | Совпадающие фрагменты от 6 строк и 60 токенов; любой найденный клон — провал |

## Пороги

| Метрика | Порог | Комментарий |
|---|---|---|
| Цикломатическая сложность функции | ≤ 10 | `switch` по enum не считается: разбивать его ради метрики не нужно |
| Тело функции | ≤ 40 строк | |
| Тело замыкания | ≤ 30 строк | SwiftUI `body` — повод вынести подвью |
| Тело типа | ≤ 250 строк | |
| Файл | ≤ 400 строк | без строк-комментариев |
| Параметров функции | ≤ 5 | больше — повод для типа-параметра |
| Вложенность | типы ≤ 2, функции ≤ 3 | |
| Кортеж | ≤ 3 элемента | больше — `struct` |

Все пороги — ошибки, а не предупреждения. Пороги меняются только по решению владельца проекта, а не ради прохождения проверки.

Подавление правила допускается только точечно и с причиной:

```swift
// swiftlint:disable:next force_unwrapping - caller guarantees a non-empty list
let head = items.first!
```

Блочные `swiftlint:disable` без парного `enable` запрещены правилом `blanket_disable_command`.

## Приложение (App/)

- SwiftLint, jscpd и `swift format` проверяют `App/` вместе с пакетами.
- В build settings Xcode-проекта: `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, те же upcoming features, что в `Package.swift`, изоляция по умолчанию — `MainActor`.
- Подпись: по умолчанию ad-hoc ([App/Signing.xcconfig](../App/Signing.xcconfig)), чтобы проект собирался везде, включая CI. Локально `scripts/make-signing-identity` создаёт самоподписанный сертификат «Cyrano Local Signing» и `App/Signing.local.xcconfig` (не в git): разрешение Accessibility привязывается к сертификату и переживает пересборки.
- `scripts/check` собирает приложение `xcodebuild` (в `.build/xcode`) и запускает Periphery по Xcode-проекту.
- `retain_public` для CyranoCore пока оставлен: скан приложения не проверяет публичный API пакета. Снять, когда Periphery начнёт сканировать оба вместе.

## Позже

Отложено, пока кода мало:

- **CRAP** — сложность × непокрытость тестами по функциям: `swift test --enable-code-coverage` + `llvm-cov export` + сложность. Либо добавить Swift в crapper.
- **Мутационное тестирование** — по изменённым файлам перед коммитом (Muter или Swift-модуль для mutator).
- **Разбиение CyranoCore на таргеты SPM** (Auth, OpenAI, Prompts, Diff, Settings): компилятор начнёт запрещать циклы и лишние зависимости.

Предостережение из эксперимента Мартина: механическое следование метрике сложности раздуло код на 20–65% и удвоило число функций без изменения поведения. Метрика — сигнал; разбивать стоит по смыслу, а не до минимального числа.
