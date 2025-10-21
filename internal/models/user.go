package models

import (
	"time"

	"gorm.io/gorm"
)

type User struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Email     string    `gorm:"uniqueIndex;size:255" json:"email"`
	Password  string    `gorm:"size:255" json:"-"` // No expose
	CreatedAt time.Time `json:"created_at"`
}

func (User) TableName() string {
	return "users"
}

func Migrate(db *gorm.DB) error {
	return db.AutoMigrate(&User{})
}
