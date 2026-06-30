#!/bin/bash
echo "TURN_SECRET=$(openssl rand -hex 32)"
echo "SIGNALING_SECRET=$(openssl rand -hex 32)"
echo "INTERNAL_SECRET=$(openssl rand -hex 32)"
