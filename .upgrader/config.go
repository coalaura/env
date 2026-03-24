package main

func GetConfigs() []*UpgradeConfig {
	return []*UpgradeConfig{
		// GoLang
		{
			Repository: "golang/go",
			Prefix:     "go",

			Binary: "go",
			Path:   GetGoBinaryPath(),
			Args:   []string{"version"},

			Installer: InstallGo,
		},

		// Zig
		{
			Repository: "ziglang/zig",
			Prefix:     "",

			Binary: "zig",
			Path:   GetZigBinaryPath(),
			Args:   []string{"version"},

			Installer: InstallZig,
		},

		// UPX
		{
			Repository: "upx/upx",
			Prefix:     "v",

			Binary: "upx",
			Path:   GetLocalBinaryPath("upx"),
			Args:   []string{"--version"},

			Installer: InstallUPX,
		},

		// Starship
		{
			Repository: "starship/starship",
			Prefix:     "v",

			Binary: "starship",
			Path:   GetLocalBinaryPath("starship"),
			Args:   []string{"--version"},

			Installer: InstallStarship,
		},

		// Bun
		{
			Repository: "oven-sh/bun",
			Prefix:     "bun-v",

			Binary: "bun",
			Path:   GetBunBinaryPath(),
			Args:   []string{"--version"},

			Installer: InstallBun,
		},

		// Biome JS
		{
			Repository: "biomejs/biome",
			Prefix:     "@biomejs/biome@",

			Binary: "biome",
			Path:   GetLocalBinaryPath("biome"),
			Args:   []string{"version"},

			Installer: InstallBiome,
		},

		// Time
		{
			Repository: "coalaura/time",
			Prefix:     "v",

			Binary: "time",
			Path:   GetLocalBinaryPath("time"),
			Args:   []string{"--version"},

			Installer: InstallTime,
		},

		// Coreutils
		{
			Repository: "uutils/coreutils",
			Prefix:     "",

			Binary: "ls",
			Path:   GetLocalBinaryPath("ls"),
			Args:   []string{"--version"},

			Installer: InstallCoreutils,
		},
	}
}
