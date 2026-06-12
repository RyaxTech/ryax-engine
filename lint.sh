#!/usr/bin/env bash
set -e
set -u


echo "-- Search for dead code"
vulture ./**/ryax --exclude "*_pb2.py,*_pb2_grpc.py" --min-confidence=80
echo "                  ==="
echo "              NO DEAD CODE !"
echo "------------------------------------------------"
echo ""
echo "-- Search for security flaws"
bandit --severity-level=high --confidence-level=high -r ./**/ryax
echo "                  ==="
echo "         NO HIGH SEVERITY FLAW"
echo "------------------------------------------------"
echo ""
echo "-- Search for vulnerability in dependencies"
git submodule foreach uv audit
echo "                  ==="
echo "     NO HIGH SEVERITY VULNERABILITY"
echo "------------------------------------------------"
echo "Check done successfully !"
