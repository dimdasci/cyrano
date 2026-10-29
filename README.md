# Cyrano

Нативное приложение для macOS, которое проверяет и улучшает короткие сообщения в любом приложении: хоткей → панель с исправленным текстом, пояснениями и диалогом с моделью → копирование результата, вставляете сами. Работает через вашу подписку ChatGPT (Plus или Pro) по официальному «Sign in with ChatGPT».

Статус: preview — основной сценарий, изображения как контекст и чтение контекста со скриншота окна работают; что сделано, следующий пакет и отступления от спеки — в [docs/plan.md](docs/plan.md).

## Структура

```
docs/                  спецификация, wireframes, исследования (начать с docs/README.md)
Packages/CyranoCore/  Swift Package: клиент OpenAI, промпты, diff, настройки (тестируется без UI)
App/                   Xcode-проект приложения: UI, AX, хоткеи, окна
evals/                 набор примеров и раннер для проверки промптов на моделях ChatGPT
scripts/check          проверка качества кода: формат, сборка, тесты, линтер, дубликаты, мёртвый код
scripts/release        выпуск версии, см. docs/releases.md
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

## Релизы

```bash
scripts/release 0.2.0    # на main: PR с версией и release notes, после слияния CI ставит тег и публикует релиз
```

Что изменилось в каждой версии — [CHANGELOG.md](CHANGELOG.md). Версии, changelog, порядок выпуска и распространение — [docs/releases.md](docs/releases.md).

## Лицензия

MIT © 2026 Dim Kharitonov. См. [LICENSE](LICENSE).
