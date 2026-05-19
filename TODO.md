# TODO

## Текущий статус

✅ Создана базовая структура проекта
✅ Dhall шаблоны для генерации кода (упрощенные)
✅ Примеры SQL запросов и схемы
✅ Ожидаемый сгенерированный код
✅ Документация (README.md, CLAUDE.md)
✅ Поддержка Go 1.26

## Следующие шаги

### 1. Интеграция с gen-sdk
- [ ] Исправить зависимости gen-sdk (проблема с Natural/equal)
- [ ] Реализовать compile.dhall для работы с gen-sdk API
- [ ] Подключить к типам из gen-sdk (Project, Statement, etc.)

### 2. Улучшение TypeMapping.dhall
- [ ] Реализовать полный маппинг PostgreSQL → Go типов
- [ ] Использовать типы из gen-sdk вместо placeholder'ов
- [ ] Добавить поддержку массивов, enum, composite типов

### 3. Тестирование
- [ ] Создать тестовые фикстуры с gen-sdk
- [ ] Проверить генерацию на примерах
- [ ] Сравнить с ожидаемым результатом в tests/expected/

### 4. Dhall инструменты
- [ ] Создать скрипт для запуска Dhall через Docker
- [ ] Добавить команды для форматирования и проверки типов
- [ ] Настроить CI для валидации Dhall кода

### 5. Документация
- [ ] Добавить примеры использования с реальной БД
- [ ] Документировать процесс разработки генератора
- [ ] Создать CONTRIBUTING.md

## Известные проблемы

1. **gen-sdk зависимости**: Ошибка `Natural/equal` при загрузке gen-sdk
   - Возможно, нужна другая версия Dhall или gen-sdk
   - Или нужно использовать frozen imports

2. **TypeMapping упрощен**: Текущая версия возвращает placeholder'ы
   - Нужна интеграция с gen-sdk для получения реальных типов

3. **compile.dhall пустой**: Основная логика компиляции еще не реализована
   - Нужно изучить API gen-sdk
   - Посмотреть на rust.gen и java.gen как примеры

## Полезные команды

```bash
# Проверка типов Dhall через Docker
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall dhall type --file gen/Gen.dhall

# Форматирование Dhall файлов
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall dhall format --inplace gen/**/*.dhall

# Тестирование генерации
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall dhall --file tests/Demo.dhall
```
