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
		if closeTo(d, start) && i < len(times)-2 && closeTo(times[i+1], startSpace) {
			return command(times[i+2:])
		}
	}

	return 0, 0, fmt.Errorf("unable to find beginning of a valid command")
}

func command(times []time.Duration) (addr, cmd uint8, err error) {
	if len(times) < PayloadSize-2 {
		return 0, 0, fmt.Errorf("not enough data, must have a length of at least 67")
	}

	addr, err = parse("addr", times, 0)
	if err != nil {
		return 0, 0, err
	}

	iAddr, err := parse("iAddr", times, 16)
	if err != nil {
		return 0, 0, err
	}

	cmd, err = parse("cmd", times, 32)
	if err != nil {
		return 0, 0, err
	}

	iCmd, err := parse("iCmd", times, 48)
	if err != nil {
		return 0, 0, err
	}

	if iAddr != addr^0xff {
		return 0, 0, fmt.Errorf("invalid address %d, inverse %d", addr, iAddr)
	}

	if iCmd != cmd^0xff {
		return 0, 0, fmt.Errorf("invalid command %d, inverse %d", cmd, iCmd)
	}

	return addr, cmd, nil
}

func parse(typ string, times []time.Duration, start int) (val uint8, err error) {
	var mask uint8
	for i, d := range times[start : start+16] {
		if i%2 == 0 {
			if !closeTo(d, bitStart) {
				return 0, fmt.Errorf("invalid %s", typ)
			}
		} else {
			if closeTo(d, bitStart) {
				mask = 0
			} else if closeTo(d, bitOne) {
				mask = 1 << (i / 2)
			} else {
				return 0, fmt.Errorf("invalid %s", typ)
			}
			val ^= mask
		}
	}

	return val, nil
}

func closeTo(d time.Duration, val time.Duration) bool {
	return d >= val-tolerance && d <= val+tolerance
}
