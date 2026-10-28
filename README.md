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
- **Номер сборки** (`CFBundleVersion`) — число коммитов на `HEAD`. Его пишет в собранное приложение шаг сборки `scripts/set-build-number`, руками не меняется. Одна и та же версия у разных коммитов различается номером, а по номеру можно найти коммит: `git rev-list --reverse HEAD | sed -n <номер>p`. CI скачивает полную историю (`fetch-depth: 0` в `.github/workflows/check.yml`), иначе номер был бы 1. В pull request CI собирает merge-коммит ветки с `main`, поэтому там номер на единицу больше, чем у последнего коммита ветки.

Релиз делается с `main`, тем же скриптом дважды: в `main` изменения попадают только через PR, а тег ставится на `main`.

```bash
scripts/release 0.2.0
```

1. Первый запуск прогоняет `scripts/check`, коммитит версию в ветку `release/0.2.0` и открывает PR в `main`.
2. После слияния PR: `git pull`, затем снова `scripts/release 0.2.0`. В `main` уже версия 0.2.0, поэтому скрипт ставит тег `v0.2.0` и пушит его.

Скрипт работает только на чистом `main`, синхронизированном с `origin/main`.

## Лицензия

MIT © 2026 Dim Kharitonov. См. [LICENSE](LICENSE).
