package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	AppPort         string
	AppEnv          string
	DatabaseURL     string
	DBHost          string
	DBPort          string
	DBUser          string
	DBPass          string
	DBName          string
	DBSSLMode       string
	JWTSecret       string
	SupabaseURL     string
	SupabaseAnonKey string
	GroqAPIKey      string
	MistralAPIKey   string
}

var App *Config

func Load() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, reading from environment")
	}

	App = &Config{
		AppPort:         getAppPort(),
		AppEnv:          getEnv("APP_ENV", "development"),
		DatabaseURL:     getEnv("DATABASE_URL", ""),
		DBHost:          getEnv("DB_HOST", "127.0.0.1"),
		DBPort:          getEnv("DB_PORT", "5432"),
		DBUser:          getEnv("DB_USER", "postgres"),
		DBPass:          getEnv("DB_PASS", ""),
		DBName:          getEnv("DB_NAME", "studygen"),
		DBSSLMode:       getEnv("DB_SSLMODE", "disable"),
		JWTSecret:       getEnv("JWT_SECRET", "secret"),
		SupabaseURL:     getEnv("SUPABASE_URL", ""),
		SupabaseAnonKey: getEnv("SUPABASE_ANON_KEY", ""),
		GroqAPIKey:      getEnv("GROQ_API_KEY", ""),
		MistralAPIKey:   getEnv("MISTRAL_API_KEY", ""),
	}
}

func getAppPort() string {
	if val := os.Getenv("APP_PORT"); val != "" {
		return val
	}
	if val := os.Getenv("PORT"); val != "" {
		return val
	}
	return "8000"
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
