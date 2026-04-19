package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"studygen-backend/config"
	"studygen-backend/database"
	"studygen-backend/middleware"
	"studygen-backend/models"
	"studygen-backend/services"

	"github.com/gin-gonic/gin"
)

func Generate(c *gin.Context) {
	if !database.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "database belum terhubung"})
		return
	}

	userID := middleware.GetUserID(c)

	// Ambil parameter
	extractionMode := c.DefaultPostForm("extraction_mode", "parser")
	summaryLength := c.DefaultPostForm("summary_length", "medium")

	if err := services.ValidateOCRMode(extractionMode); err != nil {
		if extractionMode != "parser" && extractionMode != "tesseract" && extractionMode != "mistral" {
			c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": fmt.Sprintf("OCR tidak tersedia: %v", err)})
		return
	}

	if err := services.ValidateGroqConnection(); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": fmt.Sprintf("API AI tidak tersedia: %v", err)})
		return
	}

	// Ambil file PDF
	file, err := c.FormFile("pdf")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "File PDF wajib diupload"})
		return
	}

	// Validasi ekstensi
	if !strings.EqualFold(filepath.Ext(file.Filename), ".pdf") {
		c.JSON(http.StatusBadRequest, gin.H{"message": "File harus berformat PDF"})
		return
	}

	// Validasi ukuran (max 20MB)
	if file.Size > 20*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ukuran file maksimal 20MB"})
		return
	}

	// Simpan file sementara
	tmpDir, _ := os.MkdirTemp("", "studygen-upload-*")
	defer os.RemoveAll(tmpDir)

	filePath := filepath.Join(tmpDir, filepath.Base(file.Filename))
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Gagal menyimpan file"})
		return
	}

	// Step 1: Ekstraksi teks
	var pdfText string
	switch extractionMode {
	case "tesseract":
		pdfText, err = services.ExtractTextWithTesseract(filePath)
	case "mistral":
		pdfText, err = services.ExtractTextWithMistral(filePath)
	default:
		pdfText, err = services.ExtractTextWithPdftotext(filePath)
	}

	if err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"message": fmt.Sprintf("Gagal membaca PDF: %v", err),
		})
		return
	}

	if len(pdfText) < 50 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"message": "Teks terlalu sedikit. Coba mode ekstraksi lain.",
		})
		return
	}

	// Step 2: Generate rangkuman dengan Llama (fokus utama)
	summaryResult, err := services.GenerateSummaryWithGroq(pdfText, summaryLength)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": fmt.Sprintf("Gagal membuat rangkuman: %v", err),
		})
		return
	}

	// Step 3: Simpan ke database
	var quizID uint64
	err = database.DB.QueryRow(
		"INSERT INTO quizzes (user_id, title, summary, extraction_mode) VALUES ($1, $2, $3, $4) RETURNING id",
		userID, summaryResult.Title, summaryResult.Summary, extractionMode,
	).Scan(&quizID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Gagal menyimpan rangkuman"})
		return
	}

	// Fetch quiz lengkap
	var quiz models.Quiz
	database.DB.QueryRow(
		"SELECT id, user_id, title, summary, extraction_mode, last_score, created_at, updated_at FROM quizzes WHERE id = $1",
		quizID,
	).Scan(&quiz.ID, &quiz.UserID, &quiz.Title, &quiz.Summary,
		&quiz.ExtractionMode, &quiz.LastScore, &quiz.CreatedAt, &quiz.UpdatedAt)
	quiz.Questions = []models.Question{}

	// Invalidate cache history agar beranda langsung melihat rangkuman baru.
	config.Cache.Delete(config.HistoryCacheKey(userID))
	config.Cache.Delete(config.QuizCacheKey(quizID))

	c.JSON(http.StatusCreated, gin.H{
		"message": "Rangkuman berhasil dibuat!",
		"quiz":    quiz,
	})
}

func GenerateQuizFromSummary(c *gin.Context) {
	if !database.IsConnected() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "database belum terhubung"})
		return
	}

	userID := middleware.GetUserID(c)
	idStr := c.Param("id")
	quizID, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "ID tidak valid"})
		return
	}

	var body struct {
		NumQuestions int `json:"num_questions"`
	}
	_ = c.ShouldBindJSON(&body)
	if body.NumQuestions <= 0 {
		body.NumQuestions = 10
	}

	var quiz models.Quiz
	err = database.DB.QueryRow(
		`SELECT id, user_id, title, summary, extraction_mode,
		        last_score, created_at, updated_at
		 FROM quizzes WHERE id = $1 AND user_id = $2`,
		quizID, userID,
	).Scan(&quiz.ID, &quiz.UserID, &quiz.Title, &quiz.Summary,
		&quiz.ExtractionMode, &quiz.LastScore, &quiz.CreatedAt, &quiz.UpdatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"message": "Rangkuman tidak ditemukan"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Gagal mengambil rangkuman"})
		return
	}
	if strings.TrimSpace(quiz.Summary) == "" {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"message": "Rangkuman kosong, tidak bisa membuat quiz"})
		return
	}

	if err := services.ValidateGroqConnection(); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": fmt.Sprintf("API AI tidak tersedia: %v", err)})
		return
	}

	questionsRaw, err := services.GenerateQuestionsWithGroq(quiz.Title, quiz.Summary, body.NumQuestions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": fmt.Sprintf("Gagal membuat quiz: %v", err)})
		return
	}

	_, _ = database.DB.Exec("DELETE FROM questions WHERE quiz_id = $1", quizID)

	questions := make([]models.Question, 0, len(questionsRaw))
	for _, q := range questionsRaw {
		optJSON, _ := json.Marshal(q.Options)
		var qID uint64
		err := database.DB.QueryRow(
			"INSERT INTO questions (quiz_id, question, options, correct_answer) VALUES ($1, $2, $3, $4) RETURNING id",
			quizID, q.Question, string(optJSON), q.Answer,
		).Scan(&qID)
		if err != nil {
			continue
		}
		questions = append(questions, models.Question{
			ID:            qID,
			QuizID:        quizID,
			Question:      q.Question,
			Options:       q.Options,
			CorrectAnswer: q.Answer,
		})
	}

	quiz.Questions = questions
	config.Cache.Delete(config.QuizCacheKey(quizID))
	config.Cache.Delete(config.HistoryCacheKey(userID))

	c.JSON(http.StatusOK, gin.H{
		"message": "Quiz berhasil dibuat dari rangkuman",
		"quiz":    quiz,
	})
}
