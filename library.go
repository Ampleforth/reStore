package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

type Folder struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Parent string `json:"parent"`
}

// Read only the logical library metadata. Never expose filesystem paths to QML.
// A collection is visible only when its entire ancestry is live and well formed.
func libraryFolders(dir string) ([]Folder, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	all := map[string]Folder{}
	for _, entry := range entries {
		if entry.IsDir() || entry.Type()&os.ModeSymlink != 0 || !strings.HasSuffix(entry.Name(), ".metadata") {
			continue
		}
		id := strings.TrimSuffix(entry.Name(), ".metadata")
		if !uuidPattern.MatchString(id) {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			return nil, err
		}
		var m struct {
			Type, VisibleName, Parent string
			Deleted, Trashed          bool
		}
		if err := json.Unmarshal(data, &m); err != nil {
			return nil, errors.New("unreadable library metadata: " + id)
		}
		if m.Type == "CollectionType" && !m.Deleted && !m.Trashed && m.Parent != "trash" {
			all[id] = Folder{ID: id, Name: m.VisibleName, Parent: m.Parent}
		}
	}
	folders := []Folder{{ID: "", Name: "My files", Parent: ""}}
	for id, f := range all {
		seen := map[string]bool{}
		current := id
		valid := true
		for current != "" {
			if seen[current] {
				valid = false
				break
			}
			seen[current] = true
			parent, ok := all[current]
			if !ok {
				valid = false
				break
			}
			current = parent.Parent
		}
		if valid {
			folders = append(folders, f)
		}
	}
	sort.Slice(folders[1:], func(i, j int) bool {
		a, b := folders[i+1], folders[j+1]
		if a.Name == b.Name {
			return a.ID < b.ID
		}
		return strings.ToLower(a.Name) < strings.ToLower(b.Name)
	})
	return folders, nil
}

func validFolder(dir, id string) error {
	folders, err := libraryFolders(dir)
	if err != nil {
		return err
	}
	for _, f := range folders {
		if f.ID == id {
			return nil
		}
	}
	return errors.New("download folder no longer exists; choose a folder in Settings")
}

func saveJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	if err = os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".books-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), path)
}
