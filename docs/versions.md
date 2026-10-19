# Pinned versions (verified 2026-10-19)

Reference clones live in ~/orbit-audit/upstream/ (never committed).

| Service | Git ref | Commit | Docker image (digest) | Status |
|---|---|---|---|---|
| Twenty | twenty/v2.48.0 | 0c87e74ac3c5 | twentycrm/twenty:v2.48.0 (sha256:43fab4bf…) | M1: run |
| n8n | n8n@2.43.7 | b7c54308e4d7 | n8nio/n8n:2.43.7 (sha256:3db21366…) | M1: run |
| Postgres | - | - | postgres:16-alpine (sha256:721873c3…) | M1: run |
| Redis | - | - | redis:7-alpine (sha256:858f009f…) | M1: run |
| Caddy | - | - | caddy:2-alpine (sha256:d8542f48…) | M1: run |
| Mailpit | - | - | axllent/mailpit:v1.31.6 | M1: run |
| Mautic | 7.2.1 | 8cbb7ef874d5 | mautic/mautic:7.2.1-apache (sha256:ff584fd1…) | later: not run |
| Chatwoot | v4.18.0 | 9f920b549c14 | chatwoot/chatwoot:v4.18.0-ce (sha256:faaa58a9…) | later: not run. Use the -ce tag (community edition, no enterprise code) |
| Postiz | v2.25.1 | 91c91f633a01 | ghcr.io/gitroomhq/postiz-app:v2.25.1 (sha256:d2b37802…) | later: not run; needs Temporal + Elasticsearch |

Rule: never use :latest. Upgrade one service at a time, after a backup.
