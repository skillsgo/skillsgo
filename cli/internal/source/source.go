package source

import (
	"fmt"
	"net/url"
	"strings"
)

type Reference struct {
	Coordinate string
	Version    string
}

func Parse(raw string) (Reference, error) {
	raw = strings.TrimSpace(raw)
	if strings.HasPrefix(raw, "https://github.com/") || strings.HasPrefix(raw, "http://github.com/") {
		parsed, err := url.Parse(raw)
		if err != nil {
			return Reference{}, err
		}
		parts := splitPath(parsed.Path)
		if len(parts) < 2 {
			return Reference{}, fmt.Errorf("GitHub URL 缺少 owner/repo")
		}
		coordinate := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
		version := "main"
		if len(parts) > 2 {
			if len(parts) < 4 || parts[2] != "tree" {
				return Reference{}, fmt.Errorf("暂不支持 GitHub URL 路径 %q", parsed.Path)
			}
			version = parts[3]
			if len(parts) > 4 {
				coordinate += "/-/" + strings.Join(parts[4:], "/")
			}
		}
		return Reference{Coordinate: coordinate, Version: version}, nil
	}

	parts := splitPath(raw)
	if len(parts) >= 2 && parts[0] != "github.com" {
		coordinate := "github.com/" + parts[0] + "/" + strings.TrimSuffix(parts[1], ".git")
		if len(parts) > 2 {
			coordinate += "/-/" + strings.Join(parts[2:], "/")
		}
		return Reference{Coordinate: coordinate, Version: "main"}, nil
	}
	if len(parts) < 3 || parts[0] != "github.com" {
		return Reference{}, fmt.Errorf("首版 source 必须是 github.com/owner/repo 坐标或 GitHub tree URL")
	}
	return Reference{Coordinate: strings.Join(parts, "/"), Version: "main"}, nil
}

func splitPath(value string) []string {
	raw := strings.Split(strings.Trim(value, "/"), "/")
	parts := make([]string, 0, len(raw))
	for _, part := range raw {
		if part != "" {
			parts = append(parts, part)
		}
	}
	return parts
}
