#!/usr/bin/env bash
set -e
set -u


echo "-- Search for dead code"
vulture ./**/ryax --exclude "*_pb2.py,*_pb2_grpc.py" --min-confidence=80
echo ""
echo "------------------------------------------------"
echo ""
echo "-- Search for security flaws"
bandit -r ./**/ryax
echo ""
echo "------------------------------------------------"
echo "Check done successfully"
