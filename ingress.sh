curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-example ingress-nginx/ingress-nginx --set controller.hostNetwork=true

kubectl apply -f - << EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
  name: example
  namespace: kotstest
spec:
  ingressClassName: nginx
  rules:
    - host: pravin-visa-test.acceldata.dev
      http:
        paths:
          - pathType: Prefix
            backend:
              service:
                name: torch-api-gateway
                port:
                  number: 443
            path: /
EOF
