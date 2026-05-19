-- Example SQL queries for testing the generator

-- name: GetUser :one
SELECT id, name, email, bio, created_at
FROM users
WHERE id = $1;

-- name: ListUsers :many
SELECT id, name, email
FROM users
ORDER BY id;

-- name: CreateUser :one
INSERT INTO users (name, email, bio)
VALUES ($1, $2, $3)
RETURNING id, name, email, bio, created_at;

-- name: UpdateUser :exec
UPDATE users
SET name = $2, email = $3
WHERE id = $1;

-- name: DeleteUser :exec
DELETE FROM users
WHERE id = $1;

-- name: FindUserByEmail :one
SELECT id, name, email, bio, created_at
FROM users
WHERE email = $1;
