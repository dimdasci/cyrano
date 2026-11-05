# Cyrano

Нативное приложение для macOS, которое проверяет и улучшает короткие сообщения в любом приложении: хоткей → панель с исправленным текстом, пояснениями и диалогом с моделью → копирование результата, вставляете сами. Работает через вашу подписку ChatGPT (Plus или Pro) по официальному «Sign in with ChatGPT».

Статус: preview — основной сценарий, изображения как контекст, чтение контекста со скриншота окна, словарь «Never change» и выбор модели для каждой операции работают; что сделано, следующий пакет и отступления от спеки — в [docs/plan.md](docs/plan.md).

## Структура

```
docs/                  спецификация, wireframes, исследования (начать с docs/README.md)
Packages/CyranoCore/  Swift Package: клиент OpenAI, промпты, diff, словарь, настройки (тестируется без UI)
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

При первом запуске: Continue with ChatGPT → разрешение Accessibility → Screen Recording, если оставить включённым чтение контекста из окна → ⌥⌘G в любом текстовом поле. Тесты ядра:

```bash
cd Packages/CyranoCore && swift test
```

Проверка качества перед коммитом (инструменты и пороги — [docs/quality.md](docs/quality.md)):

```bash
brew install swiftlint periphery && npm install -g jscpd
scripts/check
```

Eval чтения контекста со скриншота — тем же кодом, что и приложение (кейсы и формат — [evals/context/README.md](evals/context/README.md)):

```bash
swift build --package-path Packages/CyranoCore --product cyrano-eval
Packages/CyranoCore/.build/debug/cyrano-eval context evals/context/cases.json
```

Eval исправлений — Fix, Explain и диалог тем же кодом, что и панель; раннер пишет отчёт, оценку ставит агент, спорное согласует с пользователем ([evals/fix/README.md](evals/fix/README.md)):

```bash
Packages/CyranoCore/.build/debug/cyrano-eval fix evals/fix/cases.json gpt-6.1-sol > evals/private/fix-runs/gpt-6.1-sol.md
```

## Релизы

```bash
scripts/release 0.2.0    # на main: PR с версией и release notes, после слияния CI ставит тег и публикует релиз
```

Что изменилось в каждой версии — [CHANGELOG.md](CHANGELOG.md). Версии, changelog, порядок выпуска и распространение — [docs/releases.md](docs/releases.md).

## Лицензия

MIT © 2026 Dim Kharitonov. См. [LICENSE](LICENSE).
