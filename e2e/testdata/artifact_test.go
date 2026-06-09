// E2E test for the generated artifact. e2e/run.sh copies this file into the
// generated package (artifacts/go) and runs it against the migrated database
// from pgenie-io/demo (music_catalogue schema).
package music_catalogue

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

func TestPgnArtifact(t *testing.T) {
	dsn := os.Getenv("PGN_E2E_DSN")
	if dsn == "" {
		t.Skip("PGN_E2E_DSN is not set")
	}
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(ctx)

	if err := RegisterTypes(ctx, conn); err != nil {
		t.Fatal("RegisterTypes:", err)
	}
	q := New(conn)

	released := time.Date(1973, 3, 1, 0, 0, 0, 0, time.UTC)
	format := AlbumFormatVinyl
	studio := "Abbey Road"
	rec := &RecordingInfo{StudioName: &studio}
	row, err := q.InsertAlbum(ctx, InsertAlbumParams{
		Name: "The Dark Side of the Moon", Released: &released, Format: &format, Recording: rec,
	})
	if err != nil {
		t.Fatal("InsertAlbum:", err)
	}
	t.Logf("inserted id=%d", row.Id)

	got, err := q.SelectAlbumById(ctx, SelectAlbumByIdParams{Id: &row.Id})
	if err != nil {
		t.Fatal("SelectAlbumById:", err)
	}
	if got == nil || got.Name != "The Dark Side of the Moon" {
		t.Fatalf("unexpected row: %+v", got)
	}
	if got.Recording == nil || got.Recording.StudioName == nil || *got.Recording.StudioName != "Abbey Road" {
		t.Fatalf("composite roundtrip failed: %+v", got.Recording)
	}

	byFormat, err := q.SelectAlbumByFormat(ctx, SelectAlbumByFormatParams{Format: &format})
	if err != nil {
		t.Fatal("SelectAlbumByFormat:", err)
	}
	if len(byFormat) == 0 {
		t.Fatal("expected at least one album by format")
	}

	n, err := q.UpdateAlbumReleased(ctx, UpdateAlbumReleasedParams{Released: &released, Id: &row.Id})
	if err != nil {
		t.Fatal("UpdateAlbumReleased:", err)
	}
	if n != 1 {
		t.Fatalf("RowsAffected = %d, want 1", n)
	}

	path := "rock.progressive"
	if _, err := q.SelectGenreByPath(ctx, SelectGenreByPathParams{Path: &path}); err != nil {
		t.Fatal("SelectGenreByPath (ltree):", err)
	}

	missing := int64(999999)
	none, err := q.SelectAlbumById(ctx, SelectAlbumByIdParams{Id: &missing})
	if err != nil {
		t.Fatal("optional:", err)
	}
	if none != nil {
		t.Fatal("expected nil for missing row")
	}
}
