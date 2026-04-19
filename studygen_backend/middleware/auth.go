package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"studygen-backend/config"
	"time"

	"github.com/gin-gonic/gin"
)

type supabaseUser struct {
	ID               string  `json:"id"`
	Email            string  `json:"email"`
	EmailConfirmedAt *string `json:"email_confirmed_at"`
}

var authHTTPClient = &http.Client{Timeout: 8 * time.Second}

func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		if config.App.SupabaseURL == "" || config.App.SupabaseAnonKey == "" {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{
				"message": "konfigurasi Supabase belum lengkap",
			})
			return
		}

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"message": "Token tidak ditemukan",
			})
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		user, err := fetchSupabaseUser(tokenStr)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"message": err.Error(),
			})
			return
		}

		if user.EmailConfirmedAt == nil || *user.EmailConfirmedAt == "" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"message": "email belum diverifikasi",
			})
			return
		}

		c.Set("user_id", user.ID)
		c.Set("email", user.Email)
		c.Next()
	}
}

func GetUserID(c *gin.Context) string {
	id, _ := c.Get("user_id")
	uid, _ := id.(string)
	return uid
}

func fetchSupabaseUser(accessToken string) (*supabaseUser, error) {
	url := strings.TrimRight(config.App.SupabaseURL, "/") + "/auth/v1/user"
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("gagal memverifikasi token")
	}

	req.Header.Set("apikey", config.App.SupabaseAnonKey)
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := authHTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("gagal menghubungi Supabase Auth")
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("token tidak valid atau expired")
	}

	var u supabaseUser
	if err := json.NewDecoder(resp.Body).Decode(&u); err != nil {
		return nil, fmt.Errorf("gagal membaca user Supabase")
	}

	if u.ID == "" {
		return nil, fmt.Errorf("user tidak ditemukan")
	}

	return &u, nil
}
