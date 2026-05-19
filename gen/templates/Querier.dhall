-- Generate DBTX interface and Queries struct
-- MVP: Minimal abstraction over pgx

let generateDBTX : Text
    = ''
// DBTX is the interface that both pgx.Conn and pgx.Tx implement
type DBTX interface {
	Query(ctx context.Context, sql string, args ...interface{}) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...interface{}) pgx.Row
	Exec(ctx context.Context, sql string, args ...interface{}) (pgconn.CommandTag, error)
}
''

let generateQueries : Text
    = ''
type Queries struct {
	db DBTX
}

func New(db DBTX) *Queries {
	return &Queries{db: db}
}

// WithTx returns a new Queries instance using the provided transaction
func (q *Queries) WithTx(tx pgx.Tx) *Queries {
	return &Queries{db: tx}
}
''

in  { generateDBTX
    , generateQueries
    }
