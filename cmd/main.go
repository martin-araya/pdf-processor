package main

import (
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres" // Driver Postgres (reemplaza sqlite)
	"gorm.io/gorm"
)

// Config
const (
	Port          = ":9001"
	TokenDuration = 24 * time.Hour // 1 day
)

var jwtSecret = os.Getenv("JWT_SECRET")
var db *gorm.DB

func init() {
	if jwtSecret == "" {
		jwtSecret = "tu-super-secreto-jwt-key-cambia-en-prod" // Fallback; set JWT_SECRET env
		log.Println("Warning: Using default JWT secret. Set JWT_SECRET env var in prod.")
	}
}

// User model (GORM: ID uint PK, email unique)
type User struct {
	ID       uint   `gorm:"primaryKey" json:"user_id"`
	Email    string `gorm:"unique;not null" json:"email"`
	Password string `json:"-"` // Hash only
}

// Claims
type Claims struct {
	UserID uint `json:"user_id"`
	jwt.RegisteredClaims
}

// Login handler
func login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user User
	if err := db.Where("email = ?", req.Email).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Generate JWT
	expirationTime := time.Now().Add(TokenDuration)
	claims := &Claims{
		UserID: user.ID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(jwtSecret))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Token generation failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token":   tokenString,
		"user_id": user.ID,
	})
}

// Register handler
func register(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if exists
	var existing User
	if err := db.Where("email = ?", req.Email).First(&existing).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "User already exists"})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Password hashing failed"})
		return
	}

	user := User{
		Email:    req.Email,
		Password: string(hashedPassword),
	}
	if err := db.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"user_id": user.ID,
		"email":   user.Email,
	})
}

// Validate token handler
func validate(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		log.Println("Validate: Missing Authorization header")
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Authorization header required"})
		return
	}

	bearerToken := strings.Split(authHeader, " ")
	if len(bearerToken) != 2 || bearerToken[0] != "Bearer" {
		log.Println("Validate: Invalid Authorization format")
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Invalid token format (use Bearer <token>)"})
		return
	}

	tokenString := bearerToken[1]
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(jwtSecret), nil
	})
	if err != nil || !token.Valid {
		log.Printf("Validate: Token invalid: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"valid": false, "error": "Invalid or expired token"})
		return
	}

	log.Printf("Validate: Token valid for user_id: %d", claims.UserID)
	c.JSON(http.StatusOK, gin.H{
		"valid":   true,
		"user_id": claims.UserID,
	})
}

func main() {
	// DB connection (Postgres via env; fallback si no)
	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		// Default para Docker: host=localhost (desde host), user/pass/db default
		dsn = "host=localhost user=postgres password=postgres dbname=auth_db port=5433 sslmode=disable TimeZone=UTC"
		log.Println("Using default DB_URL. Set DB_URL env for custom (e.g., for prod).")
	}

	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Postgres connection failed:", err)
	}

	// AutoMigrate: Crea tabla users si no existe
	if err := db.AutoMigrate(&User{}); err != nil {
		log.Fatal("Migration failed:", err)
	}

	// Demo user si DB vacía (primera run)
	var count int64
	db.Model(&User{}).Where("email = ?", "test@example.com").Count(&count)
	if count == 0 {
		hashed, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
		db.Create(&User{Email: "test@example.com", Password: string(hashed)})
		log.Println("Demo user created: test@example.com / password123")
	}

	r := gin.Default()

	// CORS (agrega emulator IP para Android)
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:8080", "http://localhost:3000", "http://10.0.2.2:8080"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// Routes
	auth := r.Group("/api/auth")
	{
		auth.POST("/login", login)
		auth.POST("/register", register)
		auth.GET("/validate", validate)
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "Auth service running on " + Port})
	})

	log.Println("Starting auth service on", Port, "connected to Postgres")
	r.Run(Port)
}
