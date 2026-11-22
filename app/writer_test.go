package main

import (
	"bytes"
	"fmt"
	"io"
	"strings"
	"sync"
	"testing"
)

// stdout and stderr of an SSH session are copied by two goroutines into the same writer (Tablet.run).
func TestLockedWriterConcurrentLines(t *testing.T) {
	var buf bytes.Buffer
	var mu sync.Mutex
	var lines []string
	lw := &lockedWriter{w: io.MultiWriter(&buf, &lineWriter{log: func(l string) {
		mu.Lock()
		lines = append(lines, l)
		mu.Unlock()
	}})}
	var wg sync.WaitGroup
	for g := 0; g < 2; g++ {
		wg.Add(1)
		go func(g int) {
			defer wg.Done()
			for i := 0; i < 2000; i++ {
				fmt.Fprintf(lw, "stream %d line %d\n", g, i)
			}
		}(g)
	}
	wg.Wait()
	if len(lines) != 4000 {
		t.Fatalf("got %d lines, want 4000", len(lines))
	}
	for _, l := range lines {
		if !strings.HasPrefix(l, "stream ") {
			t.Fatalf("mixed line %q", l)
		}
	}
	if strings.Count(buf.String(), "\n") != 4000 {
		t.Fatalf("buffer lost lines")
	}
}
