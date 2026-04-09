# label-studio

A custom Docker base image extending [heartexlabs/label-studio](https://hub.docker.com/r/heartexlabs/label-studio) with a pre-configured entrypoint and automatic template initialization script.

**Support:** halay09@gmail.com

> **Copyright Notice**
> This image is built on top of the official **Label Studio** Docker image by Heartex Labs.
> Base image: [`heartexlabs/label-studio`](https://hub.docker.com/r/heartexlabs/label-studio)
> Label Studio is licensed under the [Apache 2.0 License](https://github.com/HumanSignal/label-studio/blob/master/LICENSE).

---

## Overview

This image serves as a **reusable base** for Label Studio deployments. It adds:
- A custom `entrypoint.sh` wrapper
- An `init_template.sh` script that auto-seeds a template project on first startup
- An `auto_attach_ml_backend.sh` watcher that auto-connects ML backend for UI-created projects

Child images extend this base to inject project-specific annotation templates.

---

## Directory Structure

```
label-studio/
├── Dockerfile          # Builds the base image
├── entrypoint.sh       # Wrapper: runs init_template.sh in background, then starts Label Studio
├── init_template.sh    # Seeds a template project via Django ORM on first startup
├── auto_attach_ml_backend.sh # Auto-connect ML backend to new projects
├── requirements.txt    # Extra Python dependencies to install into the Label Studio venv
└── template/           # (Optional) custom annotation templates — handled by child images
```

---

## How It Works

### `entrypoint.sh`
Wraps the default Label Studio startup:
1. Starts `init_template.sh` in the background
2. Calls `exec label-studio` — Label Studio becomes PID 1 (handles signals correctly)

### `init_template.sh`
Runs after Label Studio is healthy:
1. Waits for the `/health` endpoint to return `UP`
2. Uses Django ORM directly to create a template project if one doesn't already exist
3. **Idempotent** — safe to run on every container restart

### `auto_attach_ml_backend.sh`
Runs as a background watcher:
1. Waits for Label Studio readiness
2. Polls projects created from UI
3. Auto-creates ML backend connection for each project if missing (idempotent)

---

## Build

```bash
docker build -t label-studio .
```

---

## Usage with Docker Compose

```yaml
services:
  label-studio:
    build:
      context: ./label-studio
      dockerfile: Dockerfile
    image: label-studio:latest
    ports:
      - "8080:8080"
    volumes:
      - label_studio_data:/label-studio/data

volumes:
  label_studio_data:
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LABEL_STUDIO_URL` | `http://localhost:8080` | Internal URL used by `init_template.sh` to check health |
| `LABEL_STUDIO_USERNAME` | `ai-engineer@localhost` | Default admin user email |
| `LABEL_STUDIO_PASSWORD` | `changeme` | Default admin user password |
| `LABEL_STUDIO_HOST` | `http://localhost:8080` | Public host URL shown in Label Studio UI |
| `AUTO_ATTACH_ML_BACKEND_URL` | `http://sphere-ai-sam-backend:9090` | ML backend URL to auto-connect for every project |
| `AUTO_ATTACH_ML_BACKEND_TITLE` | `SphereAI SAM Backend` | Display title for auto-connected backend |
| `AUTO_ATTACH_POLL_INTERVAL` | `5` | Poll interval in seconds for new projects |
