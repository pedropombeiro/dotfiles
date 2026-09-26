
#
# `docker-whois` is used to find out which container or network an IP address refers to
#

local target_ip="$1"

if [[ -z "$target_ip" ]]; then
  echo "Usage: docker-whois <IP_ADDRESS>"
  return 1
fi

echo "🔍 Searching for IP: $target_ip ..."
local found_match=0

# ----------------------------------------------
# 1. Search Container IPs (Running containers)
# ----------------------------------------------
# Format: [Name] [Tab] [List of IPs]
local container_results
container_results=$(docker ps -q | xargs -r docker inspect \
  --format '{{.Name}}'$'\t''{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' |
  awk -v ip="$target_ip" '$0 ~ "(^|[[:space:]])"ip"([[:space:]]|$)" {print $1}')

if [[ -n "$container_results" ]]; then
  echo ""
  echo "📦 FOUND CONTAINER(S):"
  for name in ${(f)container_results}; do # (f) splits on newlines
    echo "   • ${name#/}"
  done
  found_match=1
fi

# ----------------------------------------------
# 2. Search Network Gateways (Routers)
# ----------------------------------------------
# Format: [Network Name] [Tab] [Gateway IP]
local network_results
network_results=$(docker network ls -q | xargs -r docker network inspect \
  --format '{{.Name}}'$'\t''{{range .IPAM.Config}}{{.Gateway}} {{end}}' |
  awk -v ip="$target_ip" '$2 == ip {print $1}')

if [[ -n "$network_results" ]]; then
  echo ""
  echo "🌐 FOUND NETWORK GATEWAY:"
  for net in ${(f)network_results}; do
    echo "   • $net"
  done
  found_match=1
fi

# ----------------------------------------------
# 3. No results
# ----------------------------------------------
if (( ! found_match )); then
  echo ""
  echo "❌ No active container or network gateway found for $target_ip."
  return 1
fi
echo ""
