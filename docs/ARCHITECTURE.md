# 🏗️ Architecture Overview

## Production Deployment Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                          INTERNET                              │
└───────────────────────┬────────────────────────────────────────┘
                        │
                        │ HTTPS (443) / HTTP (80)
                        │
┌───────────────────────▼────────────────────────────────────────┐
│                 Nginx Proxy Manager                            │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ • SSL Termination (Let's Encrypt)                    │     │
│  │ • Reverse Proxy                                      │     │
│  │ • Security Headers                                   │     │
│  │ • Rate Limiting                                      │     │
│  └──────────────────────────────────────────────────────┘     │
└────────┬────────────────────────────┬──────────────────────────┘
         │                            │
         │ :8081                      │ :8080
         │ (internal)                 │ (internal)
┌────────▼──────────────┐   ┌────────▼──────────────────────────┐
│  Flutter Web Frontend │   │  PocketBase Backend               │
│  ┌─────────────────┐  │   │  ┌─────────────────────────────┐  │
│  │ Caddy Server    │  │   │  │ • REST API                  │  │
│  │ • Static Files  │  │   │  │ • Admin UI                  │  │
│  │ • SPA Routing   │  │   │  │ • File Storage              │  │
│  └─────────────────┘  │   │  │ • Real-time Subscriptions   │  │
└───────────────────────┘   │  └─────────────────────────────┘  │
                            │  ┌─────────────────────────────┐  │
                            │  │ Auto-Initialization         │  │
                            │  │ • Create Admin User         │  │
                            │  │ • Apply Migrations          │  │
                            │  │ • Setup Collections         │  │
                            │  └─────────────────────────────┘  │
                            └───┬────────────────────────────────┘
                                │
                        ┌───────▼───────┐
                        │  Volumes      │
                        │  • pb_data    │
                        │  • pb_public  │
                        │  • pb_backups │
                        └───────────────┘
```

## Dev/Test Deployment Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                       DEVELOPER PC                             │
└───────────────────────┬────────────────────────────────────────┘
                        │
                        │ localhost
                        │
         ┌──────────────┴──────────────┐
         │                             │
         │ :8081                       │ :8080
         │ (exposed)                   │ (exposed)
┌────────▼──────────────┐   ┌──────────▼────────────────────────┐
│  Flutter Web Frontend │   │  PocketBase Backend               │
│  ┌─────────────────┐  │   │  ┌─────────────────────────────┐  │
│  │ Caddy Server    │  │   │  │ • REST API                  │  │
│  │ • Static Files  │  │   │  │ • Admin UI                  │  │
│  │ • SPA Routing   │  │   │  │ • File Storage              │  │
│  └─────────────────┘  │   │  └─────────────────────────────┘  │
└───────────────────────┘   │  ┌─────────────────────────────┐  │
                            │  │ Auto-Initialization         │  │
                            │  │ • Create Admin User         │  │
                            │  │ • Apply Migrations          │  │
                            │  │ • Setup Collections         │  │
                            │  └─────────────────────────────┘  │
                            └───┬────────────────────────────────┘
                                │
                        ┌───────▼────────┐
                        │  Local Volumes │
                        │  • pb_data     │
                        │  • pb_public   │
                        └────────────────┘
```

## Mobile/Desktop Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Mobile/Desktop App                          │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   Flutter Frontend                       │ │
│  │  • Offline-First Architecture                           │ │
│  │  • Local SQLite Database                                │ │
│  │  • Image Caching                                        │ │
│  └────────┬─────────────────────────────────────────────────┘ │
└───────────┼────────────────────────────────────────────────────┘
            │
            │ Background Sync
            │
┌───────────▼────────────────────────────────────────────────────┐
│                    PocketBase Server                           │
│  • Conflict Resolution                                         │
│  • Delta Sync                                                  │
│  • File Upload/Download                                        │
└────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. First Start (Auto-Initialization)

```
┌──────────────┐
│ Docker Start │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ PocketBase Container │
│ Starts               │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────────┐
│ init-pocketbase.sh Executes │
└──────┬──────────────────────┘
       │
       ├─► Check if data.db exists
       │   └─► No? Continue
       │
       ├─► Wait for PocketBase API
       │   └─► Health check loop
       │
       ├─► Create Admin User
       │   └─► From ENV variables
       │
       ├─► Copy Migrations
       │   └─► To pb_data/migrations/
       │
       └─► Apply Migrations
           └─► Create collections
               └─► Set API Rules
```

### 2. User Request Flow

```
┌─────────┐
│ Browser │
└────┬────┘
     │ HTTPS
     ▼
┌─────────────────┐
│ Nginx Proxy Mgr │ ◄─── SSL Certificate
└────┬────────────┘      (Let's Encrypt)
     │
     ├─► /         ──► Flutter Web (Caddy)
     │                  └─► Serve static files
     │
     └─► /api/*    ──► PocketBase
                        ├─► Check Authentication
                        ├─► Process Request
                        └─► Return JSON
```

### 3. Authentication Flow

```
┌──────────┐
│  Client  │
└────┬─────┘
     │ POST /api/collections/users/auth-with-password
     ▼
┌────────────────┐
│  PocketBase    │
│  Auth Service  │
└────┬───────────┘
     │ Validate
     ├─► Check email/password
     ├─► Generate JWT token
     └─► Return token + user
         │
         ▼
┌────────────────┐
│  Client Stores │
│  Token         │
└────────────────┘
     │
     │ Subsequent requests include:
     │ Authorization: Bearer <token>
     ▼
┌────────────────┐
│  PocketBase    │
│  Middleware    │
└────┬───────────┘
     │ Verify Token
     ├─► Valid? → Process request
     └─► Invalid? → 401 Unauthorized
```

## File Structure

```
lager_app/
├── app/                          # Flutter Application
│   ├── lib/                      # Dart source code
│   ├── web/                      # Web-specific files
│   ├── Dockerfile                # Multi-stage build
│   └── pubspec.yaml              # Dependencies
│
├── server/                       # Backend Configuration
│   ├── Dockerfile                # Custom PocketBase image
│   ├── init-pocketbase.sh        # Auto-initialization script
│   ├── pb_migrations/            # Database migrations
│   │   ├── 1772784781_created_artikel.js
│   │   └── pb_schema.json
│   ├── pb_data/                  # Database (volume)
│   ├── pb_public/                # Public files (volume)
│   └── pb_backups/               # Backups (volume)
│
├── .github/workflows/            # CI/CD
│   └── docker-build-push.yml     # Build & push images
│
├── docs/                         # Documentation
│   ├── PRODUCTION_DEPLOYMENT.md
│   ├── IMPLEMENTATION_SUMMARY.md
│   └── TECHNISCHE_ANALYSE_2026-03.md
│
├── docker-compose.yml            # Dev/Test setup
├── docker-compose.prod.yml       # Production setup
├── docker-stack.yml              # Docker Swarm setup
├── .env.example                  # Dev/Test template
├── .env.production.example       # Production template
├── test-deployment.sh            # Validation script
├── QUICKSTART.md                 # Quick setup guide
├── CHANGELOG.md                  # Version history
└── README.md                     # Main documentation
```

## Security Boundaries

```
┌────────────────────────────────────────────────────────────────┐
│                       PUBLIC INTERNET                          │
│                      (Untrusted Zone)                          │
└───────────────────────┬────────────────────────────────────────┘
                        │
              ┌─────────▼──────────┐
              │   Firewall         │
              │   • Port 80 ✓      │
              │   • Port 443 ✓     │
              │   • Port 8080 ✗    │
              │   • Port 8081 ✗    │
              │   • Port 81 ✗      │
              └─────────┬──────────┘
                        │
┌───────────────────────▼────────────────────────────────────────┐
│                       DMZ                                      │
│  ┌────────────────────────────────────────────────────┐        │
│  │ Nginx Proxy Manager                                │        │
│  │ • SSL Termination                                  │        │
│  │ • Rate Limiting                                    │        │
│  │ • Security Headers                                 │        │
│  └────────────────────────────────────────────────────┘        │
└───────────────────────┬────────────────────────────────────────┘
                        │ Internal Network
┌───────────────────────▼────────────────────────────────────────┐
│                  APPLICATION ZONE                              │
│                  (Internal Only)                               │
│  ┌──────────────────┐        ┌──────────────────────┐         │
│  │ Flutter Web      │        │ PocketBase           │         │
│  │ Port: 8081       │        │ Port: 8080           │         │
│  │ (not exposed)    │        │ (not exposed)        │         │
│  └──────────────────┘        └──────────────────────┘         │
│                                      │                         │
│                              ┌───────▼──────┐                  │
│                              │  Volumes     │                  │
│                              │  (Encrypted) │                  │
│                              └──────────────┘                  │
└────────────────────────────────────────────────────────────────┘
```

## Deployment States

### State 1: Initial Deployment
```
[Fresh Server] → [Git Clone] → [Configure ENV] → [Docker Compose Up]
                                                         ↓
                                            [Auto-Init Runs]
                                                         ↓
                                            [Services Ready]
```

### State 2: Update Deployment
```
[Running Server] → [Git Pull] → [Docker Compose Build] → [Rolling Update]
                                                               ↓
                                                    [Zero Downtime]
```

### State 3: Backup & Restore
```
[Running Server] → [Create Backup] → [Copy to Safe Location]
                         ↓
                   [Disaster Occurs]
                         ↓
                   [Fresh Server] → [Restore Backup] → [Services Ready]
```

---

**Key Principles:**

1. **Security First**: Authentication required, no public endpoints
2. **Automation**: Zero-configuration deployment
3. **Simplicity**: One command to deploy
4. **Reliability**: Health checks and auto-restart
5. **Scalability**: Docker Stack support for multi-node
6. **Maintainability**: Clear structure and documentation
