package services

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// ExtractTextWithPdftotext menggunakan pdftotext (poppler-utils) untuk PDF digital
// Install: sudo apt install poppler-utils
func ExtractTextWithPdftotext(filePath string) (string, error) {
	cmd := exec.Command("pdftotext", "-layout", filePath, "-")
	var out, stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("pdftotext error: %v — %s", err, stderr.String())
	}

	text := cleanText(out.String())
	return text, nil
}

func cleanText(text string) string {
	// Hapus baris kosong berlebih
	lines := strings.Split(text, "\n")
	var cleaned []string
	emptyCount := 0

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			emptyCount++
			if emptyCount <= 1 {
				cleaned = append(cleaned, "")
			}
		} else {
			emptyCount = 0
			cleaned = append(cleaned, trimmed)
		}
	}

	result := strings.Join(cleaned, "\n")

	// Batasi 12000 karakter agar tidak overflow Groq context
	if len(result) > 12000 {
		result = result[:12000] + "..."
	}

	return strings.TrimSpace(result)
}
