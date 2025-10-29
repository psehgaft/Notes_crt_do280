# 🛠️ Migration Guide: MongoDB, PostgreSQL, and Redis to OpenShift

This guide explains how to migrate on-premise deployments of MongoDB, PostgreSQL, and Redis to OpenShift, including backup, restore, and deployment using persistent storage and operators.

---

## 📦 General Preparation

1. Assess whether to deploy as a **StatefulSet** or use a **managed service**.
2. Ensure you have a **Persistent Volume (PV)** and **Persistent Volume Claim (PVC)** strategy.
3. Use **official Operators** where available.
4. **Backup** your current database and **test restoration** before migration.

---

## 🟢 MongoDB Migration

### Option 1: Use MongoDB Atlas (Recommended)
- Integrate via MongoDB Atlas Operator on OpenShift.
- Use Kubernetes Secrets and environment variables for secure access.

### Option 2: Self-Managed MongoDB on OpenShift

#### 1. Backup on-premise
```bash
mongodump --out /path/to/backup
```

#### 2. Deploy MongoDB with PVC
Use Bitnami MongoDB Helm chart or create YAML for StatefulSet.

#### 3. Restore on OpenShift
```bash
mongorestore /path/to/backup
```

---

## 🔵 PostgreSQL Migration

### Option 1: Use Crunchy PostgreSQL Operator
- Provides HA, backup, and monitoring.

### Option 2: Self-Managed PostgreSQL

#### 1. Backup on-premise
```bash
pg_dump -U <user> -h <host> -Fc <database> > db_backup.dump
```

#### 2. Deploy PostgreSQL with PVC
Create Deployment or StatefulSet with PVCs.

#### 3. Restore
```bash
pg_restore -U <user> -d <new_db> db_backup.dump
```

---

## 🔴 Redis Migration

### Option 1: Use Redis Operator (Bitnami / Spotahome)

### Option 2: Manual Redis Setup

#### 1. Backup Redis
```bash
redis-cli save
# or copy dump.rdb from /var/lib/redis/
```

#### 2. Deploy Redis on OpenShift
Use StatefulSet or Deployment with mounted PVC for /data.

#### 3. Restore
Place `dump.rdb` in `/data` volume mount before starting Redis pod.

---

## ✅ Post-Migration Checklist

- Validate connectivity and permissions.
- Use readiness and liveness probes.
- Run integration and load tests.
- Ensure PVCs are properly retained and backed up.

---

## 🔐 Security and Secrets

- Use Kubernetes Secrets for DB credentials.
- Encrypt sensitive traffic with TLS.
