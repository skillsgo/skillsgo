/*
 * [INPUT]: Depends on IANA time zones, daily blocked-window configuration, and instants around window boundaries.
 * [OUTPUT]: Specifies always-on defaults and exact next-low-price execution times for translation work.
 * [POS]: Serves as deterministic coverage for the translation execution schedule.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package translation

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestExecutionScheduleAllowsWorkOutsideBlockedWindows(t *testing.T) {
	schedule, err := NewExecutionSchedule("Asia/Shanghai", []string{"09:00-12:00", "14:00-18:00"})
	require.NoError(t, err)

	now := time.Date(2026, time.July, 31, 13, 30, 0, 0, time.FixedZone("test", 8*60*60))
	require.Zero(t, schedule.Delay(now))
}

func TestExecutionScheduleDelaysUntilCurrentBlockedWindowEnds(t *testing.T) {
	schedule, err := NewExecutionSchedule("Asia/Shanghai", []string{"09:00-12:00", "14:00-18:00"})
	require.NoError(t, err)

	tests := []struct {
		name string
		now  time.Time
		want time.Duration
	}{
		{"morning peak starts inclusively", time.Date(2026, time.July, 31, 9, 0, 0, 0, time.UTC), 3 * time.Hour},
		{"morning peak", time.Date(2026, time.July, 31, 11, 30, 0, 0, time.UTC), 30 * time.Minute},
		{"afternoon peak", time.Date(2026, time.July, 31, 17, 0, 0, 0, time.UTC), time.Hour},
		{"peak end is allowed", time.Date(2026, time.July, 31, 18, 0, 0, 0, time.UTC), 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			local := time.Date(tt.now.Year(), tt.now.Month(), tt.now.Day(), tt.now.Hour(), tt.now.Minute(), 0, 0, time.FixedZone("test", 8*60*60))
			require.Equal(t, tt.want, schedule.Delay(local))
		})
	}
}

func TestExecutionScheduleRejectsInvalidOrOverlappingWindows(t *testing.T) {
	_, err := NewExecutionSchedule("missing/timezone", []string{"09:00-12:00"})
	require.ErrorContains(t, err, "time zone")
	_, err = NewExecutionSchedule("Asia/Shanghai", []string{"9:00-12:00"})
	require.ErrorContains(t, err, "HH:MM")
	_, err = NewExecutionSchedule("Asia/Shanghai", []string{"09:00-12:00", "11:00-14:00"})
	require.ErrorContains(t, err, "overlap")
}

func TestExecutionScheduleSupportsEndOfDayAndOvernightWindows(t *testing.T) {
	endOfDay, err := NewExecutionSchedule("UTC", []string{"08:30-24:00"})
	require.NoError(t, err)
	require.Equal(t, time.Second, endOfDay.Delay(time.Date(2026, time.July, 31, 23, 59, 59, 0, time.UTC)))
	require.Zero(t, endOfDay.Delay(time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC)))

	overnight, err := NewExecutionSchedule("UTC", []string{"22:00-02:00"})
	require.NoError(t, err)
	require.Equal(t, 3*time.Hour, overnight.Delay(time.Date(2026, time.July, 31, 23, 0, 0, 0, time.UTC)))
	require.Equal(t, time.Hour, overnight.Delay(time.Date(2026, time.August, 1, 1, 0, 0, 0, time.UTC)))
	require.Zero(t, overnight.Delay(time.Date(2026, time.August, 1, 2, 0, 0, 0, time.UTC)))
}

func TestExecutionScheduleDefaultsToAlwaysAllowed(t *testing.T) {
	schedule, err := NewExecutionSchedule("", nil)
	require.NoError(t, err)
	require.Zero(t, schedule.Delay(time.Now()))
}
