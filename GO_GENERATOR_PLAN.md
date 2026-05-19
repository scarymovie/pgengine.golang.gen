# План создания Go генератора для pGenie

**Дата создания:** 2026-05-19  
**Статус:** Планирование

## Обзор

Создание генератора кода для Go (Golang) в экосистеме pGenie. Генератор будет создавать type-safe Go код для работы с PostgreSQL на основе SQL запросов.

## Текущая ситуация

### Существующие генераторы в pgenie-io:
- ✅ **java.gen** - генератор для Java (Maven проект)
- ✅ **rust.gen** - генератор для Rust (Cargo проект)  
- ✅ **haskell.gen** - генератор для Haskell
- 🚧 **c-sharp.gen-design** - набросок для C# (в стадии дизайна)
- ❌ **go.gen** - НЕ СУЩЕСТВУЕТ (это мы и создаём!)

### Доступные ресурсы:
- **gen-sdk** - SDK с контрактом и API для создания генераторов
  - Репозиторий: https://github.com/pgenie-io/gen-sdk
  - Dhall API в `dhall/package.dhall`
  - Документация: https://pgenie-io.github.io/gen-sdk/dhall/
- **Примеры генераторов:**
  - rust.gen: https://github.com/pgenie-io/rust.gen
  - java.gen: https://github.com/pgenie-io/java.gen

## Архитектура генератора

### Структура репозитория

```
go.gen/  (или golang.gen)
├── README.md                    # Документация по использованию
├── LICENSE                      # Лицензия (GPL-3.0 как у других генераторов)
├── gen/
│   ├── Gen.dhall               # Главная точка входа генератора
│   ├── Config.dhall            # Схема конфигурации
│   ├── compile.dhall           # Основная логика компиляции
│   ├── types/
│   │   ├── TypeMapping.dhall   # Маппинг PostgreSQL → Go типы
│   │   ├── Primitive.dhall     # Обработка примитивных типов
│   │   ├── Custom.dhall        # Обработка кастомных типов (enum, composite)
│   │   └── Array.dhall         # Обработка массивов
│   ├── statements/
│   │   ├── Statement.dhall     # Генерация функций для запросов
│   │   ├── Input.dhall         # Генерация Input структур
│   │   ├── Output.dhall        # Генерация Output структур
│   │   └── Execution.dhall     # Логика выполнения запросов
│   └── templates/
│       ├── go.mod.dhall        # Шаблон go.mod
│       ├── types.go.dhall      # Шаблон для кастомных типов
│       ├── statement.go.dhall  # Шаблон для функций запросов
│       └── errors.go.dhall     # Шаблон для обработки ошибок
├── tests/
│   ├── Demo.dhall              # Тестовые фикстуры
│   └── expected/               # Ожидаемый сгенерированный код
├── examples/
│   ├── basic/                  # Базовый пример использования
│   └── advanced/               # Продвинутый пример
└── .github/
    └── workflows/
        ├── test.yaml           # CI для тестирования генератора
        └── dhall.yaml          # Валидация Dhall кода
```

### Точка входа Gen.dhall

Структура по аналогии с другими генераторами:

```dhall
let Sdk = https://raw.githubusercontent.com/pgenie-io/gen-sdk/master/dhall/package.dhall

let Config = ./Config.dhall
let compile = ./compile.dhall

in Sdk.module
  { major = 1, minor = 0 }  -- Версия контракта
  Config
  compile
```

## Маппинг типов PostgreSQL → Go

### Примитивные типы

| PostgreSQL Type | Go Type | Nullable Go Type | Библиотека |
|----------------|---------|------------------|------------|
| `bool` | `bool` | `*bool` или `sql.NullBool` | stdlib |
| `int2` (smallint) | `int16` | `*int16` или `sql.NullInt16` | stdlib |
| `int4` (integer) | `int32` | `*int32` или `sql.NullInt32` | stdlib |
| `int8` (bigint) | `int64` | `*int64` или `sql.NullInt64` | stdlib |
| `float4` (real) | `float32` | `*float32` или `sql.NullFloat64` | stdlib |
| `float8` (double) | `float64` | `*float64` atau `sql.NullFloat64` | stdlib |
| `numeric` | `string` или `decimal.Decimal` | `*string` | github.com/shopspring/decimal |
| `text` | `string` | `*string` atau `sql.NullString` | stdlib |
| `varchar` | `string` | `*string` atau `sql.NullString` | stdlib |
| `bytea` | `[]byte` | `[]byte` (nil для NULL) | stdlib |
| `uuid` | `uuid.UUID` | `*uuid.UUID` atau `uuid.NullUUID` | github.com/google/uuid |
| `date` | `time.Time` | `*time.Time` atau `sql.NullTime` | stdlib |
| `timestamp` | `time.Time` | `*time.Time` atau `sql.NullTime` | stdlib |
| `timestamptz` | `time.Time` | `*time.Time` atau `sql.NullTime` | stdlib |
| `time` | `time.Time` | `*time.Time` | stdlib |
| `interval` | `time.Duration` atau `string` | `*time.Duration` | stdlib |
| `json` | `json.RawMessage` | `json.RawMessage` (nil для NULL) | stdlib |
| `jsonb` | `json.RawMessage` | `json.RawMessage` (nil для NULL) | stdlib |
| `inet` | `net.IP` | `*net.IP` | stdlib |
| `cidr` | `*net.IPNet` | `*net.IPNet` | stdlib |
| `macaddr` | `net.HardwareAddr` | `net.HardwareAddr` | stdlib |
| `array[]` | `[]T` | `[]T` (nil для NULL) | stdlib |

### Кастомные типы

**Enum:**
```go
type UserRole string

const (
    UserRoleAdmin UserRole = "admin"
    UserRoleUser  UserRole = "user"
    UserRoleGuest UserRole = "guest"
)

// Scan implements sql.Scanner
func (r *UserRole) Scan(value interface{}) error { ... }

// Value implements driver.Valuer
func (r UserRole) Value() (driver.Value, error) { ... }
```

**Composite:**
```go
type Address struct {
    Street  string
    City    string
    ZipCode *string // nullable поле
}

// Scan implements sql.Scanner
func (a *Address) Scan(value interface{}) error { ... }

// Value implements driver.Valuer
func (a Address) Value() (driver.Value, error) { ... }
```

## Генерируемый код

### Пример структуры проекта

```
generated/
├── go.mod
├── go.sum
├── types/
│   ├── user_role.go        # Enum типы
│   ├── address.go          # Composite типы
│   └── types.go            # Общие утилиты
├── statements/
│   ├── get_user_by_id.go
│   ├── create_user.go
│   ├── update_user.go
│   └── delete_user.go
└── client.go               # Опциональный клиент-обёртка
```

### Пример сгенерированного кода для запроса

```go
package statements

import (
    "context"
    "database/sql"
    "fmt"
)

// GetUserByIDInput represents input parameters for GetUserByID query
type GetUserByIDInput struct {
    UserID int64 `db:"user_id"`
}

// GetUserByIDOutput represents output row for GetUserByID query
type GetUserByIDOutput struct {
    ID        int64     `db:"id"`
    Name      string    `db:"name"`
    Email     string    `db:"email"`
    Role      UserRole  `db:"role"`
    CreatedAt time.Time `db:"created_at"`
}

const getUserByIDSQL = `
SELECT id, name, email, role, created_at
FROM users
WHERE id = $1
`

// GetUserByID executes the query and returns a single row
func GetUserByID(ctx context.Context, db *sql.DB, input GetUserByIDInput) (*GetUserByIDOutput, error) {
    row := db.QueryRowContext(ctx, getUserByIDSQL, input.UserID)
    
    var output GetUserByIDOutput
    err := row.Scan(
        &output.ID,
        &output.Name,
        &output.Email,
        &output.Role,
        &output.CreatedAt,
    )
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, fmt.Errorf("user not found: %w", err)
        }
        return nil, fmt.Errorf("failed to scan row: %w", err)
    }
    
    return &output, nil
}
```

### Пример для запроса с множественными результатами

```go
// ListUsersOutput represents output row for ListUsers query
type ListUsersOutput struct {
    ID    int64  `db:"id"`
    Name  string `db:"name"`
    Email string `db:"email"`
}

const listUsersSQL = `SELECT id, name, email FROM users ORDER BY id`

// ListUsers executes the query and returns multiple rows
func ListUsers(ctx context.Context, db *sql.DB) ([]ListUsersOutput, error) {
    rows, err := db.QueryContext(ctx, listUsersSQL)
    if err != nil {
        return nil, fmt.Errorf("failed to execute query: %w", err)
    }
    defer rows.Close()
    
    var results []ListUsersOutput
    for rows.Next() {
        var output ListUsersOutput
        err := rows.Scan(&output.ID, &output.Name, &output.Email)
        if err != nil {
            return nil, fmt.Errorf("failed to scan row: %w", err)
        }
        results = append(results, output)
    }
    
    if err := rows.Err(); err != nil {
        return nil, fmt.Errorf("error iterating rows: %w", err)
    }
    
    return results, nil
}
```

## Конфигурация генератора

### Config.dhall

```dhall
{ Type =
    { -- Использовать указатели для nullable полей вместо sql.Null* типов
      usePointers : Bool
    , -- Генерировать клиент-обёртку
      generateClient : Bool
    , -- Имя пакета для сгенерированного кода
      packageName : Optional Text
    , -- Использовать pgx вместо database/sql
      usePgx : Bool
    , -- Генерировать тесты
      generateTests : Bool
    }
, default =
    { usePointers = True
    , generateClient = False
    , packageName = None Text
    , usePgx = False
    , generateTests = False
    }
}
```

## Решения по дизайну

### 1. Библиотека для работы с PostgreSQL

**Вариант A: database/sql + lib/pq (рекомендуется для начала)**
- ✅ Стандартная библиотека Go
- ✅ Стабильная и проверенная временем
- ✅ Простая интеграция
- ❌ Меньше фич чем pgx

**Вариант B: pgx**
- ✅ Более современная
- ✅ Лучшая производительность
- ✅ Больше PostgreSQL-специфичных фич
- ✅ Поддержка prepared statements, batch operations
- ❌ Более сложная интеграция

**Решение:** Начать с database/sql, добавить опцию для pgx через Config

### 2. Nullable поля

**Вариант A: Указатели (*string, *int64)**
- ✅ Идиоматично для Go
- ✅ Проще в использовании
- ❌ Требует аллокации

**Вариант B: sql.Null* типы**
- ✅ Стандартные типы из database/sql
- ❌ Менее удобны в использовании (нужно проверять .Valid)

**Решение:** Указатели по умолчанию, опция в Config для sql.Null*

### 3. Стиль API

**Вариант A: Функции (рекомендуется)**
```go
result, err := statements.GetUserByID(ctx, db, input)
```
- ✅ Простой и прямолинейный
- ✅ Легко тестировать
- ✅ Не требует инициализации

**Вариант B: Методы на Client**
```go
client := NewClient(db)
result, err := client.GetUserByID(ctx, input)
```
- ✅ Можно добавить middleware
- ✅ Удобно для dependency injection
- ❌ Требует дополнительный код

**Решение:** Функции по умолчанию, опциональная генерация Client через Config

### 4. Обработка ошибок

```go
// Wrapped errors с контекстом
return nil, fmt.Errorf("failed to execute query %s: %w", queryName, err)

// Специальные ошибки для NotFound
var ErrNotFound = errors.New("record not found")

if err == sql.ErrNoRows {
    return nil, ErrNotFound
}
```

### 5. Карточность результатов (Result Cardinality)

Из `Project.dhall`:
```dhall
let ResultRowsCardinality = < Optional | Single | Multiple >
```

**Маппинг на Go:**
- `Optional` → возвращает `*Output, error` (может быть nil без ошибки)
- `Single` → возвращает `*Output, error` (nil только при ошибке, ErrNotFound если нет строк)
- `Multiple` → возвращает `[]Output, error` (пустой слайс если нет строк)

## План реализации

### Фаза 1: Подготовка (1-2 дня)
- [ ] Создать репозиторий go.gen
- [ ] Изучить детально rust.gen и java.gen
- [ ] Изучить gen-sdk Dhall API
- [ ] Создать базовую структуру файлов
- [ ] Настроить CI/CD

### Фаза 2: Маппинг типов (2-3 дня)
- [ ] Реализовать TypeMapping.dhall для примитивных типов
- [ ] Реализовать обработку Enum типов
- [ ] Реализовать обработку Composite типов
- [ ] Реализовать обработку Array типов
- [ ] Написать тесты для маппинга типов

### Фаза 3: Генерация кода (3-5 дней)
- [ ] Реализовать шаблоны для Input структур
- [ ] Реализовать шаблоны для Output структур
- [ ] Реализовать генерацию функций запросов
- [ ] Реализовать обработку разных cardinality (Optional/Single/Multiple)
- [ ] Реализовать генерацию go.mod

### Фаза 4: Тестирование (2-3 дня)
- [ ] Создать тестовые фикстуры
- [ ] Протестировать на примерах из gen-sdk/Fixtures
- [ ] Создать интеграционные тесты
- [ ] Проверить сгенерированный код компилируется
- [ ] Проверить сгенерированный код работает с реальной БД

### Фаза 5: Документация и примеры (1-2 дня)
- [ ] Написать README.md
- [ ] Создать примеры использования
- [ ] Документировать Config опции
- [ ] Создать CONTRIBUTING.md

### Фаза 6: Дополнительные фичи (опционально)
- [ ] Поддержка pgx через Config
- [ ] Генерация Client обёртки
- [ ] Генерация тестов
- [ ] Поддержка prepared statements
- [ ] Поддержка транзакций

## Технические детали

### Зависимости для сгенерированного кода

```go.mod
module github.com/username/project

go 1.22

require (
    github.com/lib/pq v1.10.9                    // PostgreSQL driver
    github.com/google/uuid v1.6.0                // UUID support
    github.com/shopspring/decimal v1.3.1         // Decimal/numeric support (опционально)
)
```

### Dhall зависимости

```dhall
-- В Gen.dhall
let Sdk = https://raw.githubusercontent.com/pgenie-io/gen-sdk/master/dhall/package.dhall
let Prelude = https://prelude.dhall-lang.org/v21.1.0/package.dhall
```

### Структура Dhall функций

```dhall
-- types/TypeMapping.dhall
let Sdk = ../../../gen-sdk/dhall/package.dhall

let primitiveToGoType : Sdk.Project.Primitive -> Text
    = \(primitive : Sdk.Project.Primitive) ->
        merge
          { Bool = "bool"
          , Int2 = "int16"
          , Int4 = "int32"
          , Int8 = "int64"
          , Float4 = "float32"
          , Float8 = "float64"
          , Text = "string"
          , Uuid = "uuid.UUID"
          , Timestamp = "time.Time"
          , Timestamptz = "time.Time"
          , Json = "json.RawMessage"
          , Jsonb = "json.RawMessage"
          -- ... остальные типы
          }
          primitive

in { primitiveToGoType }
```

## Полезные ссылки

### Документация pGenie
- Главный репозиторий: https://github.com/pgenie-io/pgenie
- gen-sdk: https://github.com/pgenie-io/gen-sdk
- Dhall API docs: https://pgenie-io.github.io/gen-sdk/dhall/
- Haskell API docs: https://pgenie-io.github.io/gen-sdk/haskell/

### Примеры генераторов
- rust.gen: https://github.com/pgenie-io/rust.gen
- java.gen: https://github.com/pgenie-io/java.gen
- haskell.gen: https://github.com/pgenie-io/haskell.gen

### Dhall
- Dhall язык: https://dhall-lang.org/
- Dhall tutorial: https://docs.dhall-lang.org/tutorials/Getting-started_Generate-JSON-or-YAML.html
- Dhall Prelude: https://prelude.dhall-lang.org/

### Go PostgreSQL библиотеки
- database/sql: https://pkg.go.dev/database/sql
- lib/pq: https://github.com/lib/pq
- pgx: https://github.com/jackc/pgx

## Вопросы для обсуждения

1. **Название репозитория:** `go.gen` или `golang.gen`?
2. **Лицензия:** GPL-3.0 (как у других) или MIT?
3. **Минимальная версия Go:** 1.21, 1.22, или 1.23?
4. **Стиль именования:** snake_case для файлов или camelCase?
5. **Генерация тестов:** Нужна ли автоматическая генерация unit/integration тестов?
6. **Connection pooling:** Генерировать код для работы с пулом соединений?
7. **Prepared statements:** Генерировать код с prepared statements для переиспользования?
8. **Транзакции:** Генерировать варианты функций принимающих *sql.Tx?

## Следующие шаги

1. Создать репозиторий (например, `go.gen`)
2. Перенести этот файл туда как `PLAN.md`
3. Создать базовую структуру директорий
4. Начать с изучения rust.gen и java.gen в деталях
5. Реализовать минимальный прототип для одного простого запроса
6. Итеративно расширять функциональность

---

**Автор:** Claude Code  
**Дата последнего обновления:** 2026-05-19
