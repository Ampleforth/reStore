package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLibraryFolders(t *testing.T) {
	dir := t.TempDir()
	ids := []string{"00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002", "00000000-0000-0000-0000-000000000003", "00000000-0000-0000-0000-000000000004", "00000000-0000-0000-0000-000000000005"}
	values := []map[string]any{
		{"type": "CollectionType", "visibleName": "Books", "parent": ""},
		{"type": "CollectionType", "visibleName": "Fiction", "parent": ids[0]},
		{"type": "CollectionType", "visibleName": "Deleted", "parent": "", "deleted": true},
		{"type": "CollectionType", "visibleName": "Hidden child", "parent": ids[2]},
		{"type": "CollectionType", "visibleName": "Cycle", "parent": ids[4]},
	}
	for i, v := range values {
		if err := saveJSON(filepath.Join(dir, ids[i]+".metadata"), v); err != nil {
			t.Fatal(err)
		}
	}
	os.WriteFile(filepath.Join(dir, "secret"), []byte("not library metadata"), 0600)
	folders, err := libraryFolders(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(folders) != 3 || folders[0].Name != "My files" {
		t.Fatalf("%+v", folders)
	}
	if err = validFolder(dir, ids[1]); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{ids[2], ids[3], ids[4], "../../etc"} {
		if validFolder(dir, id) == nil {
			t.Fatal("accepted", id)
		}
	}
}
