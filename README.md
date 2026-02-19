# 🧠 Neural Hub -- Automation & AI Starter Kit v1.0

A modern mini infrastructure stack for: - ⚙️ Automation (n8n) - 🧠 AI
Interface (Open WebUI) - 🗂 Knowledge Base (AFFiNE Workspaces) - 🔐 HTTPS
via Traefik - 🗄 PostgreSQL + Redis backend

------------------------------------------------------------------------

## 🧱 Stack Components

-   Traefik (Reverse Proxy + Let's Encrypt)
-   n8n (Workflow Automation)
-   Open WebUI (LLM Interface)
-   AFFiNE (Open‑source Knowledge Base)
-   PostgreSQL (pgvector ready)
-   Redis

------------------------------------------------------------------------

## 🏗 Architecture Diagram (Mermaid)

``` mermaid
flowchart TB

    User((User))

    subgraph Internet
        User
    end

    subgraph VPS
        Traefik[Traefik Reverse Proxy]

        subgraph Apps
            N8N[n8n Automation]
            WEBUI[Open WebUI]
            AFFINE[AFFiNE Workspace]
        end

        subgraph Internal
            PG[(PostgreSQL + pgvector)]
            REDIS[(Redis)]
        end
    end

    User -->|HTTPS| Traefik

    Traefik -->|workflows.domain| N8N
    Traefik -->|ai.domain| WEBUI
    Traefik -->|workspace.domain| AFFINE

    N8N --> PG
    N8N --> REDIS

    AFFINE --> PG
    AFFINE --> REDIS

    WEBUI --> PG
```

------------------------------------------------------------------------

## 🚀 Quick Start

``` bash
cp .env.template .env
nano .env
docker compose up -d
```

------------------------------------------------------------------------

## 📦 n8n Workflows (Included Conceptually)

### 1️⃣ Discord → AI → Database Log

-   Discord Trigger
-   LLM (summarize)
-   Insert into PostgreSQL

Example table:

``` sql
CREATE TABLE community_insights (
  id SERIAL PRIMARY KEY,
  username TEXT,
  original_message TEXT,
  summary TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

------------------------------------------------------------------------

### 2️⃣ AFFiNE Page → Discord Notification

-   Webhook
-   Format
-   Discord notification

------------------------------------------------------------------------

### 3️⃣ Webhook Lead Capture

-   Public Webhook
-   Store in Postgres
-   Email alert
-   Return JSON response

------------------------------------------------------------------------

## 🔐 Security Notes

-   Never expose PostgreSQL publicly
-   Never commit `.env`
-   Enable authentication on n8n
-   Use firewall rules on VPS
-   Backup Docker volumes regularly [see server-backup-to-google-drive](server-backup-to-google-drive.md)

------------------------------------------------------------------------

## 🎯 Philosophy

This is not a demo stack.

This is a modern automation architecture blueprint for builders, makers,
and founders.

------------------------------------------------------------------------

## 🧠 Neural Hub Vision

-   Experiment
-   Automate
-   Document
-   Scale

Neural Hub is a living project. Contributions, feedback, and ideas are welcome!

Join us on Discord to collaborate on building the future of automation and AI interfaces.

https://neuralhub.wad-labs.fr/
