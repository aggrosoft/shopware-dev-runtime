package main

import (
	"fmt"
	"io"
	"net"
	"os"
	"time"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: nc HOST PORT")
		os.Exit(2)
	}

	addr := net.JoinHostPort(os.Args[1], os.Args[2])

	conn, err := net.DialTimeout("tcp", addr, 10*time.Second)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer conn.Close()

	errCh := make(chan error, 2)

	go func() {
		_, err := io.Copy(conn, os.Stdin)
		if tcp, ok := conn.(*net.TCPConn); ok {
			_ = tcp.CloseWrite()
		}
		errCh <- err
	}()

	go func() {
		_, err := io.Copy(os.Stdout, conn)
		errCh <- err
	}()

	if err := <-errCh; err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
