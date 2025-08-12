#!/usr/bin/env bash

# Walker restart helper script
# Usage: restart-walker.sh

echo "Stopping walker service..."
pkill -f "walker --gapplication-service" || true

echo "Waiting for walker to stop..."
sleep 2

echo "Starting walker service..."
walker --gapplication-service &

echo "Walker service restarted!"
