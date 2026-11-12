package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"
	"time"
)

// Run only in the private mount namespace established by ensureEngine.
// The browser gets a separate filesystem and an unprivileged UID; it cannot
// traverse the tablet's documents or the root user's home directory.
func engineInit(root, port, driverPort string) error {
	if os.Geteuid() != 0 {
		return errors.New("browser initializer requires root for setup")
	}
	selfNS, err := os.Readlink("/proc/self/ns/mnt")
	if err != nil {
		return err
	}
	parentNS, err := os.Readlink(fmt.Sprintf("/proc/%d/ns/mnt", os.Getppid()))
	if err != nil {
		return err
	}
	if selfNS == parentNS {
		return errors.New("browser initializer requires its own mount namespace")
	}
	if err := syscall.Mount("", "/", "", syscall.MS_REC|syscall.MS_PRIVATE, ""); err != nil {
		return err
	}
	if err := syscall.Chroot(root); err != nil {
		return err
	}
	if err := os.Chdir("/"); err != nil {
		return err
	}
	if err := syscall.Mount("proc", "/proc", "proc", syscall.MS_NOSUID|syscall.MS_NODEV|syscall.MS_NOEXEC, ""); err != nil {
		return err
	}
	if err := syscall.Mount("tmpfs", "/dev", "tmpfs", syscall.MS_NOSUID, "mode=755,size=4m"); err != nil {
		return err
	}
	for name, minor := range map[string]int{"null": 3, "zero": 5, "random": 8, "urandom": 9} {
		if err := syscall.Mknod("/dev/"+name, syscall.S_IFCHR|0666, 256+minor); err != nil {
			return err
		}
		if err := os.Chmod("/dev/"+name, 0666); err != nil {
			return err
		}
	}
	if err := syscall.Mount("tmpfs", "/tmp", "tmpfs", syscall.MS_NOSUID|syscall.MS_NODEV, "mode=1777,size=128m"); err != nil {
		return err
	}
	if err := syscall.Setgroups([]int{}); err != nil {
		return err
	}
	if err := syscall.Setgid(65534); err != nil {
		return err
	}
	if err := syscall.Setuid(65534); err != nil {
		return err
	}
	// Prevent bundled set-ID helpers or file capabilities from raising privileges.
	if _, _, errno := syscall.Syscall6(syscall.SYS_PRCTL, 38, 1, 0, 0, 0, 0); errno != 0 {
		return errno
	}
	env := []string{"PATH=/usr/bin:/bin", "HOME=/state", "LANG=C.UTF-8", "PYTHONPATH=/usr/lib/python3/dist-packages", "RESTORE_ISOLATED=1", "RESTORE_LIFECYCLE_FD=3", "RESTORE_CHROMIUM=/usr/lib/chromium/chromium", "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt", "XDG_CACHE_HOME=/state/cache", "XDG_CONFIG_HOME=/state/config"}
	return syscall.Exec("/usr/bin/python3.11", []string{"python3.11", "/app/server.py", "--state", "/state", "--port", port, "--driver-port", driverPort}, env)
}

func freePort() (int, error) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

func (s *Service) ensureEngine() error {
	if s.engineExited != nil {
		select {
		case <-s.engineExited:
			if s.enginePipe != nil {
				s.enginePipe.Close()
				s.enginePipe = nil
			}
			s.engineURL = ""
			s.engineProcess = nil
			s.engineExited = nil
		default:
		}
	}
	if s.engineURL != "" {
		return nil
	}
	if os.Geteuid() != 0 {
		return errors.New("the bundled browser must be launched by AppLoad on the tablet")
	}
	if _, err := os.Stat(filepath.Join(s.engineRoot, "usr/lib/chromium/chromium")); err != nil {
		return errors.New("bundled on-tablet browser runtime is missing")
	}
	state := filepath.Join(s.engineRoot, "state")
	if err := os.MkdirAll(state, 0700); err != nil {
		return err
	}
	if err := os.Chown(state, 65534, 65534); err != nil {
		return err
	}
	if err := os.Chmod(state, 0700); err != nil {
		return err
	}
	random := make([]byte, 32)
	if _, err := rand.Read(random); err != nil {
		return err
	}
	s.engineToken = hex.EncodeToString(random)
	tokenPath := filepath.Join(state, "token")
	// Create under the trusted runtime directory, then replace the state entry.
	// Never follow a symlink placed in browser-writable state by the child UID.
	secret, err := os.CreateTemp(s.engineRoot, ".token-*")
	if err != nil {
		return err
	}
	defer os.Remove(secret.Name())
	if _, err = secret.Write([]byte(s.engineToken)); err != nil {
		secret.Close()
		return err
	}
	if err = secret.Chown(65534, 65534); err != nil {
		secret.Close()
		return err
	}
	if err = secret.Close(); err != nil {
		return err
	}
	if err = os.Rename(secret.Name(), tokenPath); err != nil {
		return err
	}
	dns, err := os.ReadFile("/etc/resolv.conf")
	if err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(s.engineRoot, "etc/resolv.conf"), dns, 0644); err != nil {
		return err
	}
	port, err := freePort()
	if err != nil {
		return err
	}
	driverPort, err := freePort()
	if err != nil {
		return err
	}
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	log, err := os.OpenFile(filepath.Join(s.engineRoot, "engine.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer log.Close()
	cmd := exec.Command(executable, "--engine-init", s.engineRoot, strconv.Itoa(port), strconv.Itoa(driverPort))
	readPipe, writePipe, err := os.Pipe()
	if err != nil {
		return err
	}
	defer readPipe.Close()
	cmd.ExtraFiles = []*os.File{readPipe}
	cmd.SysProcAttr = &syscall.SysProcAttr{Cloneflags: syscall.CLONE_NEWNS, Setpgid: true, Pdeathsig: syscall.SIGKILL}
	cmd.Stdout, cmd.Stderr = log, log
	if err = cmd.Start(); err != nil {
		writePipe.Close()
		return fmt.Errorf("start isolated on-tablet browser: %w", err)
	}
	s.engineProcess = cmd
	s.enginePipe = writePipe
	s.engineExited = make(chan error, 1)
	exited := s.engineExited
	go func() { exited <- cmd.Wait() }()
	address := fmt.Sprintf("http://127.0.0.1:%d", port)
	client := &http.Client{Timeout: time.Second}
	for n := 0; n < 180; n++ {
		select {
		case err := <-exited:
			s.enginePipe.Close()
			s.enginePipe = nil
			s.engineProcess = nil
			s.engineExited = nil
			return fmt.Errorf("on-tablet browser exited (%v); see runtime/engine.log", err)
		default:
		}
		req, _ := http.NewRequest("GET", address+"/status", nil)
		req.Header.Set("Authorization", "Bearer "+s.engineToken)
		resp, err := client.Do(req)
		if err == nil {
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			if resp.StatusCode == 200 {
				s.engineURL = address
				return nil
			}
		}
		time.Sleep(time.Second)
	}
	s.stopEngine()
	return errors.New("on-tablet browser startup timed out; see runtime/engine.log")
}
func (s *Service) stopEngine() {
	if s.enginePipe != nil {
		s.enginePipe.Close()
		s.enginePipe = nil
	}
	if s.engineProcess != nil {
		select {
		case <-s.engineExited:
		case <-time.After(6 * time.Second):
			syscall.Kill(-s.engineProcess.Process.Pid, syscall.SIGKILL)
		}
	}
	s.engineProcess = nil
	s.engineExited = nil
	s.engineURL = ""
}
