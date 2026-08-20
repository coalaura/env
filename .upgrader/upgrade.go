package main

import (
	"errors"

	"github.com/coalaura/plain"
)

type Installer func(*SemVer) error
type VersionResolver func() (*SemVer, error)

type UpgradeConfig struct {
	Name       string
	Repository string
	Prefix     string
	Releases   bool

	Binary string
	Path   string
	Args   []string

	Installer Installer
	Resolver  VersionResolver
}

func (u *UpgradeConfig) GetName() string {
	if u.Name != "" {
		return u.Name
	}

	return u.Binary
}

func (u *UpgradeConfig) Upgrade() error {
	log.Printf("Checking %s version...\n", u.GetName())

	remote, err := u.FetchLatestVersion()
	if err != nil {
		return err
	}

	local, err := u.ResolveCurrentVersion()
	if err != nil {
		return err
	}

	if !remote.HigherThan(local) {
		log.Printf("Already up-to-date (%s == %s)\n", remote, local)

		return nil
	}

	log.Printf("New version found (%s > %s)\n", remote, local)

	log.Printf("Upgrading %s...\n", u.GetName())

	err = u.Installer(remote)
	if err != nil {
		return err
	}

	log.Print("Validating upgrade...")

	local, err = u.ResolveCurrentVersion()
	if err != nil {
		log.Errorln("failed")

		return err
	}

	if !remote.Equal(local) {
		log.Errorln("failed")

		return errors.New("installed version does not match requested version")
	}

	log.Writeln(log.Theme(plain.Success), "success", true, true)

	return nil
}
