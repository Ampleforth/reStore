package main

import (
	"archive/zip"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type Config struct {
	Folder    string `json:"folder"`
	SecretKey string `json:"secretKey,omitempty"`
}
type Service struct {
	mu                                 sync.Mutex
	config                             Config
	configPath, library, staging       string
	client                             *http.Client
	staged                             string
	engineRoot, engineURL, engineToken string
	engineProcess                      *exec.Cmd
	engineExited                       chan error
	enginePipe                         io.Closer
}

func (s *Service) remote(ctx context.Context, method, path string, body io.Reader) (*http.Response, error) {
	if err := s.ensureEngine(); err != nil {
		return nil, err
	}
	u, err := url.Parse(s.engineURL)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return nil, errors.New("invalid local browser address")
	}
	endpoint, err := url.Parse(path)
	if err != nil {
		return nil, err
	}
	u.Path = strings.TrimRight(u.Path, "/") + endpoint.Path
	u.RawQuery = endpoint.RawQuery
	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+s.engineToken)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return s.client.Do(req)
}
func (s *Service) settings() (any, error) {
	folders, err := libraryFolders(s.library)
	return map[string]any{"folder": s.config.Folder, "folders": folders, "hasSecretKey": s.config.SecretKey != ""}, err
}
func (s *Service) stage(ctx context.Context, title string) (any, error) {
	if err := validFolder(s.library, s.config.Folder); err != nil {
		return nil, err
	}
	if s.staged != "" {
		return map[string]any{"file": (&url.URL{Scheme: "file", Path: s.staged}).String(), "folder": s.config.Folder}, nil
	}
	resp, err := s.remote(ctx, "GET", "/file", nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, errors.New("no completed book download is available")
	}
	format := resp.Header.Get("X-Book-Format")
	if format != "epub" && format != "pdf" {
		return nil, errors.New("download is not EPUB or PDF")
	}
	if err = os.MkdirAll(s.staging, 0700); err != nil {
		return nil, err
	}
	f, err := os.CreateTemp(s.staging, "Book-*."+format)
	if err != nil {
		return nil, err
	}
	ok := false
	defer func() {
		f.Close()
		if !ok {
			os.Remove(f.Name())
		}
	}()
	const limit = 512 * 1024 * 1024
	n, err := io.Copy(f, io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if n > limit {
		return nil, errors.New("book exceeds the 512 MiB download limit")
	}
	if err = f.Sync(); err != nil {
		return nil, err
	}
	if err = f.Close(); err != nil {
		return nil, err
	}
	if err = validateBook(f.Name(), format); err != nil {
		return nil, err
	}
	// Recheck after transfer: the user may have moved or deleted a folder meanwhile.
	if err = validFolder(s.library, s.config.Folder); err != nil {
		return nil, err
	}
	// Give the native importer the book title, not a generated cache filename.
	title = strings.Map(func(r rune) rune {
		if r < 32 || strings.ContainsRune(`/\\:*?"<>|`, r) {
			return '-'
		}
		return r
	}, title)
	title = strings.Trim(title, " .-")
	if title == "" {
		title = "Book"
	}
	runes := []rune(title)
	if len(runes) > 100 {
		title = string(runes[:100])
	}
	dir, err := os.MkdirTemp(s.staging, "import-*")
	if err != nil {
		return nil, err
	}
	final := filepath.Join(dir, title+"."+format)
	if err = os.Rename(f.Name(), final); err != nil {
		os.Remove(dir)
		return nil, err
	}
	s.staged = final
	ok = true
	return map[string]any{"file": (&url.URL{Scheme: "file", Path: s.staged}).String(), "folder": s.config.Folder}, nil
}
func validateBook(path, format string) error {
	if format == "pdf" {
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		defer f.Close()
		prefix := make([]byte, 1024)
		n, _ := f.Read(prefix)
		if !strings.Contains(string(prefix[:n]), "%PDF-") {
			return errors.New("the server returned a page instead of a PDF")
		}
		return nil
	}
	z, err := zip.OpenReader(path)
	if err != nil {
		return errors.New("the server returned a page instead of an EPUB")
	}
	defer z.Close()
	for _, f := range z.File {
		if f.Name == "mimetype" {
			r, err := f.Open()
			if err != nil {
				return err
			}
			b, err := io.ReadAll(io.LimitReader(r, 100))
			r.Close()
			if err == nil && string(b) == "application/epub+zip" {
				return nil
			}
		}
	}
	return errors.New("download is not a valid EPUB archive")
}
func (s *Service) handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Type", "application/json")
		isCover := r.Method == "GET" && r.URL.Path == "/cover"
		if r.Header.Get("Origin") != "" || (!isCover && r.Header.Get("X-ArchiveBooks-Request") != "app") {
			http.Error(w, `{"error":"forbidden"}`, 403)
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		respond := func(v any, err error) {
			if err != nil {
				w.WriteHeader(400)
				v = map[string]string{"error": err.Error()}
			}
			json.NewEncoder(w).Encode(v)
		}
		if isCover {
			resp, err := s.remote(r.Context(), "GET", "/cover?"+r.URL.RawQuery, nil)
			if err != nil {
				respond(nil, err)
				return
			}
			defer resp.Body.Close()
			if resp.StatusCode != 200 || !strings.HasPrefix(resp.Header.Get("Content-Type"), "image/") {
				w.WriteHeader(404)
				return
			}
			b, err := io.ReadAll(io.LimitReader(resp.Body, 4*1024*1024+1))
			if err != nil || len(b) > 4*1024*1024 {
				w.WriteHeader(502)
				return
			}
			w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
			w.Write(b)
			return
		}
		if r.URL.Path == "/settings" {
			if r.Method == "POST" {
				var v struct {
					Folder    *string `json:"folder"`
					SecretKey *string `json:"secretKey"`
				}
				d := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096))
				d.DisallowUnknownFields()
				if err := d.Decode(&v); err != nil {
					respond(nil, err)
					return
				}
				next := s.config
				if v.Folder != nil {
					if err := validFolder(s.library, *v.Folder); err != nil {
						respond(nil, err)
						return
					}
					next.Folder = *v.Folder
				}
				if v.SecretKey != nil {
					next.SecretKey = strings.TrimSpace(*v.SecretKey)
					if len(next.SecretKey) > 256 || strings.ContainsAny(next.SecretKey, "\r\n") {
						respond(nil, errors.New("secret key must be at most 256 characters on one line"))
						return
					}
				}
				if err := saveJSON(s.configPath, next); err != nil {
					respond(nil, err)
					return
				}
				s.config = next
			} else if r.Method != "GET" {
				w.WriteHeader(http.StatusMethodNotAllowed)
				json.NewEncoder(w).Encode(map[string]string{"error": "settings method not allowed"})
				return
			}
			v, err := s.settings()
			respond(v, err)
			return
		}
		if r.Method == "POST" && r.URL.Path == "/download" {
			var input struct {
				Title string `json:"title"`
			}
			if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&input); err != nil {
				respond(nil, err)
				return
			}
			v, err := s.stage(r.Context(), input.Title)
			respond(v, err)
			return
		}
		if r.Method == "POST" && r.URL.Path == "/imported" {
			if s.staged != "" {
				// Remove the local browser's copy only after the native importer succeeds.
				resp, err := s.remote(r.Context(), "POST", "/ack", strings.NewReader(`{}`))
				if err != nil {
					respond(nil, err)
					return
				}
				resp.Body.Close()
				if resp.StatusCode != 200 {
					respond(nil, errors.New("could not acknowledge the import to the local browser"))
					return
				}
				if err := os.Remove(s.staged); err != nil && !os.IsNotExist(err) {
					respond(nil, err)
					return
				}
				os.Remove(filepath.Dir(s.staged))
				s.staged = ""
			}
			respond(map[string]bool{"ok": true}, nil)
			return
		}
		routes := map[string]string{"POST /search": "/search", "POST /book": "/book", "POST /start": "/start", "GET /browser": "/browser", "POST /browser": "/browser", "GET /status": "/status", "POST /account": "/account", "POST /account/resume": "/account/resume", "POST /account/logout": "/account/logout"}
		path, ok := routes[r.Method+" "+r.URL.Path]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			json.NewEncoder(w).Encode(map[string]string{"error": "unknown local reStore endpoint"})
			return
		}
		if path == "/start" && s.staged != "" {
			respond(nil, errors.New("finish importing the previous download first"))
			return
		}
		var body io.Reader
		if r.Method == "POST" {
			b, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 16384))
			if err != nil {
				respond(nil, err)
				return
			}
			body = strings.NewReader(string(b))
		}
		if path == "/account" {
			var input struct {
				Reuse bool `json:"reuse"`
			}
			if err := json.NewDecoder(body).Decode(&input); err != nil {
				respond(nil, errors.New("invalid account request"))
				return
			}
			data, _ := json.Marshal(map[string]any{"key": s.config.SecretKey, "reuse": input.Reuse})
			body = strings.NewReader(string(data))
		}
		resp, err := s.remote(r.Context(), r.Method, path, body)
		if err != nil {
			respond(nil, err)
			return
		}
		defer resp.Body.Close()
		b, err := io.ReadAll(io.LimitReader(resp.Body, 12*1024*1024+1))
		if err != nil {
			respond(nil, err)
			return
		}
		if len(b) > 12*1024*1024 || !json.Valid(b) {
			respond(nil, errors.New("invalid response from browser local browser"))
			return
		}
		if resp.StatusCode == 200 && (path == "/search" || path == "/book") {
			var value any
			if json.Unmarshal(b, &value) == nil {
				var rewrite func(any)
				rewrite = func(v any) {
					switch x := v.(type) {
					case map[string]any:
						for k, v := range x {
							if k == "cover" {
								if u, ok := v.(string); ok && u != "" {
									x[k] = "http://" + r.Host + "/cover?url=" + url.QueryEscape(u)
								}
							} else {
								rewrite(v)
							}
						}
					case []any:
						for _, v := range x {
							rewrite(v)
						}
					}
				}
				rewrite(value)
				b, _ = json.Marshal(value)
			}
		}
		w.WriteHeader(resp.StatusCode)
		w.Write(b)
	})
}
func lifecycle(path string) (net.Conn, error) {
	var conn net.Conn
	var err error
	for n := 0; n < 50; n++ {
		conn, err = net.Dial("unixpacket", path)
		if err == nil {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if err != nil {
		return nil, err
	}
	go func() {
		defer os.Exit(0)
		buf := make([]byte, 8)
		for {
			n, err := conn.Read(buf)
			if err != nil || n != 8 {
				return
			}
			kind, length := binary.NativeEndian.Uint32(buf[:4]), binary.NativeEndian.Uint32(buf[4:])
			if length > 10*1024*1024 {
				return
			}
			if length > 0 {
				b := make([]byte, length)
				n, err = conn.Read(b)
				if err != nil || uint32(n) != length {
					return
				}
			}
			if kind == ^uint32(0) {
				return
			}
		}
	}()
	return conn, nil
}
func main() {
	if len(os.Args) == 5 && os.Args[1] == "--engine-init" {
		if err := engineInit(os.Args[2], os.Args[3], os.Args[4]); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	home, _ := os.UserHomeDir()
	executable, _ := os.Executable()
	engineRoot := flag.String("runtime", filepath.Join(filepath.Dir(filepath.Dir(executable)), "runtime"), "bundled on-tablet browser root")
	probeSearch := flag.String("probe-search", "", "test an on-tablet search and exit")
	configPath := flag.String("config", filepath.Join(home, ".config/archive-books/config.json"), "saved library folder")
	library := flag.String("library", filepath.Join(home, ".local/share/remarkable/xochitl"), "library metadata directory")
	staging := flag.String("staging", filepath.Join(home, ".local/share/archive-books/staging"), "private import staging")
	listen := flag.String("listen", "127.0.0.1:38767", "loopback API address")
	flag.Parse()
	host, _, err := net.SplitHostPort(*listen)
	if err != nil || (host != "127.0.0.1" && host != "::1") {
		fmt.Fprintln(os.Stderr, "listen must be loopback")
		os.Exit(1)
	}
	c := Config{}
	b, err := os.ReadFile(*configPath)
	if err == nil {
		err = json.Unmarshal(b, &c)
	}
	if err != nil && !os.IsNotExist(err) {
		fmt.Fprintln(os.Stderr, "invalid configuration")
		os.Exit(1)
	}
	s := &Service{config: c, configPath: *configPath, library: *library, staging: *staging, engineRoot: *engineRoot, client: &http.Client{Timeout: 10 * time.Minute, CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}}
	defer s.stopEngine()
	if *probeSearch != "" {
		data, _ := json.Marshal(map[string]any{"query": *probeSearch, "page": 1})
		resp, err := s.remote(context.Background(), "POST", "/search", strings.NewReader(string(data)))
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		defer resp.Body.Close()
		io.Copy(os.Stdout, io.LimitReader(resp.Body, 32768))
		if resp.StatusCode != 200 {
			os.Exit(1)
		}
		return
	}
	server := &http.Server{Handler: s.handler(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 11 * time.Minute, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192}
	listener, err := net.Listen("tcp", *listen)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer listener.Close()
	if flag.NArg() > 0 {
		conn, err := lifecycle(flag.Arg(0))
		if err != nil {
			fmt.Fprintln(os.Stderr, "AppLoad connection failed")
			os.Exit(1)
		}
		defer conn.Close()
	}
	if err = server.Serve(listener); err != nil && err != http.ErrServerClosed {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
