package middleware

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/ulule/limiter/v3"
	"github.com/ulule/limiter/v3/drivers/store/memory"
)

var (
	generateLimiter *limiter.Limiter
	loginLimiter    *limiter.Limiter
)

func InitRateLimiters() {
	// /quiz/generate: max 10x per jam per IP
	generateRate, _ := limiter.NewRateFromFormatted("10-H")
	generateLimiter = limiter.New(memory.NewStore(), generateRate)

	// /auth/login: max 10x per menit per IP
	loginRate, _ := limiter.NewRateFromFormatted("10-M")
	loginLimiter = limiter.New(memory.NewStore(), loginRate)
}

func RateLimitGenerate() gin.HandlerFunc {
	return applyLimit(generateLimiter,
		"Terlalu banyak request generate. Coba lagi dalam 1 jam.")
}

func RateLimitLogin() gin.HandlerFunc {
	return applyLimit(loginLimiter,
		"Terlalu banyak percobaan login. Coba lagi dalam 1 menit.")
}

func applyLimit(l *limiter.Limiter, msg string) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, err := l.Get(c.Request.Context(), c.ClientIP())
		if err != nil {
			c.Next()
			return
		}

		c.Header("X-RateLimit-Limit",
			fmt.Sprintf("%d", ctx.Limit))
		c.Header("X-RateLimit-Remaining",
			fmt.Sprintf("%d", ctx.Remaining))
		c.Header("X-RateLimit-Reset",
			fmt.Sprintf("%d", ctx.Reset))

		if ctx.Reached {
			retryAfter := time.Until(time.Unix(ctx.Reset, 0)).Seconds()
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"message":     msg,
				"retry_after": retryAfter,
			})
			return
		}
		c.Next()
	}
}
