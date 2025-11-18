package main

import "errors"

type Installer func(*SemVer) error

type UpgradeConfig struct {
	Repository string
	Prefix     string

	Binary string
	Args   []string

	Installer Installer
}

func (u *UpgradeConfig) Upgrade() error {
	log.Printf("Checking %s version...\n", u.Binary)

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

	log.Printf("Upgrading %s...\n", u.Binary)

	err = u.Installer(remote)
	if err != nil {
		return err
	}

	log.Println("Validating upgrade...")

	local, err = u.ResolveCurrentVersion()
	if err != nil {
		return err
	}

	if remote.HigherThan(local) {
		return errors.New("upgrade failed")
	}

	log.Println("upgrade okay")

	return nil
}
