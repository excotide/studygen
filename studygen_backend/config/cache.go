package config

import (
	"fmt"
	"time"

	gocache "github.com/patrickmn/go-cache"
)

// Cache instance global
var Cache *gocache.Cache

func InitCache() {
	// Default TTL 5 menit, cleanup setiap 10 menit
	Cache = gocache.New(5*time.Minute, 10*time.Minute)
}

// Key helpers
func HistoryCacheKey(userID string) string {
	return fmt.Sprintf("history:%s", userID)
}

func QuizCacheKey(quizID uint64) string {
	return fmt.Sprintf("quiz:%d", quizID)
}
