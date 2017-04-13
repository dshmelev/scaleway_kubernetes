alias etcdctl="etcdctl --endpoints https://$(hostname):2379 --ca-file /etc/ssl/ca.pem --cert-file /etc/ssl/server.pem --key-file /etc/ssl/server-key.pem"
