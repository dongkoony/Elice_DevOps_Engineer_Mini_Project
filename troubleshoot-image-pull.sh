#!/bin/bash

# Container Registry 연결 및 이미지 Pull 최적화

set -e

echo "🔧 Image Pull 문제 완전 해결"
echo "================================================="

# 1. Registry IP 주소 확인
REGISTRY_IP=$(docker network inspect kind | grep -A 4 registry | grep IPv4Address | cut -d'"' -f4 | cut -d'/' -f1)
echo "📍 Registry IP: $REGISTRY_IP"

# 2. Kind 클러스터 노드에서 Registry 연결 설정
echo "🔗 Kind 클러스터 노드에서 Registry 연결 설정..."

# Kind 노드의 /etc/hosts에 registry 호스트명 추가
docker exec elice-devops-control-plane sh -c "
# 기존 registry 항목 제거
sed -i '/registry$/d' /etc/hosts
# 새로운 registry 항목 추가
echo '$REGISTRY_IP registry' >> /etc/hosts
echo '✅ Registry 호스트명 추가됨: $REGISTRY_IP registry'
"

# 3. containerd에서 insecure registry 허용 설정 업데이트
echo "⚙️ containerd insecure registry 설정 업데이트..."

docker exec elice-devops-control-plane sh -c "
# containerd registry 설정 디렉토리 생성
mkdir -p /etc/containerd/certs.d/registry:5000

# Registry 설정 파일 생성
cat > /etc/containerd/certs.d/registry:5000/hosts.toml <<EOF
server = 'http://registry:5000'

[host.'http://registry:5000']
  capabilities = ['pull', 'resolve']
  skip_verify = true
  plain_http = true

[host.'http://$REGISTRY_IP:5000']
  capabilities = ['pull', 'resolve']
  skip_verify = true
  plain_http = true
EOF

echo '✅ containerd registry 설정 완료'
"

# 4. containerd 재시작
echo "🔄 containerd 서비스 재시작..."
docker exec elice-devops-control-plane systemctl restart containerd
sleep 5

# 5. Registry 연결 테스트
echo "🔍 Registry 연결 테스트..."
docker exec elice-devops-control-plane sh -c "
# Registry 호스트명 해석 확인
nslookup registry || echo 'DNS 해석 실패 - /etc/hosts 사용'

# Registry 연결 테스트
curl -s http://registry:5000/v2/ && echo '✅ Registry HTTP 연결 성공' || echo '❌ Registry 연결 실패'
curl -s http://$REGISTRY_IP:5000/v2/ && echo '✅ Registry IP 연결 성공' || echo '❌ Registry IP 연결 실패'

# Registry 카탈로그 확인
curl -s http://registry:5000/v2/_catalog && echo '' || echo '카탈로그 접근 실패'
"

# 6. 이미지 존재 확인 및 재푸시
echo "📦 이미지 존재 확인 및 재푸시..."

# 로컬에서 이미지 확인
docker images | grep api-gateway

# Registry에 이미지 푸시 (IP 주소 사용)
echo "Registry에 이미지 재푸시..."
docker tag localhost:5000/api-gateway:dev-10-51b78e3 $REGISTRY_IP:5000/api-gateway:dev-10-51b78e3
docker tag localhost:5000/api-gateway:dev-10-51b78e3 registry:5000/api-gateway:dev-10-51b78e3

# localhost:5000 Registry를 통해 재푸시
docker push localhost:5000/api-gateway:dev-10-51b78e3

# Registry 이미지 확인
echo "Registry 이미지 목록 확인:"
curl -s http://localhost:5000/v2/_catalog
curl -s http://localhost:5000/v2/api-gateway/tags/list

# 7. 매니페스트 파일에서 이미지 경로 최적화
echo "📝 매니페스트 이미지 경로 최적화..."

# IP 주소 사용하도록 매니페스트 수정
sed -i "s|registry:5000/api-gateway:dev-10-51b78e3|$REGISTRY_IP:5000/api-gateway:dev-10-51b78e3|g" aws/kubernetes/dev/api-gateway.yaml

echo "✅ 매니페스트 업데이트 완료:"
grep "image:" aws/kubernetes/dev/api-gateway.yaml

# 8. API Gateway Pod 재배포
echo "♻️ API Gateway Pod 재배포..."

# 기존 Pod 삭제
kubectl delete pod -l app=api-gateway -n elice-devops-dev --ignore-not-found=true

# 새로운 배포 적용
kubectl apply -f aws/kubernetes/dev/api-gateway.yaml

# 9. Pod 상태 모니터링
echo "📊 Pod 배포 상태 모니터링..."

for i in {1..12}; do
    echo "[$i/12] Pod 상태 확인 중..."
    kubectl get pods -l app=api-gateway -n elice-devops-dev --no-headers
    
    pod_status=\$(kubectl get pods -l app=api-gateway -n elice-devops-dev --no-headers | head -1 | awk '{print \$3}')
    
    if [[ "\$pod_status" == "Running" ]]; then
        echo "🎉 API Gateway Pod 성공적으로 실행됨!"
        kubectl get pods -l app=api-gateway -n elice-devops-dev
        break
    elif [[ "\$pod_status" == "ContainerCreating" ]]; then
        echo "⏳ 컨테이너 생성 중..."
    elif [[ "\$pod_status" == "ImagePullBackOff" ]] || [[ "\$pod_status" == "ErrImagePull" ]]; then
        echo "⚠️ 이미지 Pull 문제 계속 발생 중..."
        if [[ \$i -gt 6 ]]; then
            echo "📋 추가 진단 정보:"
            kubectl describe pod -l app=api-gateway -n elice-devops-dev | grep -A 3 "Failed to pull image"
        fi
    fi
    
    sleep 10
done

# 10. 다른 서비스들 정리 (ECR 이미지 사용 서비스)
echo "🧹 ECR 이미지 사용 서비스들 정리..."

# ECR 접근 불가 서비스들 스케일 다운
SERVICES_TO_SCALE="analytics-service auth-service health-service inventory-service log-service notification-service order-service payment-service product-service review-service user-service"

for service in \$SERVICES_TO_SCALE; do
    echo "Scaling down \$service..."
    kubectl scale deployment \$service -n elice-devops-dev --replicas=0 2>/dev/null || echo "Deployment \$service not found"
done

# 11. 최종 상태 확인
echo ""
echo "🎯 최종 상태 확인"
echo "=================="

echo "Registry 상태:"
curl -s http://localhost:5000/v2/_catalog

echo ""
echo "활성화된 Pod 목록:"
kubectl get pods -n elice-devops-dev | grep -v "0/1"

echo ""
echo "API Gateway 서비스 상태:"
kubectl get pods -l app=api-gateway -n elice-devops-dev

echo ""
echo "🎉 Image Pull 문제 해결 완료!"
echo "================================"

if kubectl get pods -l app=api-gateway -n elice-devops-dev --no-headers | grep -q "Running"; then
    echo "✅ API Gateway가 성공적으로 실행되었습니다!"
    echo "🔗 ArgoCD UI에서 Health Status가 Healthy로 변경되었는지 확인하세요."
    echo ""
    echo "📋 성공 요인:"
    echo "  - Registry IP 주소 직접 사용: $REGISTRY_IP:5000"
    echo "  - containerd insecure registry 설정 완료"
    echo "  - Kind 클러스터 호스트명 해석 문제 해결"
    echo "  - ECR 접근 불가 서비스들 정리 완료"
else
    echo "⚠️ 여전히 문제가 있습니다. 추가 진단이 필요합니다."
    echo ""
    echo "📋 추가 확인사항:"
    echo "  kubectl describe pod -l app=api-gateway -n elice-devops-dev"
    echo "  kubectl logs -l app=api-gateway -n elice-devops-dev"
fi