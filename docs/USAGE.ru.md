# Подключение golang.gen к своему Go-проекту

Пошаговый гайд: что и где должно лежать, чтобы из SQL получить типобезопасный
Go-пакет.

## Как это работает

pGenie CLI (`pgn`) читает ваш проект (миграции + запросы), валидирует его
против **реального PostgreSQL**, выводит типы параметров и результатов
(включая nullability и кардинальность) и прогоняет генератор
(этот репозиторий — Dhall-программа) — на выходе Go-пакет в `artifacts/go/`.

## 1. Установка pgn CLI

Вариант A — готовый бинарник из релизов:

```bash
curl -fsSL "https://github.com/pgenie-io/pgenie/releases/download/v0.6.2/pgn-linux-x64.tar.gz" \
  | sudo tar xz -C /usr/local/bin
```

Вариант B — Homebrew: `brew install pgenie-io/tap/pgn`.

Документация: https://pgenie.io/docs/guides/installation/

Также понадобится запущенный PostgreSQL нужной версии — pgn валидирует схему
и запросы на живой базе (удобно поднять одноразовый
`docker run -d -e POSTGRES_PASSWORD=pw -p 5498:5432 postgres:18`).

## 2. Структура проекта

```
my-service/                      # ваш Go-репозиторий
├── go.mod                       # ваш модуль (например, github.com/you/my-service)
├── go.work                      # подключает artifacts/go (см. шаг 5)
├── main.go
│
├── project1.pgn.yaml            # конфиг pGenie — в корне проекта
├── migrations/                  # схема: обычные SQL-миграции, по порядку
│   ├── 0001_create_users.sql
│   └── 0002_add_bio.sql
├── queries/                     # ОДИН запрос на файл; имя файла = имя метода
│   ├── get_user.sql             #   → метод GetUser
│   ├── list_users.sql           #   → метод ListUsers
│   └── create_user.sql          #   → метод CreateUser
│
└── artifacts/
    └── go/                      # ← генерируется pgn, в git можно и коммитить,
        ├── go.mod               #   и добавлять в .gitignore + генерить в CI
        ├── db.go
        ├── models.go            # только если в схеме есть enum/composite/domain
        └── queries.sql.go
```

Живой пример проекта: https://github.com/pgenie-io/demo

## 3. project1.pgn.yaml

```yaml
# Неймспейс: ваш ник или организация. Влияет на module path артефакта.
space: you

# Имя проекта. По умолчанию — имя Go-пакета.
name: my_service

# Версия для генерируемых артефактов (SemVer).
version: 0.1.0

# Версия PostgreSQL для валидации.
postgres: 18

artifacts:
  # Простая форма — только генератор:
  go: https://github.com/scarymovie/pgengine.golang.gen/releases/download/v0.1.0/resolved.dhall

  # Либо с конфигом:
  # go:
  #   gen: https://github.com/scarymovie/pgengine.golang.gen/releases/download/v0.1.0/resolved.dhall
  #   config:
  #     packageName: db      # имя Go-пакета (по умолчанию — name проекта)
  #     emitGoMod: true      # false → без go.mod, для вендоринга в свой модуль
  #     useGoogleUuid: false # true → uuid-колонки как uuid.UUID из
  #                          # github.com/google/uuid вместо string
```

Ссылка на `releases/download/vX.Y.Z/resolved.dhall` — замороженный
самодостаточный Dhall (без сетевых импортов). Для экспериментов можно
указать `raw/main/gen/Gen.dhall` или локальный путь к клону генератора.

## 4. SQL: миграции и запросы

`migrations/*.sql` — обычный DDL, выполняется по алфавитному порядку имён:

```sql
-- migrations/0001_create_users.sql
create table users (
  id bigint generated always as identity primary key,
  name text not null,
  email text not null unique,
  bio text,
  created_at timestamptz not null default now()
);
```

`queries/*.sql` — один параметризованный запрос на файл, параметры через
`$имя`:

```sql
-- queries/get_user.sql  →  func (q *Queries) GetUser(ctx, GetUserParams) (GetUserRow, error)
select id, name, email, bio, created_at
from users
where id = $id
```

Кардинальность результата pgn выводит сам: уникальный ключ в `where` →
одна строка; без него → срез; `insert/update/delete` без `returning` →
`RowsAffected`/`Void`. Сигнатуры:

| Результат | Go-сигнатура |
|---|---|
| Single | `(Row, error)` |
| Optional | `(*Row, error)` — `nil`, если не найдено |
| Multiple | `([]Row, error)` |
| RowsAffected | `(int64, error)` |
| Void | `error` |

## 5. Генерация и подключение к модулю

```bash
pgn --database-url "postgresql://postgres:pw@127.0.0.1:5498/postgres" generate
```

Артефакт появится в `artifacts/go/`. Дальше два варианта.

**Вариант A: отдельный модуль (emitGoMod: true, по умолчанию)** — workspace:

```bash
go work init . ./artifacts/go
```

или `replace` в своём go.mod:

```
require you/my_service v0.0.0
replace you/my_service => ./artifacts/go
```

(module path артефакта = `<space>/<packageName>`; версия при replace на
директорию не важна).

**Вариант B: вендоринг (emitGoMod: false)** — артефакт без go.mod, кладёте
вывод прямо в поддиректорию своего модуля (например `internal/db/`) и
импортируете как обычный внутренний пакет.

## 6. Использование в коде

```go
package main

import (
    "context"
    "log"

    "github.com/jackc/pgx/v5"
    db "you/my_service"
)

func main() {
    ctx := context.Background()
    conn, err := pgx.Connect(ctx, "postgres://localhost/mydb")
    if err != nil { log.Fatal(err) }
    defer conn.Close(ctx)

    // Только если в схеме есть кастомные типы (enum/composite/domain):
    // if err := db.RegisterTypes(ctx, conn); err != nil { log.Fatal(err) }

    q := db.New(conn)

    user, err := q.GetUser(ctx, db.GetUserParams{ID: 1})
    if err != nil { log.Fatal(err) }
    log.Printf("%+v", user)
}
```

Транзакции: `q.WithTx(tx)` возвращает `*Queries` поверх `pgx.Tx`.
При пуле (`pgxpool`) `RegisterTypes` вызывайте в `AfterConnect`.

## 7. Рабочий цикл

1. Меняете схему → новый файл в `migrations/` (старые не редактируются).
2. Меняете/добавляете запрос в `queries/`.
3. `pgn generate` (база должна быть доступна) → артефакт перегенерирован.
4. `go build ./...` — компилятор поймает все разъехавшиеся типы.

Накат миграций на боевую базу pgn не делает — это ваша забота
(те же файлы `migrations/` можно скармливать goose/tern/psql).

## Маппинг типов (кратко)

NOT NULL → нативный тип, nullable → указатель, массивы → срезы.
`uuid`, `numeric`, `inet`, `interval` и пр. — каноничная текстовая форма
(`string`), без сторонних зависимостей в публичном API. `bytea`/`json`/`jsonb`
→ `[]byte`. Полная таблица — в [README](../README.md#type-mapping).
