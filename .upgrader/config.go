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
			Resolver:  FetchLatestGoVersion,
		},

		// Zig
		{
			Repository: "ziglang/zig",
			Prefix:     "",

			Binary: "zig",
			Path:   GetZigBinaryPath(),
			Args:   []string{"version"},

			Installer: InstallZig,
			Resolver:  FetchLatestZigVersion,
		},

		// UPX
		{
			Repository: "upx/upx",
			Prefix:     "v",
			Releases:   true,

			Binary: "upx",
			Path:   GetLocalBinaryPath("upx"),
			Args:   []string{"--version"},

			Installer: InstallUPX,
		},

		// Starship
		{
			Repository: "starship/starship",
			Prefix:     "v",
			Releases:   true,

			Binary: "starship",
			Path:   GetLocalBinaryPath("starship"),
			Args:   []string{"--version"},

			Installer: InstallStarship,
		},

		// Bun
		{
			Repository: "oven-sh/bun",
			Prefix:     "bun-v",
			Releases:   true,

			Binary: "bun",
			Path:   GetBunBinaryPath(),
			Args:   []string{"--version"},

			Installer: InstallBun,
		},

		// Biome JS
		{
			Repository: "biomejs/biome",
			Prefix:     "@biomejs/biome@",
			Releases:   true,

			Binary: "biome",
			Path:   GetLocalBinaryPath("biome"),
			Args:   []string{"version"},

			Installer: InstallBiome,
		},

		// Vet
		{
			Repository: "coalaura/vet",
			Prefix:     "v",
			Releases:   true,

			Binary: "vet",
			Path:   GetLocalBinaryPath("vet"),
			Args:   []string{"--version"},

			Installer: InstallVet,
		},

		// Time
		{
			Repository: "coalaura/time",
			Prefix:     "v",
			Releases:   true,

			Binary: "time",
			Path:   GetLocalBinaryPath("time"),
			Args:   []string{"--version"},

			Installer: InstallTime,
		},

		// Wtf
		{
			Repository: "coalaura/wtf",
			Prefix:     "v",
			Releases:   true,

			Binary: "wtf",
			Path:   GetLocalBinaryPath("wtf"),
			Args:   []string{"--version"},

			Installer: InstallWtf,
		},

		// Coreutils
		{
			Repository: "uutils/coreutils",
			Prefix:     "",
			Releases:   true,

			Binary: "coreutils",
			Path:   GetLocalBinaryPath("coreutils"),
			Args:   []string{"--version"},

			Installer: InstallCoreutils,
		},
	}
}
