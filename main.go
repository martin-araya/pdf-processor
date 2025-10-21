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
	"gorm.io/driver/postgres"
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

// Login handler (POST /auth/login)
func login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("Login: Invalid JSON: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos (verifica formato)"})
		return
	}

	var user User
	if err := db.Where("email = ?", req.Email).First(&user).Error; err != nil {
		log.Printf("Login: User not found: %s", req.Email)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuario o contraseña inválidos"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		log.Printf("Login: Invalid password for: %s", req.Email)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuario o contraseña inválidos"})
		return
	}

	// Generate JWT
	token, err := generateToken(user.ID, user.Email)
	if err != nil {
		log.Printf("Login: Token gen failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error en servidor auth. Intenta más tarde"})
		return
	}

	log.Printf("✅ Login success for: %s (user_id: %d)", user.Email, user.ID)
	c.JSON(http.StatusOK, gin.H{
		"token":    token,
		"user_id":  user.ID,
		"username": user.Email, // Fix: Map email to username para Flutter
	})
}

// Register handler (POST /auth/register; genera token post-create)
func register(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("Register: Invalid JSON: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos (password mínimo 6 caracteres)"})
		return
	}

	// Check if exists
	var existing User
	if err := db.Where("email = ?", req.Email).First(&existing).Error; err == nil {
		log.Printf("Register: User exists: %s", req.Email)
		c.JSON(http.StatusConflict, gin.H{"error": "Usuario ya existe"})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Register: Hash failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error en servidor auth. Intenta más tarde"})
		return
	}

	user := User{
		Email:    req.Email,
		Password: string(hashedPassword),
	}
	if err := db.Create(&user).Error; err != nil {
		log.Printf("Register: Create failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error en servidor auth. Intenta más tarde"})
		return
	}

	// Fix: Generate token post-register (para auto-login en Flutter)
	token, err := generateToken(user.ID, user.Email)
	if err != nil {
		log.Printf("Register: Token gen failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error generando token"})
		return
	}

	log.Printf("✅ Register success for: %s (user_id: %d)", user.Email, user.ID)
	c.JSON(http.StatusCreated, gin.H{
		"user_id":  user.ID,
		"username": user.Email, // Fix: username = email
		"token":    token,      // Fix: Agrega token
	})
}

// Validate token handler (GET /auth/validate)
func validate(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		log.Println("Validate: Missing Authorization header")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas", "valid": false})
		return
	}

	bearerToken := strings.Split(authHeader, " ")
	if len(bearerToken) != 2 || bearerToken[0] != "Bearer" {
		log.Println("Validate: Invalid Authorization format")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas", "valid": false})
		return
	}

	tokenString := bearerToken[1]
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(jwtSecret), nil
	})
	if err != nil || !token.Valid {
		log.Printf("Validate: Token invalid: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sesión expirada.", "valid": false})
		return
	}

	// Fetch user para username
	var user User
	if err := db.First(&user, claims.UserID).Error; err != nil {
		log.Printf("Validate: User fetch failed for id %d: %v", claims.UserID, err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas", "valid": false})
		return
	}

	log.Printf("✅ Validate: Token valid for user_id: %d (%s)", claims.UserID, user.Email)
	c.JSON(http.StatusOK, gin.H{
		"valid":    true,
		"user_id":  claims.UserID,
		"username": user.Email, // Fix: Agrega username para Flutter
	})
}

// Refresh handler (POST /auth/refresh)
func refresh(c *gin.Context) {
	var req struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("Refresh: Invalid JSON: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos"})
		return
	}

	claims := &Claims{}
	token, err := jwt.ParseWithClaims(req.Token, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(jwtSecret), nil
	})
	if err != nil || !token.Valid {
		log.Printf("Refresh: Invalid token: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Token inválido o expirado"})
		return
	}

	if time.Until(claims.RegisteredClaims.ExpiresAt.Time) < 0 {
		log.Println("Refresh: Token expired")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sesión expirada."})
		return
	}

	// Fetch user
	var user User
	if err := db.First(&user, claims.UserID).Error; err != nil {
		log.Printf("Refresh: User fetch failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error en servidor auth."})
		return
	}

	newToken, err := generateToken(claims.UserID, user.Email)
	if err != nil {
		log.Printf("Refresh: New token failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo renovar token"})
		return
	}

	log.Printf("🔄 Refresh success for user_id: %d (%s)", claims.UserID, user.Email)
	c.JSON(http.StatusOK, gin.H{
		"token":    newToken,
		"username": user.Email,
	})
}

// Helper: Generate JWT
func generateToken(userID uint, username string) (string, error) {
	expirationTime := time.Now().Add(TokenDuration)
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(jwtSecret))
}

func main() {
	// DB connection
	dsn := os.Getenv("DB_URL")
	if dsn == "" {
		dsn = "host=localhost user=postgres password=postgres dbname=auth_db port=5433 sslmode=disable TimeZone=UTC"
		log.Println("Using default DB_URL. Set DB_URL env for custom.")
	}

	var err error
	db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("Postgres connection failed:", err)
	}

	// AutoMigrate
	if err := db.AutoMigrate(&User{}); err != nil {
		log.Fatal("Migration failed:", err)
	}

	// Demo user si no existe
	var count int64
	db.Model(&User{}).Where("email = ?", "test@example.com").Count(&count)
	if count == 0 {
		hashed, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
		db.Create(&User{Email: "test@example.com", Password: string(hashed)})
		log.Println("Demo user created: test@example.com / password123")
	}

	r := gin.Default()

	// CORS (Flutter web/emulator/desktop)
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*", "http://localhost:*", "http://10.0.2.2:*"}, // * para dev; restrict prod
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// Routes: /auth/... (Fix: Sin /api para match Flutter; si quieres /api, cambia Flutter a '/api/auth/...')
	auth := r.Group("/auth")
	{
		auth.POST("/login", login)
		auth.POST("/register", register)
		auth.GET("/validate", validate)
		auth.POST("/refresh", refresh) // Fix: Agrega refresh
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "Auth service running on " + Port})
	})

	log.Println("Starting auth service on", Port, "connected to Postgres")
	r.Run(Port)
}
