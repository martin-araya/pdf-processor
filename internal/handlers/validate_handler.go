package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

// ValidateHandler: Dedicated handler for JWT validation (no DB/AuthSvc needed).
type ValidateHandler struct{}

func NewValidateHandler() *ValidateHandler {
	return &ValidateHandler{}
}

// Validate JWT token from middleware context (requires JWTMiddleware first).
func (h *ValidateHandler) Validate(c *gin.Context) {
	userID, exists := c.Get("user_id") // Set by jwt_middleware
	if !exists {
		log.Println("Validate: No user_id in context (no JWT or invalid)")
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Invalid token"})
		return
	}

	// Type assertion: Assume uint from claims.UserID; adjust to int if models.User.ID is int
	userIDInt, ok := userID.(uint)
	if !ok {
		log.Println("Validate: user_id type error (expected uint)")
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Invalid user ID type"})
		return
	}

	log.Printf("Validate: Token valid for user_id: %d", userIDInt)
	c.JSON(http.StatusOK, gin.H{"valid": true, "user_id": userIDInt})
}
