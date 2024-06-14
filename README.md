# Directory Structure
```
home_server/
│
├── compose.yaml           # Main Docker Compose file to manage all categories
├── README.md                    # Documentation for your entire setup
├── .env                         # Global environment variables, if necessary
│
└── services/                    # Directory to organize all services by category
    ├── proxy/                   # Reverse proxy service (e.g., Nginx, Traefik)
    │   ├── compose.yaml   # Docker Compose for proxy services
    │   └── ...
    ├── media/                   # Media services (Plex, Radarr, Sonarr, Jackett)
    │   ├── plex/
    │   │   └── ...
    │   └── ...
    ├── torrenting/              # Torrent services (Deluge, VPN)
    │   ├── deluge_expressvpn/
    │   │   └── ...
    │   └── ...
    └── dns/                     # DNS services (e.g., Pi-hole)
        ├── pihole/
        └── ...
```

## TODO
- get email server for authentik
- portainer?

# Tools

## Using NFS Mount
To optimize NFS mount speeds, I used chatgpt to create a test_nfs.sh script that will try different options for NFS mount.