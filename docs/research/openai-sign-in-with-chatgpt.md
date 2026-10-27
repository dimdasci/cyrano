# Исследование: подписка ChatGPT через «Sign in with ChatGPT»

Дата: 2026-10-27. Источник — официальная документация [developers.openai.com/siwc](https://developers.openai.com/siwc/quickstart), остальное из вторичных обзоров.

## Что это

На DevDay 29.09.2026 OpenAI запустила «Sign in with ChatGPT». Приложение получает OAuth-токен и тратит лимиты подписки пользователя, а не API-ключ.

- **Кто может:** open-source и **локально запущенные** приложения — self-serve, без заявки, без client secret и partner API key. Платные или хостящиеся удалённо приложения подают [interest form](https://openai.com/form/sign-in-with-chatgpt-interest/). Наше личное приложение на своём Mac подпадает под первый вариант.
- **План пользователя:** Plus или Pro.
- **Контроль:** пользователь задаёт недельный лимит для приложения. По исчерпании запросы прекращаются, ничего не списывается.
- **Данные:** приложению доступны только имя, email и аватар. Доступа к перепискам и памяти ChatGPT нет.

## Протокол (локальное приложение)

1. Сохранить стабильный `ext_agent_host_id`, например `urn:uuid:…`, без данных пользователя.
2. Поднять loopback-слушатель `http://127.0.0.1:<port>/auth/callback`.
3. Открыть в системном браузере `https://auth.openai.com/api/accounts/authorize` с параметрами:
   - `client_id=dynamic_agent_client` (при первом входе), `agent_name_hint=<имя приложения>`, `ext_agent_host_id`;
   - `response_type=code`, `redirect_uri`, `resource=https://api.openai.com/v1`;
   - `scope=openid profile email offline_access resource.invoke chatgpt.tokens.use.direct`;
   - `state`, `nonce`, `code_challenge` (S256).
4. Колбэк: проверить `state`. Сохранить выданный `client_id` (`oaiapp_…`) и использовать его при следующих входах.
5. `POST https://auth.openai.com/api/accounts/oauth/token` (authorization_code + `code_verifier`).
6. Проверить ID token (JWKS, `iss`, `aud`, `exp`, `nonce`) и что в scope есть `chatgpt.tokens.use.direct`.
7. Хранить токены атомарно (у нас — Keychain). Refresh token ротируется: при обновлении заменять его вместе с access token.

## Вызов модели

- `POST https://api.openai.com/v1/responses`, `Authorization: Bearer <access token>`.
- Обязательно `store: false` и `stream: true` (SSE). Успех — только после `response.completed`.
- Список моделей: `GET /v1/models` с тем же токеном, брать `visibility: "list"`. В примерах документации — `gpt-6.1-sol`.
- **Не поддерживается:** `previous_response_id` (историю диалога шлём целиком в `input`), `system` items (вместо них `instructions`), `temperature`, `max_output_tokens`, `metadata` и др., а также встроенные инструменты (file search, code interpreter, image generation).
- Картинки на вход — в зависимости от модели. Structured outputs в ограничениях не указаны, это надо проверить.
- Ошибки лимитов приходят посреди стрима: `subscription_sharing_usage_limit_exceeded`, `subscription_sharing_usage_unavailable`.

## Неофициальный путь (не используем)

До DevDay сторонние инструменты переиспользовали токены `codex login` и эндпоинты `chatgpt.com/backend-api`. Это серая зона по условиям OpenAI, и такие решения регулярно ломаются. Документация прямо требует не использовать `backend-api`.

## Оценка для нас

| Работа | Оценка |
|---|---|
| OAuth PKCE + loopback (Network.framework) + Keychain + refresh | ~1 день |
| Клиент Responses API со SSE, разбор событий и ошибок лимитов | ~0.5 дня |
| `CloudEngine` за общим интерфейсом движка, перенос промптов | ~0.5 дня |
| Прогон eval на облачной модели | несколько часов |

Итого 2–3 дня до рабочего прототипа. Альтернатива — API-ключ с оплатой за токены: интеграция за пару часов, но это отдельный счёт помимо подписки.

## Последствия для архитектуры

- Текст сообщений и контекст уходят в OpenAI (`store: false`, но обработка на их серверах). Это осознанный отказ от «только локально» для облачного режима.
- Ограничения на 4096 токенов, компакцию и guided generation Apple для облачного движка не нужны. Интерфейс движка должен скрывать эти различия.
- Нужны: экран входа («Continue with ChatGPT» по гайдлайнам OpenAI), статус лимита, выход из аккаунта, запасной локальный движок при ошибке лимита или без сети.

## Источники

- [Quickstart](https://developers.openai.com/siwc/quickstart)
- [Open-source: Sign in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in.md)
- [Models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [The New Stack](https://thenewstack.io/sign-in-with-chatgpt/), [WorkOS](https://workos.com/blog/sign-in-with-chatgpt-plan-usage-scope) — обзоры запуска
