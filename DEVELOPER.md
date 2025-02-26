# Khoj Developer Guide

This guide provides instructions for developers working on the Khoj project. It explains how to set up your development environment and use the provided Makefile to streamline your workflow.

## Prerequisites

- Python 3.9+
- PostgreSQL
- Node.js and Yarn
- Git

## Getting Started with the Makefile

The Khoj project includes a comprehensive Makefile to simplify development workflows. Below is a detailed guide on how to use it effectively.

### Initial Setup

To set up your development environment for the first time:

```bash
# Install all dependencies (backend and frontend)
make install

# Set up the PostgreSQL database
make setup-db
```

The installation process will:
1. Create a Python virtual environment (`.venv`)
2. Install backend dependencies
3. Install frontend (Yarn) dependencies
4. Set up the PostgreSQL database named "khoj"

### Development Workflow

#### Option 1: Unified Development Experience

For a streamlined development experience with both backend and frontend servers running in the background:

```bash
# Start both backend and frontend servers in the background
make run-dev
```

This command:
- Starts the backend server in anonymous mode (no authentication required)
- Starts the frontend development server with hot reloading
- Opens your browser automatically to http://localhost:3000
- Runs both servers in the background so you can continue using your terminal

To monitor the servers:

```bash
# View backend logs in real-time
make logs-backend

# View frontend logs in real-time
make logs-frontend
```

To stop all development servers:

```bash
# Stop all running servers
make stop-servers
```

#### Option 2: Manual Control with Separate Terminals

For more direct control over the servers, you can run them in separate terminals:

```bash
# Terminal 1: Run the backend server
make run-backend

# Terminal 2: Run the frontend development server
make run-frontend-dev
```

This approach provides immediate feedback in each terminal and allows you to restart individual servers as needed.

### Building Frontend Assets

To build the frontend assets for production:

```bash
# Build frontend assets
make build-frontend
```

### Cleaning Up

To clean up temporary files and stop all running servers:

```bash
# Clean up temporary files and stop servers
make clean
```

## Development Notes

### Server Locations
- Backend API: http://127.0.0.1:42110
- Frontend UI: http://localhost:3000

### Anonymous Mode

The backend server runs with the `--anonymous-mode` flag, which bypasses email authentication. This simplifies development by removing the need to set up email credentials.

### Hot Reload

The frontend development server automatically reloads when you make changes to the frontend code. Note that the backend does not have automatic reload capability - you'll need to restart it manually when making backend changes.

### Streaming Limitation

When using the frontend development server (Next.js), streaming responses from the backend will not work correctly due to Next.js SSR limitations. To test streaming functionality, use the backend server endpoint directly.

### Getting Help

You can always view available commands and their descriptions:

```bash
# Show help information
make help
```

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Ensure PostgreSQL is running (`sudo service postgresql status`)
   - Verify that the database "khoj" exists (`sudo -u postgres psql -l`)

2. **Port Conflicts**
   - If port 42110 or 3000 is already in use, stop the conflicting service or modify the port settings

3. **Missing Dependencies**
   - Run `make install` to ensure all dependencies are installed

4. **Server Not Starting**
   - Check the logs with `make logs-backend` or `make logs-frontend`
   - Ensure all dependencies have been properly installed

For more detailed information about Khoj development, refer to the official [Khoj Development Documentation](https://docs.khoj.dev/contributing/development). 