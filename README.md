# HadoopHA
Creating a Hadoop Cluster with High-availability and Fail-over control


# 📦 Repository Structure

```
📦 hadoop-ha-cluster
│
├── 📄 README.md
│
├── ⚙️ Hadoop & Yarn configs
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── yarn-site.xml
│   └── mapred-site.xml
|
├── ⚙️ ZooKeeper
│   └── zoo.cfg
|
├── ⚙️ docker
│   └── docker-compose.yml
│
└── 🚀 scripts
    └── start_cluster.sh
```

---

# 🚀 Hadoop High Availability Cluster

![Hadoop](https://img.shields.io/badge/Apache-Hadoop-yellow)
![Cluster](https://img.shields.io/badge/Cluster-5%20Nodes-blue)
![High Availability](https://img.shields.io/badge/HDFS-High%20Availability-green)
![YARN](https://img.shields.io/badge/YARN-HA-orange)
![Status](https://img.shields.io/badge/Status-Completed-success)

An **Apache Hadoop cluster** with **High Availability** consisting of **5 nodes** on **Docker**:

This project demonstrates how production Hadoop clusters achieve:

*  Distributed Storage with **HDFS**
*  Distributed Processing with **YARN**
*  **Automatic Failover**
*  **ZooKeeper Coordination**
*  **JournalNode Quorum**
*  Containerized deployment

---

## ⚙️ Technologies & Stack 

| Component | Version | Purpose |
|-----------|---------| --------|
| 🐧Linux |  Ubuntu 24.04 | Cluster Environment and Bash Scripting |
| ☕ Java | OpenJDK 8 | Hadoop Framework and writing MapReduce Jobs |
| 🐘 Hadoop | 3.4.2 | Distributed Storage and Processing Solution |
| 🛠 ZooKeeper | 3.8.6 |  centralized coordination service for Hadoop |
| 🐳 Docker | Docker 3.8.0+ | Containerization and Virtualization  | 


## Prerequisites

- Docker Desktop installed and running
- The following files placed in the `/shared` folder before starting:
  - `hadoop-3.4.2.tar.gz`
  - `apache-zookeeper-3.8.6-bin.tar.gz`
  - `conf/` — Hadoop configuration files (`core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`, `mapred-site.xml`)
  - `zkconf/zoo.cfg` — ZooKeeper configuration


# 🖼️ Architecture Diagram


<img width="1536" height="1024" alt="ChatGPT Image Mar 7, 2026, 09_22_19 PM" src="https://github.com/user-attachments/assets/03cc5e2c-b408-4c7d-b342-fe1c77cb3530" />


---

# Cluster Architecture Overview

The cluster consists of **5 nodes** with high availability enabled for both **HDFS and YARN**.

| Node | Components | Role |
|------|-----------|------|
|🟦 **node01** | NameNode (Active/Standby), ResourceManager (Active/Standby), JournalNode, ZKFC, ZooKeeper | Primary NameNode — handles all HDFS metadata and YARN scheduling |
|🟦**node02** | NameNode (Standby/Active), ResourceManager (Standby/Active), JournalNode, ZKFC, ZooKeeper | Standby NameNode — hot backup, takes over automatically on failure |
|🟩**node03** | DataNode, JournalNode, NodeManager, ZooKeeper | Worker + third quorum member for JournalNode and ZooKeeper |
|🟩**node04** | DataNode, NodeManager | Pure worker node |
|🟩**node05** | DataNode, NodeManager | Pure worker node |

### Port Mappings

| Node | NameNode UI | YARN UI | JournalNode UI |
|------|------------|---------|----------------|
| node01 | 9871→9870 | 8081→8088 | 8481→8480 |
| node02 | 9872→9870 | 8082→8088 | 8482→8480 |
| node03 | 9873→9870 | 8083→8088 | 8483→8480 |
| node04 | 9874→9870 | 8084→8088 | — |
| node05 | 9875→9870 | 8085→8088 | — |

---
#  Core Components

## 🗂️ HDFS NameNode HA

Two NameNodes are configured for **fault tolerance**.

```text
Active NameNode  → node01 or node02
Standby NameNode → node02 or node01
```

ZooKeeper coordinates automatic failover between them.
ZooKeeper FailOver Controller (ZKFC) management of the NameNodes

---

## 🧾 JournalNode Quorum

JournalNodes store shared **HDFS edit logs**.

```
JournalNode Quorum
│
├── node01
├── node02
└── node03
```

This ensures metadata consistency between NameNodes.

---

## 📡 ZooKeeper Ensemble

ZooKeeper manages **leader election and failover**.

```
ZooKeeper Cluster
│
├── node01
├── node02
└── node03
```

---

## ⚙️ Worker Nodes

Worker nodes perform **storage and computation**.

```
Worker Nodes
│
├── node03
├── node04
└── node05
```

Each worker runs:

* DataNode
* NodeManager


---

# 🚀 Starting the Cluster

1. Start containers:
```bash
docker compose up -d
```

2. Enter the nodes:
```bash
docker exec -it node01 bash
docker exec -it node02 bash
docker exec -it node03 bash
docker exec -it node04 bash
docker exec -it node05 bash
```

3. Install the necessary packages **(All Nodes)**:
```bash
apt update
apt install openjdk-8-jdk
apt-get install ssh
apt-get install pdsh
apt-get install sudo
apt-get install vim
```

4. Unpack and install Hadoop **(All Nodes)**:
```bash
tar -xzf /shared/hadoop-3.4.2.tar.gz
mkdir /opt/hadoop && mv /hadoop-3.4.2/* /opt/hadoop/
```

5. Configure Java, Hadoop, and ZooKeeper variables **(All Nodes)**:
```bash
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> /opt/hadoop/etc/hadoop/hadoop-env.sh
cat >> ~/.bashrc << 'EOF'
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin
export HADOOP_HOME=/opt/hadoop
export PATH=$PATH:$HADOOP_HOME/bin
export PATH=$PATH:$HADOOP_HOME/sbin
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export ZK_HOME=/opt/zookeeper
export PATH=$PATH:$ZK_HOME/bin
EOF
source ~/.bashrc && echo $HADOOP_HOME && echo $JAVA_HOME
```

6. Configure passwordless SSH **(All Nodes)**:
```bash
service ssh start
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> /shared/authorized_keys
```

7. Distribute keys **(All Nodes)**:
```bash
cp /shared/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
ssh-keyscan -H node01 node02 node03 node04 node05 >> /root/.ssh/known_hosts
```

8. Fix environment PATH for non-interactive SSH sessions **(All Nodes)**:
```bash
cat >> /etc/environment << 'EOF'
PATH=/opt/hadoop/bin:/opt/hadoop/sbin:/opt/zookeeper/bin:/usr/lib/jvm/java-8-openjdk-amd64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
```

9. Check SSH **(from node01)**:
```bash
ssh root@node02
ssh root@node03
ssh root@node04
ssh root@node05
```

10. Install ZooKeeper **(Nodes 01, 02, 03)**:
```bash
tar -xzf /shared/apache-zookeeper-3.8.6-bin.tar.gz
mv apache-zookeeper-3.8.6-bin zookeeper
sudo cp -r /shared/zookeeper /opt/
```

11. Create ZooKeeper myid files **(Nodes 01, 02, 03)**:
```bash
mkdir -p /root/zookeeper/data
# node01:
echo "1" > /root/zookeeper/data/myid
# node02:
echo "2" > /root/zookeeper/data/myid
# node03:
echo "3" > /root/zookeeper/data/myid
```

12. Move zoo.cfg to the ZooKeeper config directory **(Nodes 01, 02, 03)**:
```bash
cp /shared/zkconf/zoo.cfg /opt/zookeeper/conf/zoo.cfg
```

13. Configure Hadoop daemon users **(All Nodes)**:
```bash
cat >> /opt/hadoop/etc/hadoop/hadoop-env.sh << 'EOF'
export HDFS_NAMENODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_JOURNALNODE_USER=root
export HDFS_ZKFC_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
EOF
```

14. Configure the workers file **(node01)**:
```bash
cat > /opt/hadoop/etc/hadoop/workers << EOF
node03
node04
node05
EOF
```

15. Move Hadoop configuration files **(All Nodes)**:
```bash
cp /shared/conf/* /opt/hadoop/etc/hadoop/
```

---

# 🔧 First Start and Formatting the Services

1. Create the required directories:
```bash
# Nodes 01 & 02
mkdir -p /root/hdfs/namenode
# Nodes 03, 04 & 05
mkdir -p /root/hdfs/datanode
```

2. Start SSH on all nodes:
```bash
# From PowerShell
foreach ($node in @("node01","node02","node03","node04","node05")) {
    docker exec $node service ssh start
}
```

3. Start ZooKeeper **(from node01)**:
```bash
for node in node01 node02 node03; do
    ssh $node "zkServer.sh start" && echo "Started on $node" || echo "Failed on $node"
done
```

4. Start JournalNodes **(from node01)**:
```bash
for node in node01 node02 node03; do
    ssh $node "hdfs --daemon start journalnode" && echo "Started on $node" || echo "Failed on $node"
done
```

5. Format ZooKeeper and NameNode **(node01)**:
```bash
hdfs zkfc -formatZK
hdfs namenode -format
```

6. Start Active NameNode, bootstrap Standby, then start all services **(node01)**:
```bash
hdfs --daemon start namenode
ssh node02 "hdfs namenode -bootstrapStandby"
start-dfs.sh
start-yarn.sh
```

---

# 🧪 Cluster Verification

Check running services:

```bash
jps | sort -k2 
```

**Expected output per node:**

| Node | Expected Processes |
|------|--------------------|
| node01 | NameNode, JournalNode, DFSZKFailoverController, QuorumPeerMain, ResourceManager |
| node02 | NameNode, JournalNode, DFSZKFailoverController, QuorumPeerMain, ResourceManager |
| node03 | DataNode, JournalNode, NodeManager, QuorumPeerMain |
| node04 | DataNode, NodeManager |
| node05 | DataNode, NodeManager |

---

## 🔁 Testing

### Test HDFS
```bash
hdfs dfsadmin -report
hdfs dfs -mkdir -p /user/hadoop/input
echo "hello world hello hadoop" > /shared/test.txt
hdfs dfs -put /shared/test.txt /user/hadoop/input/
hdfs dfs -ls /user/hadoop/input/
```

### Test MapReduce
```bash
hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
    wordcount /user/hadoop/input/test.txt /user/hadoop/output/wordcount

# View the output
hdfs dfs -cat /user/hadoop/output/wordcount/*
```

### Test HDFS Automatic Failover
```bash
# Check current active
hdfs haadmin -getServiceState nn1
hdfs haadmin -getServiceState nn2

# Kill the active NameNode (run on whichever node is active)
hdfs --daemon stop namenode

# Watch the standby take over
hdfs haadmin -getServiceState nn2

# Bring it back
hdfs --daemon start namenode
```

### Test YARN Automatic Failover
```bash
yarn rmadmin -getServiceState rm1
yarn --daemon stop resourcemanager
yarn rmadmin -getServiceState rm2   # should now be active
```

### Test JournalNode Quorum
```bash
# Open JournalNode UIs: http://localhost:8481, :8482, :8483
# Stop one JournalNode — HDFS should remain healthy
hdfs --daemon stop journalnode
hdfs dfs -ls /
hdfs dfsadmin -report

# Restart it
hdfs --daemon start journalnode
```
---
## Sources

1. [Hadoop HDFS High Availability with QJM](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/HDFSHighAvailabilityWithQJM.html)
2. [Hadoop Cluster Setup](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/ClusterSetup.html)
3. [YARN ResourceManager HA](https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceManagerHA.html)
4. [ZooKeeper Getting Started](https://zookeeper.apache.org/doc/r3.4.5/zookeeperStarted.html)

---

# 👨‍💻 Author

Omar Galal El-Deen | Data Engineer 
---
