/*
 * [INPUT]: Depends on an optional IANA time zone and non-overlapping daily blocked execution windows.
 * [OUTPUT]: Provides deterministic translation admission and next-allowed delay calculations.
 * [POS]: Serves as the provider-cost scheduling policy shared by translation dispatchers and item workers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"
)

type dailyWindow struct {
	startMinute int
	endMinute   int
	source      string
}

type ExecutionSchedule struct {
	location *time.Location
	blocked  []dailyWindow
}

func NewExecutionSchedule(timeZone string, blockedWindows []string) (*ExecutionSchedule, error) {
	if strings.TrimSpace(timeZone) == "" {
		timeZone = "UTC"
	}
	location, err := time.LoadLocation(timeZone)
	if err != nil {
		return nil, fmt.Errorf("load translation time zone %q: %w", timeZone, err)
	}
	blocked := make([]dailyWindow, 0, len(blockedWindows))
	for _, value := range blockedWindows {
		windows, err := parseDailyWindow(value)
		if err != nil {
			return nil, err
		}
		blocked = append(blocked, windows...)
	}
	sort.Slice(blocked, func(i, j int) bool { return blocked[i].startMinute < blocked[j].startMinute })
	for index := 1; index < len(blocked); index++ {
		if blocked[index].startMinute < blocked[index-1].endMinute {
			return nil, fmt.Errorf("translation blocked windows %q and %q overlap", blocked[index-1].source, blocked[index].source)
		}
	}
	return &ExecutionSchedule{location: location, blocked: blocked}, nil
}

func (s *ExecutionSchedule) Delay(now time.Time) time.Duration {
	if s == nil || len(s.blocked) == 0 {
		return 0
	}
	local := now.In(s.location)
	minute := local.Hour()*60 + local.Minute()
	for _, window := range s.blocked {
		if minute < window.startMinute || minute >= window.endMinute {
			continue
		}
		end := time.Date(local.Year(), local.Month(), local.Day(), window.endMinute/60, window.endMinute%60, 0, 0, s.location)
		if window.endMinute == 24*60 {
			end = time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, s.location).AddDate(0, 0, 1)
			for _, continuation := range s.blocked {
				if continuation.source == window.source && continuation.startMinute == 0 {
					end = time.Date(end.Year(), end.Month(), end.Day(), continuation.endMinute/60, continuation.endMinute%60, 0, 0, s.location)
					break
				}
			}
		}
		return end.Sub(now)
	}
	return 0
}

func parseDailyWindow(value string) ([]dailyWindow, error) {
	start, end, ok := strings.Cut(strings.TrimSpace(value), "-")
	if !ok {
		return nil, fmt.Errorf("translation blocked window %q must use HH:MM-HH:MM", value)
	}
	startMinute, err := parseClock(start, false)
	if err != nil {
		return nil, fmt.Errorf("translation blocked window %q: %w", value, err)
	}
	endMinute, err := parseClock(end, true)
	if err != nil {
		return nil, fmt.Errorf("translation blocked window %q: %w", value, err)
	}
	if endMinute == startMinute {
		return nil, fmt.Errorf("translation blocked window %q must not be empty", value)
	}
	if endMinute > startMinute {
		return []dailyWindow{{startMinute: startMinute, endMinute: endMinute, source: value}}, nil
	}
	return []dailyWindow{
		{startMinute: 0, endMinute: endMinute, source: value},
		{startMinute: startMinute, endMinute: 24 * 60, source: value},
	}, nil
}

func parseClock(value string, allowEndOfDay bool) (int, error) {
	value = strings.TrimSpace(value)
	if len(value) != 5 || value[2] != ':' {
		return 0, fmt.Errorf("time %q must use HH:MM", value)
	}
	hourText, minuteText := value[:2], value[3:]
	hour, hourErr := strconv.Atoi(hourText)
	minute, minuteErr := strconv.Atoi(minuteText)
	if allowEndOfDay && hour == 24 && minute == 0 {
		return 24 * 60, nil
	}
	if hourErr != nil || minuteErr != nil || hour < 0 || hour > 23 || minute < 0 || minute > 59 {
		return 0, fmt.Errorf("time %q is invalid", value)
	}
	return hour*60 + minute, nil
}
