package services

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"strings"
	"studygen-backend/config"
	"time"
)

var serviceHealthClient = &http.Client{Timeout: 8 * time.Second}

func ValidateGroqConnection() error {
	if strings.TrimSpace(config.App.GroqAPIKey) == "" {
		return errors.New("GROQ_API_KEY belum diatur")
	}

	req, err := http.NewRequest("GET", "https://api.groq.com/openai/v1/models", nil)
	if err != nil {
		return fmt.Errorf("gagal membuat request Groq: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+config.App.GroqAPIKey)

	resp, err := serviceHealthClient.Do(req)
	if err != nil {
		return fmt.Errorf("gagal menghubungi Groq: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
	return fmt.Errorf("Groq API tidak siap (%d): %s", resp.StatusCode, strings.TrimSpace(string(body)))
}

func ValidateMistralConnection() error {
	if strings.TrimSpace(config.App.MistralAPIKey) == "" {
		return errors.New("MISTRAL_API_KEY belum diatur")
	}

	req, err := http.NewRequest("GET", "https://api.mistral.ai/v1/models", nil)
	if err != nil {
		return fmt.Errorf("gagal membuat request Mistral: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+config.App.MistralAPIKey)

	resp, err := serviceHealthClient.Do(req)
	if err != nil {
		return fmt.Errorf("gagal menghubungi Mistral: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return nil
	}

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
	return fmt.Errorf("Mistral API tidak siap (%d): %s", resp.StatusCode, strings.TrimSpace(string(body)))
}

func ValidateOCRMode(extractionMode string) error {
	switch extractionMode {
	case "parser":
		return requireBinary("pdftotext")
	case "tesseract":
		if err := requireBinary("gs"); err != nil {
			return err
		}
		return requireBinary("tesseract")
	case "mistral":
		return ValidateMistralConnection()
	default:
		return fmt.Errorf("mode ekstraksi tidak valid: %s", extractionMode)
	}
}

func requireBinary(name string) error {
	if _, err := exec.LookPath(name); err != nil {
		return fmt.Errorf("dependensi OCR '%s' tidak tersedia di server", name)
	}
	return nil
}
