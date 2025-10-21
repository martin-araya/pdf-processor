package handlers

import (
	"auth-service/internal/models"
	"auth-service/internal/services"
	"errors" // Para errors.Is con GORM
	"log"    // Para debug logs en Validate (quita en prod)
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AuthHandler struct {
	db      *gorm.DB
	authSvc *services.AuthService
}

func NewAuthHandler(db *gorm.DB, authSvc *services.AuthService) *AuthHandler {
	return &AuthHandler{db: db, authSvc: authSvc}
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := h.db.Where("email = ?", req.Email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		}
		return
	}

	if !h.authSvc.CheckPassword(user.Password, req.Password) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	token, err := h.authSvc.GenerateToken(&user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Token generation failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token, "user_id": user.ID})
}

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Chequea si user existe
	var existingUser models.User
	if err := h.db.Where("email = ?", req.Email).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "User already exists"})
		return
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		// Si error no es "not found", es DB issue
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database query error"})
		return
	}

	hashed, err := h.authSvc.HashPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Password hashing failed"})
		return
	}

	user := models.User{Email: req.Email, Password: hashed}
	if err := h.db.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"user_id": user.ID, "email": user.Email})
}

// Validate JWT token from middleware context.
func (h *AuthHandler) Validate(c *gin.Context) {
	userID, exists := c.Get("user_id") // Set by jwt_middleware
	if !exists {
		log.Println("Validate: No user_id in context (no JWT or invalid)")
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Invalid token"})
		return
	}

	userIDInt, ok := userID.(uint) // Assumes User.ID is uint; adjust to int if needed
	if !ok {
		log.Println("Validate: user_id type error")
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Invalid user ID"})
		return
	}

	log.Printf("Validate: Token valid for user_id: %d", userIDInt)
	c.JSON(http.StatusOK, gin.H{"valid": true, "user_id": userIDInt})
}
