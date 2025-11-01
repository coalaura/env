package main

func GetConfigs() []*UpgradeConfig {
	return []*UpgradeConfig{
		// GoLang
		{
			Repository: "golang/go",
			Prefix:     "go",

			Binary: "go",
			Args:   []string{"version"},

			Installer: InstallGo,
		},

		// Biome JS
		{
			Repository: "biomejs/biome",
			Prefix:     "@biomejs/biome@",

			Binary: "biome",
			Args:   []string{"version"},

			Installer: InstallBiome,
		},
	}
}
