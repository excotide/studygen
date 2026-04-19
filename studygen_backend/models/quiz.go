package models

import "time"

type Quiz struct {
	ID             uint64     `json:"id"`
	UserID         string     `json:"user_id"`
	Title          string     `json:"title"`
	Summary        string     `json:"summary"`
	ExtractionMode string     `json:"extraction_mode"`
	LastScore      *int       `json:"last_score"`
	Questions      []Question `json:"questions"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type Question struct {
	ID            uint64    `json:"id"`
	QuizID        uint64    `json:"quiz_id"`
	Question      string    `json:"question"`
	Options       []string  `json:"options"`
	CorrectAnswer int       `json:"correct_answer"`
	CreatedAt     time.Time `json:"created_at"`
}
