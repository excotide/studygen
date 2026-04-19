package router

import (
	"studygen-backend/handlers"
	"studygen-backend/middleware"

	"github.com/gin-gonic/gin"
)

func Setup(r *gin.Engine) {
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(corsMiddleware())
	r.MaxMultipartMemory = 20 << 20

	api := r.Group("/api")

	// Quiz
	quiz := api.Group("/quiz")
	quiz.Use(middleware.AuthRequired())
	{
		quiz.POST("/generate",
			middleware.RateLimitGenerate(),
			handlers.Generate)
		quiz.POST("/:id/generate-quiz",
			middleware.RateLimitGenerate(),
			handlers.GenerateQuizFromSummary)
		quiz.GET("/history", handlers.GetHistory)
		quiz.GET("/:id", handlers.GetQuizByID)
		quiz.DELETE("/:id", handlers.DeleteQuiz)
		quiz.PATCH("/:id/score", handlers.UpdateScore)
	}
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods",
			"GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers",
			"Origin, Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}
