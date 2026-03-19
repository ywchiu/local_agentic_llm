#!/bin/bash
# Greeting script
NAME=$1
if [ -z "$NAME" ]
    echo "Usage: ./run.sh <name>"
    exit 1
fi
echo "Hello, $NAME! Welcome to OpenClaw."
echo "Greeted $NAME at $(date)" >> greeting_log.txt
