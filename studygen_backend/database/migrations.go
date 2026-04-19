package database

func RunMigrations() error {
	Migrate()
	return nil
}
