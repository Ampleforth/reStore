// Run the bundled-browser fixture in a private mount namespace on real hardware.
// This helper does not replace the installed app, write its profile or restart UI.
package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
)

func run() error {
	if len(os.Args) != 4 {
		return fmt.Errorf("usage: runner runtime-root fixture-directory parent|child")
	}
	root, fixtures := os.Args[1], os.Args[2]
	if os.Args[3] == "parent" {
		self, err := os.Executable()
		if err != nil {
			return err
		}
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		cmd := exec.CommandContext(ctx, self, root, fixtures, "child")
		cmd.SysProcAttr = &syscall.SysProcAttr{Cloneflags: syscall.CLONE_NEWNS, Setpgid: true, Pdeathsig: syscall.SIGKILL}
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		if err = cmd.Start(); err != nil {
			return err
		}
		defer syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		return cmd.Wait()
	}
	if os.Args[3] != "child" {
		return fmt.Errorf("unknown mode")
	}
	own, err := os.Readlink("/proc/self/ns/mnt")
	if err != nil {
		return err
	}
	parent, err := os.Readlink(fmt.Sprintf("/proc/%d/ns/mnt", os.Getppid()))
	if err != nil {
		return err
	}
	if own == parent {
		return fmt.Errorf("refusing to modify ordinary mount namespace")
	}
	files := map[string][]byte{}
	for _, name := range []string{"server.py", "parser.py", "browser_smoke.py"} {
		files[name], err = os.ReadFile(filepath.Join(fixtures, name))
		if err != nil {
			return err
		}
	}
	if err = syscall.Mount("", "/", "", syscall.MS_REC|syscall.MS_PRIVATE, ""); err != nil {
		return err
	}
	if err = syscall.Chroot(root); err != nil {
		return err
	}
	if err = os.Chdir("/"); err != nil {
		return err
	}
	if err = syscall.Mount("proc", "/proc", "proc", syscall.MS_NOSUID|syscall.MS_NODEV|syscall.MS_NOEXEC, ""); err != nil {
		return err
	}
	if err = syscall.Mount("tmpfs", "/dev", "tmpfs", syscall.MS_NOSUID, "mode=755,size=4m"); err != nil {
		return err
	}
	for name, minor := range map[string]int{"null": 3, "zero": 5, "random": 8, "urandom": 9} {
		if err = syscall.Mknod("/dev/"+name, syscall.S_IFCHR|0666, 256+minor); err != nil {
			return err
		}
		if err = os.Chmod("/dev/"+name, 0666); err != nil {
			return err
		}
	}
	if err = syscall.Mount("tmpfs", "/tmp", "tmpfs", syscall.MS_NOSUID|syscall.MS_NODEV, "mode=1777,size=128m"); err != nil {
		return err
	}
	if err = os.MkdirAll("/tmp/restore-tests/engine", 0755); err != nil {
		return err
	}
	if err = os.MkdirAll("/tmp/restore-tests/tests", 0755); err != nil {
		return err
	}
	for name, data := range files {
		dir := "engine"
		if name == "browser_smoke.py" {
			dir = "tests"
		}
		if err = os.WriteFile("/tmp/restore-tests/"+dir+"/"+name, data, 0644); err != nil {
			return err
		}
	}
	if err = syscall.Setgroups([]int{}); err != nil {
		return err
	}
	if err = syscall.Setgid(65534); err != nil {
		return err
	}
	if err = syscall.Setuid(65534); err != nil {
		return err
	}
	if _, _, errno := syscall.Syscall6(syscall.SYS_PRCTL, 38, 1, 0, 0, 0, 0); errno != 0 {
		return errno
	}
	return syscall.Exec("/usr/bin/python3.11", []string{"python3.11", "/tmp/restore-tests/tests/browser_smoke.py"}, []string{"PATH=/usr/bin:/bin", "HOME=/tmp", "LANG=C.UTF-8", "PYTHONPATH=/usr/lib/python3/dist-packages", "RESTORE_ISOLATED=1", "RESTORE_CHROMIUM=/usr/lib/chromium/chromium"})
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
