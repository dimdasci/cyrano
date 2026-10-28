# Документация

| Документ | Содержание | Статус |
|---|---|---|
| [specs/01-options.md](specs/01-options.md) | Исходные варианты реализации и UX | исторический |
| [specs/02-tech-decisions.md](specs/02-tech-decisions.md) | Стек, авторизация, модель, захват текста, хранение, тесты | согласовано |
| [specs/03-mvp-scope.md](specs/03-mvp-scope.md) | Сценарии, настройки, критерии готовности MVP | согласовано |
| [specs/04-prompts.md](specs/04-prompts.md) | Конвейер, встроенные промпты, выбор модели, eval | согласовано |
| [specs/05-ui.md](specs/05-ui.md) | Экраны, панель-чат, состояния, клавиатура, Settings, сверка с HIG | согласовано |
| [plan.md](plan.md) | Декомпозиция MVP на пакеты работ, что вошло в preview | в работе |
| [quality.md](quality.md) | Проверки качества кода: `scripts/check`, инструменты, пороги | принято |
| [releases.md](releases.md) | Версия и номер сборки, выпуск релиза, защита `main`, распространение | принято |
| [wireframes/](wireframes/) | Wireframes всех экранов и как их использовать в разработке | согласовано |
| [research/openai-sign-in-with-chatgpt.md](research/openai-sign-in-with-chatgpt.md) | Sign in with ChatGPT: протокол, ограничения, оценка | принято |

Порядок чтения для разработки: 03 (что делаем) → 02 (как) → 05 + wireframes (как выглядит) → 04 (что отправляем модели).

Набор примеров и облачный раннер для проверки промптов — в [`/evals`](../evals/).
