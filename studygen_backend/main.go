package main

import (
	"log"
	"studygen-backend/config"
	"studygen-backend/database"
	"studygen-backend/middleware"
	"studygen-backend/router"

	"github.com/gin-gonic/gin"
)

func main() {
	config.Load()
	config.InitCache()
	middleware.InitRateLimiters()

	database.Connect()
	database.Migrate()

	if config.App.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()
	router.Setup(r)

	port := ":" + config.App.AppPort
	log.Printf("🚀 StudyGen backend running on %s", port)

	if err := r.Run(port); err != nil {
		log.Fatalf("Failed to start: %v", err)
	}
}
