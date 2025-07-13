#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# stop.sh
#
# Finds and stops all running Docker containers. It does not remove any
# containers or images.
# -----------------------------------------------------------------------------

# Ensure docker is installed
if ! command -v docker &> /dev/null; then
  echo "Error: Docker not found. Please install Docker first." >&2
  exit 1
fi

echo "➡️  Finding all running containers..."
# Gets a list of IDs for all currently running containers
running_containers=$(docker ps -q)

if [ -n "$running_containers" ]; then
  echo "Found running containers. Stopping them now..."
  # The list of container IDs is passed to the stop command
  docker stop $running_containers
  echo "✅ All running containers have been stopped."
else
  echo "ℹ️  No running containers found. Nothing to do."
fi

echo "✨ Operation complete!"