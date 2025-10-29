#!/bin/bash

REPORT_FILE="psehgaft-storage-report.txt"
NAMESPACE_STORAGE="openshift-storage"
NAMESPACE_LSO="openshift-local-storage"

echo "OpenShift ODF Storage Report" > $REPORT_FILE
echo "Generado en: $(date)" >> $REPORT_FILE
echo "------------------------------------------" >> $REPORT_FILE

# Paso 1: Discos detectados por Local Storage Operator
echo -e "\nPaso 1: LocalVolumeDiscoveryResult (Discos detectados por LSO)\n" >> $REPORT_FILE
oc get localvolumediscoveryresult -n $NAMESPACE_LSO -o wide >> $REPORT_FILE 2>&1

# Paso 2: PersistentVolumes
echo -e "\nPersistentVolumes\n" >> $REPORT_FILE
oc get pv -o wide >> $REPORT_FILE 2>&1

# Paso 2.1: Detalle de los primeros 5 PVs
for pv in $(oc get pv -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -n 5); do
  echo -e "\nDetalles de PV: $pv\n" >> $REPORT_FILE
  oc describe pv $pv >> $REPORT_FILE 2>&1
done

# Paso 3: Información Ceph OSDs
echo -e "\nCeph OSDs\n" >> $REPORT_FILE
TOOLS_POD=$(oc get pod -n $NAMESPACE_STORAGE -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')
if [[ -n "$TOOLS_POD" ]]; then
  oc rsh -n $NAMESPACE_STORAGE $TOOLS_POD ceph osd tree >> $REPORT_FILE 2>&1
  oc rsh -n $NAMESPACE_STORAGE $TOOLS_POD ceph osd df >> $REPORT_FILE 2>&1
  oc rsh -n $NAMESPACE_STORAGE $TOOLS_POD ceph volume lvm list >> $REPORT_FILE 2>&1
else
  echo "No se encontró el pod rook-ceph-tools." >> $REPORT_FILE
fi

# Paso 4: CephCluster deviceSets
echo -e "\nDeviceSets en CephCluster\n" >> $REPORT_FILE
oc get cephcluster -n $NAMESPACE_STORAGE -o yaml | grep -A10 deviceSets >> $REPORT_FILE 2>&1

# Paso 5: LocalVolumeSets
echo -e "\n Paso 5: LocalVolumeSets\n" >> $REPORT_FILE
oc get localvolumeset -n $NAMESPACE_STORAGE >> $REPORT_FILE 2>&1
for lvs in $(oc get localvolumeset -n $NAMESPACE_STORAGE -o name); do
  echo -e "\nDetalles de $lvs\n" >> $REPORT_FILE
  oc describe $lvs -n $NAMESPACE_STORAGE >> $REPORT_FILE 2>&1
done

# Paso 6: StorageCluster
echo -e "\nStorageCluster ocs-storagecluster\n" >> $REPORT_FILE
oc get storagecluster ocs-storagecluster -n $NAMESPACE_STORAGE -o yaml >> $REPORT_FILE 2>&1

echo -e "\nReporte generado: $REPORT_FILE"
