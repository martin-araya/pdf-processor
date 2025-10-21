package middleware

import (
	"auth-service/internal/services"
	"log" // Para debug logs
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func JWTMiddleware(authSvc *services.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			log.Println("JWT: Missing Authorization header")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		bearerToken := strings.Split(authHeader, " ")
		if len(bearerToken) != 2 || bearerToken[0] != "Bearer" {
			log.Println("JWT: Invalid Authorization format")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid Authorization format (use Bearer <token>)"})
			c.Abort()
			return
		}

		tokenStr := bearerToken[1]
		if len(tokenStr) < 10 { // Basic check: token muy corto?
			log.Printf("JWT: Token too short: %s", tokenStr[:10])
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token (too short)"})
			c.Abort()
			return
		}

		claims, err := authSvc.ValidateToken(tokenStr)
		if err != nil {
			log.Printf("JWT: Validation failed: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token: " + err.Error()})
			c.Abort()
			return
		}

		userID, ok := claims.UserID.(uint) // Asume uint en models.User; ajusta si int
		if !ok {
			log.Println("JWT: Invalid user_id type in claims")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user claims"})
			c.Abort()
			return
		}

		c.Set("user_id", userID)
		log.Printf("JWT: Valid token for user_id: %d", userID)
		c.Next()
	}
}
