#!/bin/bash
# =============================================================================
# cluster_start.sh — Regular Hadoop HA Cluster Startup
# Run this script on NODE 01 only. Use after initial setup is complete.
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC}   $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}     $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}   $1"; }
fail() { echo -e "${RED}[FAIL]${NC}   $1"; exit 1; }
gate() { echo -e "${CYAN}[GATE]${NC}   $1"; }
step() { echo ""; echo -e "${BLUE}━━━ $1 ━━━${NC}"; }

ZK_NODES="node01 node02 node03"
NAMENODES="node01 node02"
DATANODES="node03 node04 node05"
ALL_NODES="node01 node02 node03 node04 node05"

# wait_for <description> <max_attempts> <sleep_sec> <command...>
wait_for() {
    local desc=$1 max=$2 delay=$3
    shift 3
    local attempt=1
    while (( attempt <= max )); do
        if "$@" &>/dev/null; then
            ok "$desc — ready"
            return 0
        fi
        log "$desc — attempt $attempt/$max, retrying in ${delay}s..."
        sleep "$delay"
        (( attempt++ ))
    done
    fail "$desc — did not become ready after $max attempts"
}

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Hadoop HA Cluster — Regular Start          ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
step "PRE-FLIGHT: Verify all nodes are reachable"
# ══════════════════════════════════════════════════════════════════════════════
for node in $ALL_NODES; do
    ssh -o ConnectTimeout=5 "$node" "echo ok" &>/dev/null \
        && ok "$node is reachable" \
        || fail "Cannot reach $node — ensure containers are running"
done
gate "All nodes reachable ✓"

# ══════════════════════════════════════════════════════════════════════════════
step "STEP 1: Start SSH on all nodes"
# ══════════════════════════════════════════════════════════════════════════════
for node in $ALL_NODES; do
    ssh "$node" "service ssh start" \
        && ok "SSH started on $node" \
        || fail "SSH service failed on $node"
done

for node in $ALL_NODES; do
    ssh -o ConnectTimeout=5 "$node" "echo ok" &>/dev/null \
        && ok "SSH verified on $node" \
        || fail "SSH not responding on $node after start"
done
gate "SSH operational on all nodes ✓"

# ══════════════════════════════════════════════════════════════════════════════
step "STEP 2: Clean stale PID files"
# ══════════════════════════════════════════════════════════════════════════════
for node in $ALL_NODES; do
    ssh "$node" "rm -f /tmp/hadoop-root-*.pid" \
        && ok "PID files cleared on $node"
done

# Gate: confirm no stale PIDs remain
for node in $ALL_NODES; do
    COUNT=$(ssh "$node" "ls /tmp/hadoop-root-*.pid 2>/dev/null | wc -l")
    [[ "$COUNT" -eq 0 ]] \
        && ok "No stale PIDs on $node" \
        || fail "Stale PID files still present on $node"
done
gate "All stale PID files cleared ✓"

# ══════════════════════════════════════════════════════════════════════════════
step "STEP 3: Start ZooKeeper"
# ══════════════════════════════════════════════════════════════════════════════
for node in $ZK_NODES; do
    ssh "$node" "zkServer.sh start" \
        && ok "ZooKeeper started on $node" \
        || fail "ZooKeeper failed on $node"
done

# Gate: wait for ZK quorum
for node in $ZK_NODES; do
    wait_for "ZooKeeper status on $node" 10 2 \
        ssh "$node" "zkServer.sh status 2>&1 | grep -qE 'leader|follower|standalone'"
done
gate "ZooKeeper quorum established ✓"

# ══════════════════════════════════════════════════════════════════════════════
step "STEP 4: Start DFS"
# ══════════════════════════════════════════════════════════════════════════════
start-dfs.sh || warn "start-dfs.sh had warnings (normal if some daemons already running)"

# Gate: wait for all NameNodes
for node in $NAMENODES; do
    wait_for "NameNode on $node" 15 2 \
        ssh "$node" "jps | grep -q NameNode"
done

# Gate: wait for all DataNodes
for node in $DATANODES; do
    wait_for "DataNode on $node" 15 2 \
        ssh "$node" "jps | grep -q DataNode"
done

# Gate: wait for JournalNodes
for node in node01 node02 node03; do
    wait_for "JournalNode on $node" 15 2 \
        ssh "$node" "jps | grep -q JournalNode"
done
gate "DFS up — NameNodes, DataNodes, JournalNodes running ✓"

# ══════════════════════════════════════════════════════════════════════════════
step "STEP 5: Start YARN"
# ══════════════════════════════════════════════════════════════════════════════
start-yarn.sh || warn "start-yarn.sh had warnings"

# Gate: both ResourceManagers
for node in $NAMENODES; do
    wait_for "ResourceManager on $node" 15 2 \
        ssh "$node" "jps | grep -q ResourceManager"
done

# Gate: all NodeManagers
for node in $DATANODES; do
    wait_for "NodeManager on $node" 15 2 \
        ssh "$node" "jps | grep -q NodeManager"
done
gate "YARN up — ResourceManagers and NodeManagers running ✓"

# ══════════════════════════════════════════════════════════════════════════════
step "FINAL VERIFICATION"
# ══════════════════════════════════════════════════════════════════════════════
log "JPS on all nodes:"
for node in $ALL_NODES; do
    echo ""
    echo -e "${YELLOW}=== $node ===${NC}"
    ssh "$node" "jps | sort -k2"
done

echo ""
log "NameNode HA States:"
NN1_STATE=$(hdfs haadmin -getServiceState nn1 2>&1)
NN2_STATE=$(hdfs haadmin -getServiceState nn2 2>&1)
echo "  nn1: $NN1_STATE"
echo "  nn2: $NN2_STATE"

if [[ "$NN1_STATE" == "active"  && "$NN2_STATE" == "standby" ]] || \
   [[ "$NN1_STATE" == "standby" && "$NN2_STATE" == "active"  ]]; then
    gate "NameNode HA valid — one active, one standby ✓"
else
    fail "NameNode HA invalid — expected one active and one standby, got nn1=$NN1_STATE nn2=$NN2_STATE"
fi

echo ""
log "ResourceManager HA States:"
RM1_STATE=$(yarn rmadmin -getServiceState rm1 2>&1)
RM2_STATE=$(yarn rmadmin -getServiceState rm2 2>&1)
echo "  rm1: $RM1_STATE"
echo "  rm2: $RM2_STATE"

if [[ "$RM1_STATE" == "active"  && "$RM2_STATE" == "standby" ]] || \
   [[ "$RM1_STATE" == "standby" && "$RM2_STATE" == "active"  ]]; then
    gate "ResourceManager HA valid — one active, one standby ✓"
else
    warn "ResourceManager HA unexpected — rm1=$RM1_STATE rm2=$RM2_STATE"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo -e "║  ${GREEN}Cluster started successfully!${NC}               ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
