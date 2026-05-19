# Сессия 2: Интеграция с gen-sdk

**Дата:** 2026-05-19  
**Время:** ~1.5 часа  
**Статус:** WIP - интеграция в процессе

---

## 🎯 Цель сессии

Интегрировать golang.gen с gen-sdk, изучив существующие генераторы (rust.gen, java.gen).

---

## ✅ Что сделано

### 1. Изучение существующих генераторов

**rust.gen:**
- Структура: Algebras/, Interpreters/, Templates/, Deps/
- Использует старую версию gen-sdk (f87c971e)
- Проблема: Natural/equal в старом Prelude

**java.gen:**
- Более новая версия gen-sdk (f45f4eca)
- Использует CodegenKit для работы с именами
- Чистая структура без Algebras

### 2. Создана структура интеграции

```
gen/
├── Deps/                    # Зависимости (новые)
│   ├── package.dhall
│   ├── Sdk.dhall           # gen-sdk v1.0
│   ├── Project.dhall       # Project types
│   ├── Prelude.dhall       # v23.1.0
│   ├── Lude.dhall          # v1.0.0
│   └── CodegenKit.dhall    # v0.3.0
├── Interpreters/            # Обработчики (новые)
│   ├── package.dhall
│   ├── Project.dhall       # Main interpreter
│   └── Query.dhall         # Query processor
├── templates/
│   └── package.dhall
├── Gen.dhall               # Обновлен
├── Config.dhall            # Обновлен (Type + default)
└── compile.dhall           # Обновлен
```

### 3. Обновлены зависимости

✅ **Prelude v23.1.0** - совместим с gen-sdk  
✅ **Lude v1.0.0** - новая версия без Compiled  
✅ **gen-sdk f45f4eca** - из java.gen  
✅ **CodegenKit v0.3.0** - для работы с именами

### 4. Созданы интерпретаторы

**Project.dhall:**
- Input: Project.Project
- Output: List Sdk.File.Type
- Пока возвращает пустой список

**Query.dhall:**
- Input: Project.Query
- Output: { queryName, queryPath, queryContent }
- Placeholder для генерации методов

---

## 🚧 Текущие проблемы

### 1. Sdk.module type mismatch

```dhall
Error: Wrong type of function argument
  - { … : … } (a record type)
  + List …
```

**Причина:** compile.dhall возвращает `List Sdk.File.Type`, но `Sdk.module` ожидает другой тип.

**Решение:** Нужно изучить сигнатуру `Sdk.module` и понять какой тип он ожидает.

### 2. Config.Type vs Config

Исправлено: теперь используем `Config.Type` в Gen.dhall.

---

## 📊 Статистика

- **Коммитов:** 5 (всего)
- **Новых файлов:** 10
- **Изменено файлов:** 3
- **Строк Dhall кода:** ~500

---

## 🔍 Следующие шаги

### Критично:

1. **Понять Sdk.module interface**
   ```bash
   docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
     dhall type --file gen/Deps/Sdk.dhall
   ```

2. **Исправить compile.dhall**
   - Изучить что возвращает java.gen/compile.dhall
   - Адаптировать наш compile.dhall

3. **Протестировать Gen.dhall**
   - Должен успешно type-check
   - Проверить на простом примере

### Дополнительно:

4. **Реализовать Project.dhall interpreter**
   - Обработка queries
   - Обработка custom types
   - Генерация файлов

5. **Создать тестовые фикстуры**
   - tests/Demo.dhall
   - Простой пример с одним запросом

---

## 💡 Изученные концепции

### gen-sdk архитектура:

1. **Sdk.module** - главная функция для создания генератора
   - Принимает: version, Config, compile
   - Возвращает: module interface

2. **Project.Project** - входные данные
   - queries: List Query
   - customTypes: List CustomType
   - migrations: List Migration

3. **Sdk.File.Type** - выходные файлы
   - path: Text
   - content: Text

4. **CodegenKit.Name** - утилиты для имен
   - toTextInSnake
   - toTextInPascal
   - toTextInKebab

---

## 📝 Заметки

### Различия rust.gen vs java.gen:

| Аспект | rust.gen | java.gen |
|--------|----------|----------|
| gen-sdk | f87c971e (старый) | f45f4eca (новый) |
| Prelude | v21.1.0 | v23.1.0 |
| Lude | v3.0.0 | v1.0.0 |
| Структура | Algebras + Interpreters | Только Interpreters |
| Compiled | Использует Lude.Compiled | Не использует |

### Выбор подхода:

Решили следовать **java.gen** подходу:
- ✅ Более новые зависимости
- ✅ Нет проблемы с Natural/equal
- ✅ Проще структура
- ✅ Работает с текущим gen-sdk

---

## 🔗 Полезные команды

```bash
# Проверка типов
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall type --file gen/Gen.dhall

# Изучение Sdk
docker run --rm -v "$PWD:/work" -w /work dhallhaskell/dhall \
  dhall --file gen/Deps/Sdk.dhall | less

# Сравнение с java.gen
diff -u /tmp/java.gen/gen/compile.dhall gen/compile.dhall
```

---

**Следующая сессия:** Исправить Sdk.module integration и создать первый рабочий прототип
