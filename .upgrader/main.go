package main

import (
	"os"
	"strings"

	"github.com/coalaura/plain"
)

var log = plain.New(plain.WithDate(plain.RFC3339Local))

func main() {
	configs := GetConfigs()
	configs = FilterConfigs(configs, os.Args[1:])

	for _, cfg := range configs {
		err := cfg.Upgrade()
		if err != nil {
			log.Warnln(err)
		}
	}
}

func FilterConfigs(configs []*UpgradeConfig, names []string) []*UpgradeConfig {
	if len(names) == 0 {
		return configs
	}

	allowed := make(map[string]struct{}, len(names))

	for _, name := range names {
		allowed[strings.ToLower(strings.TrimSpace(name))] = struct{}{}
	}

	filtered := make([]*UpgradeConfig, 0, len(configs))

	for _, cfg := range configs {
		name := strings.ToLower(cfg.GetName())

		if _, ok := allowed[name]; ok {
			filtered = append(filtered, cfg)

			continue
		}
	}

	return filtered
}
