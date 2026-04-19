package database

import (
	"database/sql"
	"fmt"
	"log"
	"net/url"
	"studygen-backend/config"

	_ "github.com/jackc/pgx/v5/stdlib"
)

var DB *sql.DB

func Connect() {
	dsn := config.App.DatabaseURL
	if dsn == "" {
		u := &url.URL{
			Scheme: "postgres",
			User:   url.UserPassword(config.App.DBUser, config.App.DBPass),
			Host:   fmt.Sprintf("%s:%s", config.App.DBHost, config.App.DBPort),
			Path:   config.App.DBName,
		}
		q := u.Query()
		q.Set("sslmode", config.App.DBSSLMode)
		u.RawQuery = q.Encode()
		dsn = u.String()
	}

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		log.Printf("database open error: %v", err)
		return
	}

	if err := db.Ping(); err != nil {
		log.Printf("database ping error: %v", err)
		_ = db.Close()
		return
	}

	DB = db
	log.Println("database connected")
}

func IsConnected() bool {
	if DB == nil {
		return false
	}

	if err := DB.Ping(); err != nil {
		log.Printf("database ping error: %v", err)
		return false
	}

	return true
}

func Migrate() {
	if DB == nil {
		log.Println("skip migration: database belum terhubung")
		return
	}

	queries := []string{
		`CREATE TABLE IF NOT EXISTS quizzes (
			id              BIGSERIAL PRIMARY KEY,
			user_id         UUID NOT NULL,
			title           VARCHAR(255) NOT NULL,
			summary         TEXT NOT NULL,
			extraction_mode VARCHAR(50) NOT NULL DEFAULT 'parser',
			last_score      INT NULL,
			created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
		);`,

		`CREATE TABLE IF NOT EXISTS questions (
			id             BIGSERIAL PRIMARY KEY,
			quiz_id        BIGINT NOT NULL,
			question       TEXT NOT NULL,
			options        JSONB NOT NULL,
			correct_answer SMALLINT NOT NULL,
			created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE
		);`,

		`CREATE OR REPLACE FUNCTION set_updated_at()
		RETURNS TRIGGER AS $$
		BEGIN
			NEW.updated_at = NOW();
			RETURN NEW;
		END;
		$$ LANGUAGE plpgsql;`,

		`DROP TRIGGER IF EXISTS quizzes_set_updated_at ON quizzes;`,
		`CREATE TRIGGER quizzes_set_updated_at
		BEFORE UPDATE ON quizzes
		FOR EACH ROW
		EXECUTE FUNCTION set_updated_at();`,

		`CREATE INDEX IF NOT EXISTS idx_quizzes_user_id_created_at ON quizzes(user_id, created_at DESC);`,
		`CREATE INDEX IF NOT EXISTS idx_questions_quiz_id ON questions(quiz_id);`,

		`ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;`,
		`ALTER TABLE questions ENABLE ROW LEVEL SECURITY;`,

		`DROP POLICY IF EXISTS quizzes_select_own ON quizzes;`,
		`CREATE POLICY quizzes_select_own ON quizzes FOR SELECT USING (auth.uid() = user_id);`,
		`DROP POLICY IF EXISTS quizzes_insert_own ON quizzes;`,
		`CREATE POLICY quizzes_insert_own ON quizzes FOR INSERT WITH CHECK (auth.uid() = user_id);`,
		`DROP POLICY IF EXISTS quizzes_update_own ON quizzes;`,
		`CREATE POLICY quizzes_update_own ON quizzes FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);`,
		`DROP POLICY IF EXISTS quizzes_delete_own ON quizzes;`,
		`CREATE POLICY quizzes_delete_own ON quizzes FOR DELETE USING (auth.uid() = user_id);`,

		`DROP POLICY IF EXISTS questions_select_own ON questions;`,
		`CREATE POLICY questions_select_own ON questions FOR SELECT USING (
			EXISTS (SELECT 1 FROM quizzes q WHERE q.id = questions.quiz_id AND q.user_id = auth.uid())
		);`,
		`DROP POLICY IF EXISTS questions_insert_own ON questions;`,
		`CREATE POLICY questions_insert_own ON questions FOR INSERT WITH CHECK (
			EXISTS (SELECT 1 FROM quizzes q WHERE q.id = questions.quiz_id AND q.user_id = auth.uid())
		);`,
		`DROP POLICY IF EXISTS questions_update_own ON questions;`,
		`CREATE POLICY questions_update_own ON questions FOR UPDATE USING (
			EXISTS (SELECT 1 FROM quizzes q WHERE q.id = questions.quiz_id AND q.user_id = auth.uid())
		) WITH CHECK (
			EXISTS (SELECT 1 FROM quizzes q WHERE q.id = questions.quiz_id AND q.user_id = auth.uid())
		);`,
		`DROP POLICY IF EXISTS questions_delete_own ON questions;`,
		`CREATE POLICY questions_delete_own ON questions FOR DELETE USING (
			EXISTS (SELECT 1 FROM quizzes q WHERE q.id = questions.quiz_id AND q.user_id = auth.uid())
		);`,
	}

	for _, q := range queries {
		if _, err := DB.Exec(q); err != nil {
			log.Fatalf("Migration failed: %v", err)
		}
	}

	log.Println("✅ Migrations done")
}
