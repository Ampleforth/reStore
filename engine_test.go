package main

import (
	"testing"
)

func TestEngineInitializerCannotAlterOrdinaryProcessNamespace(t *testing.T) {
	if err := engineInit("/nonexistent", "1", "2"); err == nil {
		t.Fatal("initializer accepted a process outside its private mount namespace")
	}
}
