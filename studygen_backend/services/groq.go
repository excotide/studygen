package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"studygen-backend/config"
	"time"
)

const groqURL = "https://api.groq.com/openai/v1/chat/completions"

type GroqRequest struct {
	Model       string        `json:"model"`
	Temperature float64       `json:"temperature"`
	MaxTokens   int           `json:"max_tokens"`
	Messages    []GroqMessage `json:"messages"`
}

type GroqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type GroqResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

type SummaryResult struct {
	Title   string `json:"title"`
	Summary string `json:"summary"`
}

type QuizQuestion struct {
	Question string   `json:"question"`
	Options  []string `json:"options"`
	Answer   int      `json:"answer"`
}

var lengthMap = map[string]string{
	"short":  "3-4 paragraf singkat",
	"medium": "5-7 paragraf",
	"long":   "8-10 paragraf mendalam",
}

func GenerateSummaryWithGroq(pdfText string, summaryLength string) (*SummaryResult, error) {
	length := lengthMap[summaryLength]
	if length == "" {
		length = lengthMap["medium"]
	}

	prompt := fmt.Sprintf(`Kamu adalah asisten pendidikan. Analisis teks materi kuliah berikut.
Kembalikan HANYA JSON valid, tanpa markdown, tanpa penjelasan lain.

Format JSON:
{
  "title": "Judul materi (singkat, max 60 karakter)",
  "summary": "Rangkuman materi dalam %s, bahasa Indonesia yang jelas"
}

Ketentuan:
- Fokus utama adalah rangkuman yang runtut dan mudah dipahami
- Jangan sertakan pertanyaan atau opsi quiz

Teks materi:
%s`, length, pdfText)

	rawJSON, err := requestGroqJSON(prompt, 0.3, 3000)
	if err != nil {
		return nil, err
	}

	var result SummaryResult
	if err := json.Unmarshal([]byte(rawJSON), &result); err != nil {
		return nil, fmt.Errorf("gagal parse JSON rangkuman: %v\nRaw: %s", err, rawJSON)
	}
	if result.Title == "" {
		result.Title = "Rangkuman Materi"
	}
	if result.Summary == "" {
		return nil, fmt.Errorf("rangkuman kosong dari model")
	}

	return &result, nil
}

func GenerateQuestionsWithGroq(title, summary string, numQuestions int) ([]QuizQuestion, error) {
	if numQuestions <= 0 {
		numQuestions = 10
	}

	prompt := fmt.Sprintf(`Kamu adalah asisten pendidikan.
Berdasarkan rangkuman materi berikut, buatkan quiz pilihan ganda.
Kembalikan HANYA JSON valid, tanpa markdown, tanpa teks lain.

Format JSON:
{
  "questions": [
    {
      "question": "Pertanyaan pilihan ganda?",
      "options": ["Pilihan A", "Pilihan B", "Pilihan C", "Pilihan D"],
      "answer": 0
    }
  ]
}

Ketentuan:
- Buat tepat %d soal pilihan ganda
- Field "answer" adalah index 0-3 dari options yang benar
- Variasikan tingkat kesulitan: mudah, sedang, sulit
- Pastikan hanya satu jawaban benar per soal

Judul materi:
%s

Rangkuman:
%s`, numQuestions, title, summary)

	rawJSON, err := requestGroqJSON(prompt, 0.4, 3000)
	if err != nil {
		return nil, err
	}

	var payload struct {
		Questions []QuizQuestion `json:"questions"`
	}
	if err := json.Unmarshal([]byte(rawJSON), &payload); err != nil {
		return nil, fmt.Errorf("gagal parse JSON quiz: %v\nRaw: %s", err, rawJSON)
	}
	if len(payload.Questions) == 0 {
		return nil, fmt.Errorf("pertanyaan quiz kosong dari model")
	}

	return payload.Questions, nil
}

func requestGroqJSON(prompt string, temperature float64, maxTokens int) (string, error) {
	reqBody := GroqRequest{
		Model:       "llama-3.3-70b-versatile",
		Temperature: temperature,
		MaxTokens:   maxTokens,
		Messages: []GroqMessage{
			{
				Role:    "system",
				Content: "Kamu hanya membalas dalam format JSON valid. Jangan tambahkan teks apapun di luar JSON.",
			},
			{
				Role:    "user",
				Content: prompt,
			},
		},
	}

	bodyBytes, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", groqURL, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+config.App.GroqAPIKey)

	client := &http.Client{Timeout: 90 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("groq request error: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("groq API error %d: %s", resp.StatusCode, string(body))
	}

	var groqResp GroqResponse
	if err := json.NewDecoder(resp.Body).Decode(&groqResp); err != nil {
		return "", fmt.Errorf("gagal decode groq response: %v", err)
	}
	if len(groqResp.Choices) == 0 {
		return "", fmt.Errorf("groq tidak menghasilkan response")
	}

	return cleanJSON(groqResp.Choices[0].Message.Content), nil
}

func cleanJSON(s string) string {
	s = bytes.NewBufferString(s).String()
	replacer := []string{"```json", "```", "`"}
	for _, r := range replacer {
		s = replaceAll(s, r, "")
	}
	return string(bytes.TrimSpace([]byte(s)))
}

func replaceAll(s, old, new string) string {
	result := bytes.ReplaceAll([]byte(s), []byte(old), []byte(new))
	return string(result)
}
