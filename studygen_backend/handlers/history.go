package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"studygen-backend/config"
	"studygen-backend/database"
	"studygen-backend/middleware"
	"studygen-backend/models"

	"github.com/gin-gonic/gin"
)

func GetHistory(c *gin.Context) {
	if !database.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "database belum terhubung"})
		return
	}

	userID := middleware.GetUserID(c)
	cacheKey := config.HistoryCacheKey(userID)

	// Cek cache dulu
	if cached, found := config.Cache.Get(cacheKey); found {
		c.JSON(http.StatusOK, gin.H{"data": cached, "from_cache": true})
		return
	}

	rows, err := database.DB.Query(
		`SELECT id, user_id, title, summary, extraction_mode,
		        last_score, created_at, updated_at
		 FROM quizzes
		 WHERE user_id = $1
		 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError,
			gin.H{"message": "Gagal mengambil history"})
		return
	}
	defer rows.Close()

	var quizzes []models.Quiz
	for rows.Next() {
		var q models.Quiz
		if err := rows.Scan(
			&q.ID, &q.UserID, &q.Title, &q.Summary,
			&q.ExtractionMode, &q.LastScore,
			&q.CreatedAt, &q.UpdatedAt,
		); err != nil {
			continue
		}
		var count int
		database.DB.QueryRow(
			"SELECT COUNT(*) FROM questions WHERE quiz_id = $1", q.ID,
		).Scan(&count)
		q.Questions = make([]models.Question, count)
		quizzes = append(quizzes, q)
	}

	if quizzes == nil {
		quizzes = []models.Quiz{}
	}

	// Simpan ke cache
	config.Cache.SetDefault(cacheKey, quizzes)

	c.JSON(http.StatusOK, gin.H{"data": quizzes})
}

func GetQuizByID(c *gin.Context) {
	if !database.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "database belum terhubung"})
		return
	}

	userID := middleware.GetUserID(c)
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "ID tidak valid"})
		return
	}

	// Cek cache
	cacheKey := config.QuizCacheKey(id)
	if cached, found := config.Cache.Get(cacheKey); found {
		c.JSON(http.StatusOK, gin.H{"quiz": cached})
		return
	}

	var quiz models.Quiz
	err = database.DB.QueryRow(
		`SELECT id, user_id, title, summary, extraction_mode,
		        last_score, created_at, updated_at
		 FROM quizzes WHERE id = $1 AND user_id = $2`,
		id, userID,
	).Scan(&quiz.ID, &quiz.UserID, &quiz.Title, &quiz.Summary,
		&quiz.ExtractionMode, &quiz.LastScore,
		&quiz.CreatedAt, &quiz.UpdatedAt)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"message": "Quiz tidak ditemukan"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError,
			gin.H{"message": "Terjadi kesalahan"})
		return
	}

	// Ambil pertanyaan
	qRows, err := database.DB.Query(
		`SELECT id, quiz_id, question, options, correct_answer, created_at
		 FROM questions WHERE quiz_id = $1`, quiz.ID,
	)
	if err == nil {
		defer qRows.Close()
		for qRows.Next() {
			var q models.Question
			var optJSON string
			if err := qRows.Scan(&q.ID, &q.QuizID, &q.Question,
				&optJSON, &q.CorrectAnswer, &q.CreatedAt); err != nil {
				continue
			}
			json.Unmarshal([]byte(optJSON), &q.Options)
			quiz.Questions = append(quiz.Questions, q)
		}
	}

	// Simpan ke cache
	config.Cache.SetDefault(cacheKey, quiz)

	c.JSON(http.StatusOK, gin.H{"quiz": quiz})
}

func DeleteQuiz(c *gin.Context) {
	if !database.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "database belum terhubung"})
		return
	}

	userID := middleware.GetUserID(c)
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "ID tidak valid"})
		return
	}

	var ownerID string
	err = database.DB.QueryRow(
		"SELECT user_id FROM quizzes WHERE id = $1", id,
	).Scan(&ownerID)

	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"message": "Quiz tidak ditemukan"})
		return
	}
	if ownerID != userID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Tidak diizinkan"})
		return
	}

	database.DB.Exec("DELETE FROM quizzes WHERE id = $1", id)

	// Hapus cache
	config.Cache.Delete(config.QuizCacheKey(id))
	config.Cache.Delete(config.HistoryCacheKey(userID))

	c.JSON(http.StatusOK, gin.H{"message": "Quiz berhasil dihapus"})
}

func UpdateScore(c *gin.Context) {
	if !database.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "database belum terhubung"})
		return
	}

	userID := middleware.GetUserID(c)
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "ID tidak valid"})
		return
	}

	var body struct {
		Score int `json:"score"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Score wajib diisi"})
		return
	}

	res, err := database.DB.Exec(
		"UPDATE quizzes SET last_score = $1 WHERE id = $2 AND user_id = $3",
		body.Score, id, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError,
			gin.H{"message": "Gagal update score"})
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Quiz tidak ditemukan"})
		return
	}

	// Invalidate cache supaya history refresh
	config.Cache.Delete(config.QuizCacheKey(id))
	config.Cache.Delete(config.HistoryCacheKey(userID))

	c.JSON(http.StatusOK, gin.H{"message": "Score berhasil disimpan"})
}
