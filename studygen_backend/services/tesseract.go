package services

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// ExtractTextWithTesseract mengkonversi PDF ke gambar lalu OCR dengan Tesseract
// Install: sudo apt install tesseract-ocr tesseract-ocr-ind ghostscript
func ExtractTextWithTesseract(filePath string) (string, error) {
	// Buat temp dir
	tmpDir, err := os.MkdirTemp("", "studygen-ocr-*")
	if err != nil {
		return "", fmt.Errorf("gagal buat temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Konversi PDF ke gambar per halaman dengan Ghostscript
	imgPattern := filepath.Join(tmpDir, "page%03d.png")
	gsCmd := exec.Command("gs",
		"-dNOPAUSE", "-dBATCH",
		"-sDEVICE=png16m",
		"-r200",
		"-dFirstPage=1", "-dLastPage=10", // max 10 halaman
		fmt.Sprintf("-sOutputFile=%s", imgPattern),
		filePath,
	)
	var gsErr bytes.Buffer
	gsCmd.Stderr = &gsErr
	if err := gsCmd.Run(); err != nil {
		return "", fmt.Errorf("ghostscript error: %v — %s", err, gsErr.String())
	}

	// Ambil semua file gambar
	images, err := filepath.Glob(filepath.Join(tmpDir, "page*.png"))
	if err != nil || len(images) == 0 {
		return "", fmt.Errorf("tidak ada halaman yang dikonversi")
	}
	sort.Strings(images)

	// OCR tiap halaman
	var allText strings.Builder
	for _, imgPath := range images {
		outBase := imgPath[:len(imgPath)-4] // hapus .png

		tCmd := exec.Command("tesseract",
			imgPath,
			outBase,
			"-l", "ind+eng",
			"--psm", "3",
		)
		var tErr bytes.Buffer
		tCmd.Stderr = &tErr
		if err := tCmd.Run(); err != nil {
			continue // skip halaman yang gagal
		}

		// Baca hasil OCR
		txtPath := outBase + ".txt"
		content, err := os.ReadFile(txtPath)
		if err != nil {
			continue
		}
		allText.WriteString(string(content))
		allText.WriteString("\n\n")
	}

	if allText.Len() == 0 {
		return "", fmt.Errorf("tesseract tidak menghasilkan teks")
	}

	return cleanText(allText.String()), nil
}
