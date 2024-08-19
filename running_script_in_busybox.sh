volume_name=${1:-busybox-volume}
storage_class=${2:hwameistor-storage-lvm-hdd}
namespace=${3:-default}

busybox_deploy_template="
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: $namespace
  labels:
    app: busybox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: busybox
  template:
    metadata:
      labels:
        app: busybox
      name: busybox
    spec:
      restartPolicy: Always
      terminationGracePeriodSeconds: 0
      containers:
        - image: nginx:latest
          imagePullPolicy: IfNotPresent
          name: nginx
          ports:
            - containerPort: 80
          command:
            - sh
            - -c
            - 'while true; do current_time=\$(date +"%Y%m%d%H%M%S"); echo "\$current_time" | tee -a /mnt/data/time.log; sleep 1; done'
          volumeMounts:
            - name: data-volume
              mountPath: /mnt/data
          resources:
            limits:
              cpu: '100m'
              memory: '100Mi'
      volumes:
        - name: data-volume
          persistentVolumeClaim:
            claimName: ${volume_name}
      tolerations:
        - key: "key-test"
          value: "key-value"
          operator: "Equal"
          effect: "NoExecute"

---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ${volume_name}
  namespace: ${namespace}
spec:
  storageClassName: ${storage_class}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
"

echo "$busybox_deploy_template" | kubectl apply -f -
