package middleware

import (
	"github.com/gofiber/fiber/v3"
	"net/http"
	"testing"
)

func TestCacheControl(t *testing.T) {
	expected := "private, no-store"
	app := fiber.New()
	app.Use(CacheControl(expected))
	app.Get("/test", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })
	r, _ := http.NewRequest("GET", "/test", nil)
	resp, err := app.Test(r)
	if err != nil {
		t.Fatal(err)
	}
	given := resp.Header.Get("Cache-Control")
	if given != expected {
		t.Fatalf("expected cache-control header to be %v but got %v", expected, given)
	}
}
