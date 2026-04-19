package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"studygen-backend/config"
	"time"
)

const mistralOCRURL = "https://api.mistral.ai/v1/ocr"

type mistralRequest struct {
	Model    string          `json:"model"`
	Document mistralDocument `json:"document"`
}

type mistralDocument struct {
	Type           string `json:"type"`
	DocumentURL    string `json:"document_url,omitempty"`
	DocumentBase64 string `json:"document_base64,omitempty"`
	DocumentName   string `json:"document_name,omitempty"`
}

type mistralResponse struct {
	Pages []struct {
		Markdown string `json:"markdown"`
	} `json:"pages"`
}

// ExtractTextWithMistral menggunakan Mistral OCR API
func ExtractTextWithMistral(filePath string) (string, error) {
	// Baca file dan encode ke base64
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("gagal baca file: %v", err)
	}
	b64 := base64.StdEncoding.EncodeToString(data)

	reqBody := mistralRequest{
		Model: "mistral-ocr-latest",
		Document: mistralDocument{
			Type:         "document_url",
			DocumentURL:  "data:application/pdf;base64," + b64,
			DocumentName: "materi.pdf",
		},
	}

	bodyBytes, _ := json.Marshal(reqBody)

	req, err := http.NewRequest("POST", mistralOCRURL, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+config.App.MistralAPIKey)

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("mistral request error: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("mistral API error %d: %s", resp.StatusCode, summarizeMistralError(body))
	}

	var mistralResp mistralResponse
	if err := json.NewDecoder(resp.Body).Decode(&mistralResp); err != nil {
		return "", fmt.Errorf("gagal decode response: %v", err)
	}

	// Gabungkan semua halaman
	var result bytes.Buffer
	for _, page := range mistralResp.Pages {
		result.WriteString(page.Markdown)
		result.WriteString("\n\n")
	}

	if result.Len() == 0 {
		return "", fmt.Errorf("mistral tidak menghasilkan teks")
	}

	return cleanText(result.String()), nil
}

func summarizeMistralError(body []byte) string {
	type detailItem struct {
		Msg string `json:"msg"`
	}
	type apiErr struct {
		Detail []detailItem `json:"detail"`
	}

	var parsed apiErr
	if err := json.Unmarshal(body, &parsed); err == nil && len(parsed.Detail) > 0 {
		msgs := make([]string, 0, len(parsed.Detail))
		for _, d := range parsed.Detail {
			m := strings.TrimSpace(d.Msg)
			if m != "" {
				msgs = append(msgs, m)
			}
		}
		if len(msgs) > 0 {
			return strings.Join(msgs, "; ")
		}
	}

	raw := strings.TrimSpace(string(body))
	if len(raw) > 280 {
		return raw[:280] + "..."
	}
	if raw == "" {
		return "response kosong"
	}
	return raw
}
