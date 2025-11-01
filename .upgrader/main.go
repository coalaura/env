package main

import (
	"github.com/coalaura/plain"
)

var log = plain.New(plain.WithDate(plain.RFC3339Local))

func main() {
	configs := GetConfigs()

	for _, cfg := range configs {
		err := cfg.Upgrade()
		if err != nil {
			log.Warnln(err)
		}
	}
}
