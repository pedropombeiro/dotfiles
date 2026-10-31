{
  "secretDirs": [
    "/share/Container/secrets",
    "/share/CACHEDEV1_DATA/Container/secrets",
    "~/.config/op"
  ],
  "manifests": ["/share/CACHEDEV1_DATA/Container/secrets.manifest.toml"],
  "secretFiles": [
    "/share/CACHEDEV1_DATA/Container/compose/*/.env",
    "/share/CACHEDEV1_DATA/Container/compose/*/*.env",
    "/share/CACHEDEV1_DATA/Container/compose/grafana/prometheus/*.scrape.yml",
    "/share/CACHEDEV1_DATA/Container/config/*/keys/*.key",
    "/share/CACHEDEV1_DATA/Container/config/crowdsec/*_credentials.yaml",
    "/share/CACHEDEV1_DATA/Container/config/home-assistant/.storage/auth",
    "/share/CACHEDEV1_DATA/Container/config/mosquitto/password_file",
    "/share/CACHEDEV1_DATA/Container/config/home-assistant/secrets.yaml",
    "/share/CACHEDEV1_DATA/Container/data/borg/.ssh/id_ed25519",
    "/share/CACHEDEV1_DATA/Container/data/borg/borg/.pgpass",
    "~/.pgpass"
  ]
}
