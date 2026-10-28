# Cyrano

Нативное приложение для macOS, которое проверяет и улучшает короткие сообщения в любом приложении: хоткей → панель с исправленным текстом, пояснениями и диалогом с моделью → копирование результата, вставляете сами. Работает через вашу подписку ChatGPT (Plus или Pro) по официальному «Sign in with ChatGPT».

Статус: preview 0.1 — основной сценарий работает, план и отступления от спеки — в [docs/plan.md](docs/plan.md).

## Структура

```
docs/                  спецификация, wireframes, исследования (начать с docs/README.md)
Packages/CyranoCore/  Swift Package: клиент OpenAI, промпты, diff, настройки (тестируется без UI)
App/                   Xcode-проект приложения: UI, AX, хоткеи, окна
evals/                 набор примеров и раннер для проверки промптов на моделях ChatGPT
scripts/check          проверка качества кода: формат, сборка, тесты, линтер, дубликаты, мёртвый код
```

## Требования

- macOS 27+, Apple Silicon, Xcode 27+
- Подписка ChatGPT Plus или Pro

## Сборка

```bash
open App/Cyrano.xcodeproj    # схема Cyrano, Run
```

Или из терминала:

```bash
xcodebuild -project App/Cyrano.xcodeproj -scheme Cyrano -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/Cyrano.app
```

Один раз перед первой сборкой создайте локальный сертификат подписи, иначе разрешение Accessibility будет сбрасываться при каждой пересборке:

```bash
scripts/make-signing-identity
```

При первом запуске: Continue with ChatGPT → разрешение Accessibility → ⌥⌘G в любом текстовом поле. Тесты ядра:

```bash
cd Packages/CyranoCore && swift test
```

Проверка качества перед коммитом (инструменты и пороги — [docs/quality.md](docs/quality.md)):

```bash
brew install swiftlint periphery && npm install -g jscpd
scripts/check
```

Раннер примеров:

```bash
cd evals/cloud-runner && swiftc -parse-as-library -O OpenAI.swift Shared.swift main.swift -o /tmp/openai-runner
/tmp/openai-runner login
MODEL=gpt-6.1-sol EFFORT=low /tmp/openai-runner run ../cases.json
```

## Версии

В About видно «Version 0.1.0 (6)»: версия и номер сборки.

- **Версия** (`CFBundleShortVersionString`) — semver `major.minor.patch`, хранится в одном месте: [App/Version.xcconfig](App/Version.xcconfig). Пока идут preview, растёт `minor` (0.2.0, 0.3.0), исправления внутри preview — `patch` (0.2.1); 1.0.0 — первый релиз, который считаем готовым.
- **Номер сборки** (`CFBundleVersion`) — число коммитов на `HEAD`. Его пишет в собранное приложение шаг сборки `scripts/set-build-number`, руками не меняется. Одна и та же версия у разных коммитов различается номером, а по номеру можно найти коммит: `git rev-list --reverse HEAD | sed -n <номер>p`. Для CI нужна полная история (`fetch-depth: 0`), иначе номер будет 1.

Релиз — из чистого рабочего дерева:

```bash
scripts/release 0.2.0
```

Скрипт прогоняет `scripts/check`, записывает версию, коммитит «Release 0.2.0» и ставит тег `v0.2.0`. Пушит не он — команду он напечатает в конце.

## Лицензия

MIT © 2026 Dim Kharitonov. См. [LICENSE](LICENSE).
