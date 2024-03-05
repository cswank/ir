package ir

import (
	"fmt"
	"time"
)

const (
	start1   = 9 * time.Millisecond
	start2   = 4500 * time.Microsecond
	bitStart = 562500 * time.Nanosecond
	bitOne   = 1687500 * time.Nanosecond

	PayloadSize = 67
)

var (
	Tolerance = 100 * time.Microsecond
)

func Command(times []time.Duration) (addr, cmd uint8, err error) {
	for i, d := range times {
		if len(times)-i >= PayloadSize && closeTo(d, start1) && closeTo(times[i+1], start2) && closeTo(times[i+66], bitStart) {
			return command(times[i+2:])
		}
	}

	return 0, 0, fmt.Errorf("unable to find a valid command: %+v", times)
}

func command(times []time.Duration) (uint8, uint8, error) {
	n, err := parse(times)
	if err != nil {
		return 0, 0, err
	}

	addr := uint8(n)
	iAddr := uint8(n >> 8)
	cmd := uint8(n >> 16)
	iCmd := uint8(n >> 24)

	if iAddr != addr^0xff {
		return 0, 0, fmt.Errorf("invalid address %d, inverse %d", addr, iAddr)
	}

	if iCmd != cmd^0xff {
		return 0, 0, fmt.Errorf("invalid command %d, inverse %d", cmd, iCmd)
	}

	return addr, cmd, nil
}

func parse(times []time.Duration) (val uint32, err error) {
	var d1, d2 time.Duration
	for i := 0; i < 64; i += 2 {
		d1, d2 = times[i], times[i+1]
		if !closeTo(d1, bitStart) {
			return 0, fmt.Errorf("invalid pulse %s (index %d), expected %s pulse", d1, i, bitStart)
		}

		if closeTo(d2, bitStart) {
			// nothing to do, this bit is already zero
		} else if closeTo(d2, bitOne) {
			val ^= (1 << (i / 2))
		} else {
			return 0, fmt.Errorf("invalid pulse %s (index %d), expected %s or %s", d2, i+1, bitStart, bitOne)
		}
	}

	return val, nil
}

func closeTo(d time.Duration, val time.Duration) bool {
	return d >= val-Tolerance && d <= val+Tolerance
}
