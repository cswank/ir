package ir

import (
	"fmt"
	"time"
)

const (
	tolerance  = 100 * time.Microsecond
	start      = 9 * time.Millisecond
	startSpace = 4500 * time.Microsecond
	bitStart   = 562500 * time.Nanosecond
	bitOne     = 1687500 * time.Nanosecond

	PayloadSize = 67
)

type (
	cmd struct {
		addr  uint8
		iAddr uint8
		cmd   uint8
		iCmd  uint8
	}
)

func Command(times []time.Duration) (addr, cmd uint8, err error) {
	if len(times) < PayloadSize {
		return 0, 0, fmt.Errorf("not enough data, must have a length of at least 67")
	}

	for i, d := range times {
		if closeTo(d, start) && len(times)-i >= PayloadSize && closeTo(times[i+1], startSpace) && closeTo(times[64], bitStart) {
			return command(times[i+2:])
		}
	}

	return 0, 0, fmt.Errorf("unable to find a valid command")
}

func command(times []time.Duration) (uint8, uint8, error) {
	n, err := parse("addr", times)
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

func parse(typ string, times []time.Duration) (val uint32, err error) {
	for i, d := range times[:64] {
		if i%2 == 0 {
			if !closeTo(d, bitStart) {
				return 0, fmt.Errorf("invalid %s", typ)
			}
		} else {
			if closeTo(d, bitStart) {
				// nothing to do, this bit is already zero
			} else if closeTo(d, bitOne) {
				val ^= (1 << (i / 2))
			} else {
				return 0, fmt.Errorf("invalid %s", typ)
			}
		}
	}

	return val, nil
}

func closeTo(d time.Duration, val time.Duration) bool {
	return d >= val-tolerance && d <= val+tolerance
}
