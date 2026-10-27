# Cyrano

Нативное приложение для macOS, которое проверяет и улучшает короткие сообщения в любом приложении: хоткей → панель с исправленным текстом, пояснениями и диалогом с моделью → вставка обратно в поле. Работает через вашу подписку ChatGPT (Plus или Pro) по официальному «Sign in with ChatGPT».

Статус: спецификация согласована, разработка не начата.

## Структура

```
docs/                  спецификация, wireframes, исследования (начать с docs/README.md)
Packages/CyranoCore/  Swift Package: клиент OpenAI, промпты, diff, настройки (тестируется без UI)
App/                   Xcode-проект приложения — появится на первом шаге разработки
evals/                 набор примеров и раннер для проверки промптов на моделях ChatGPT
scripts/check          проверка качества кода: формат, сборка, тесты, линтер, дубликаты, мёртвый код
```

## Требования

- macOS 27+, Apple Silicon, Xcode 27+
- Подписка ChatGPT Plus или Pro

## Сборка

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

## Лицензия

MIT © 2026 Dim Kharitonov. См. [LICENSE](LICENSE).
