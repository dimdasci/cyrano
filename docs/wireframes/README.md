# Wireframes

Визуальная часть спецификации UI. Текст и правила — в [05-ui.md](../specs/05-ui.md), здесь — как это выглядит и как этим пользоваться при разработке.

## Где что лежит

| Что | Где | Зачем |
|---|---|---|
| Живой канвас | [Grammar UI wireframes](https://claude.ai/artifact/WC2VDYDdgmstvtfedoeizC) (приватный) | Смотреть, кликать интерактивные артборды, оставлять заметки и комментарии |
| Исходники артбордов | `*.dc.html` в этой папке | Версионируются в git вместе со спекой; по ним видны точные размеры, тексты и состояния |
| Раскладка канваса | `canvas.json` | Положение и названия артбордов |
| Скриншоты | `png/` (пока пусто) | Быстрый просмотр без канваса, ссылки из спек и PR |

Правило синхронизации: правки делаются на канвасе, затем исходники копируются сюда, а [05-ui.md](../specs/05-ui.md) обновляется в том же коммите. Если wireframe и спека расходятся — это баг документации, исправляем оба.

## Артборды → спека → SwiftUI

| Артборд | Интерактивный | Раздел 05-ui | Будущие SwiftUI-вью |
|---|---|---|---|
| `Main.dc.html` — панель проверки | да: Context, скриншоты, раскрытие изменений, Never Change, язык, поле ввода и Send, тёмная тема (Tweaks) | §2.1–2.7, §2.9 | `ProofreadingPanel`, `PanelHeader`, `ContextBar`, `ConversationView`, `VersionCard`, `ChangeList`, `MessageBubble`, `Composer`, `StatusLine` |
| `States.dc.html` — состояния панели | нет | §2.8 | состояния `ProofreadingPanel` (checking, no changes, nothing to check, network error, plan limit, signed out, no Accessibility) |
| `Onboarding.dc.html` — первый запуск | да: шаги, вход, разрешение | §1 | `OnboardingWindow`, `SignInStep`, `AccessibilityStep`, `ShortcutStep` |
| `MenuBar.dc.html` — меню в строке меню | нет | §4 | `MenuBarExtra` content |
| `Settings.dc.html` — настройки | да: вкладки, переключатели, поиск в словаре, редактор промптов | §5 | `SettingsView` + `GeneralPane`, `StylePane`, `DictionaryPane`, `PromptsPane`, `AccountPane` |
| `About.dc.html` — окно About | нет | Карта экранов | стандартная About-панель (`orderFrontStandardAboutPanel`) с credits |

## Как переносить в SwiftUI

Wireframe — эскиз, а не макет для попиксельного копирования. При реализации:

- **Цвета** берём системные, а не hex из wireframe: фон панели — `windowBackgroundColor`, карточки — `controlBackgroundColor`, вторичный текст — `secondaryLabelColor`, разделители — `separatorColor`, акцент — `accentColor`. Подсветка diff: `systemGreen` 20% (ошибки, сплошное подчёркивание), `systemBlue` 15% (стиль, пунктирное), удалённое — зачёркнутое `secondaryLabelColor`.
- **Контролы** — стандартные: `Picker` со стилем `.menu` (pop-up buttons в шапке), `Toggle` (switch в Settings), `Form` со стилем `.grouped` (Settings), `Table` (словарь), `TextEditor` (поле диалога, Context, редактор промптов), `KeyboardShortcuts.Recorder` (сочетания клавиш).
- **Размеры** — регулярные системные: высота контролов 22 pt, строки Settings 40–44 pt, ширина панели 520–560 pt, шрифт текста версии 14 pt, остальное 13 pt системный.
- **Тексты** — копируются из wireframe как есть (они уже в title case / sentence case по HIG, §6 05-ui).
- **Поведение** берём из 05-ui, а не из JS wireframe: в wireframe интерактивность имитационная.

## Дальше

Как только появятся SwiftUI-вью, у каждого экрана и состояния будет `#Preview` с теми же данными, что в wireframe (пример с Ravi, Version 1 / Version 2, «Is this polite?»). С этого момента живым эталоном UI становятся превью в Xcode, а wireframes остаются как исходное намерение.
