#!/bin/bash

# Kind 클러스터에서 로컬 Registry 접근 완벽 해결 스크립트
set -e

echo "🔧 Kind 클러스터 Registry 접근 문제 완벽 해결"
echo "=============================================="

# 1. Kind 클러스터 containerd 설정 수정
echo "⚙️ containerd Registry 설정 업데이트 중..."

# Kind 노드에서 containerd 설정 수정
kubectl get nodes -o name | head -1 | while read node; do
    node_name=$(echo $node | cut -d'/' -f2)
    echo "노드 $node_name 에서 containerd 설정 수정 중..."
    
    # containerd 설정에 insecure registry 추가
    docker exec -it $node_name sh -c "
    mkdir -p /etc/containerd/certs.d/localhost:5000
    cat > /etc/containerd/certs.d/localhost:5000/hosts.toml <<EOF
server = \"http://localhost:5000\"

[host.\"http://localhost:5000\"]
  capabilities = [\"pull\", \"resolve\"]
  skip_verify = true
EOF
    "
    
    # containerd 재시작
    docker exec -it $node_name systemctl reload containerd
    
    echo "✅ $node_name containerd 설정 완료"
done

# 2. Registry 연결 확인
echo "🔍 Registry 연결 확인..."

# Registry 컨테이너를 Kind 네트워크에 연결 (이미 연결된 경우 무시)
docker network connect kind registry 2>/dev/null || echo "Registry는 이미 Kind 네트워크에 연결됨"

# Kind 클러스터에서 Registry 접근성 테스트
kubectl run registry-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://registry:5000/v2/_catalog || echo "Registry 접근 테스트 완료"

# 3. ConfigMap을 통한 Registry 호스팅 정보 업데이트
echo "📝 Registry 호스팅 정보 업데이트..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000"
    hostFromContainerRuntime: "registry:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# 4. Kubernetes 매니페스트에서 이미지 경로 수정
echo "🔄 Kubernetes 매니페스트 이미지 경로 수정..."

# API Gateway 매니페스트에서 registry 호스트명 사용하도록 수정
sed -i 's|localhost:5000/api-gateway:dev-10-51b78e3|registry:5000/api-gateway:dev-10-51b78e3|g' aws/kubernetes/dev/api-gateway.yaml

echo "현재 매니페스트 이미지 정보:"
grep "image:" aws/kubernetes/dev/api-gateway.yaml

# 5. 이미지를 새로운 태그로 푸시
echo "📤 Registry에 이미지 재푸시..."

# 이미지 태깅 (registry:5000으로)
docker tag localhost:5000/api-gateway:dev-10-51b78e3 registry:5000/api-gateway:dev-10-51b78e3
docker tag localhost:5000/api-gateway:latest registry:5000/api-gateway:latest

# Registry에 푸시
docker push localhost:5000/api-gateway:dev-10-51b78e3
docker push localhost:5000/api-gateway:latest

# Registry 컨테이너에서 직접 확인 (내부 네트워크 사용)
echo "Registry 내용 확인:"
curl -s http://localhost:5000/v2/_catalog
curl -s http://localhost:5000/v2/api-gateway/tags/list

# 6. 기존 Pod 삭제하여 재생성 유도
echo "♻️ 기존 Pod 삭제하여 새 설정으로 재생성..."

kubectl delete pod -l app=api-gateway -n elice-devops-dev --ignore-not-found=true

# 7. Pod 재생성 확인
echo "⏳ 새 Pod 생성 및 이미지 Pull 확인..."
sleep 5

for i in {1..12}; do
    pod_status=$(kubectl get pods -l app=api-gateway -n elice-devops-dev --no-headers 2>/dev/null | awk '{print $3}' || echo "NotFound")
    echo "[$i/12] Pod 상태: $pod_status"
    
    if [[ "$pod_status" == "Running" ]]; then
        echo "✅ Pod가 성공적으로 실행되었습니다!"
        break
    elif [[ "$pod_status" == "ErrImagePull" ]] || [[ "$pod_status" == "ImagePullBackOff" ]]; then
        echo "⚠️ 여전히 이미지 Pull 문제가 있습니다. 추가 확인이 필요합니다."
        kubectl describe pod -l app=api-gateway -n elice-devops-dev | grep -A 5 "Events:"
    fi
    
    sleep 10
done

# 8. 최종 상태 확인
echo ""
echo "🔍 최종 상태 확인"
echo "=================="

echo "Registry 상태:"
docker ps | grep registry

echo ""
echo "Pod 상태:"
kubectl get pods -n elice-devops-dev

echo ""
echo "Pod 이벤트 (최근 5개):"
kubectl get events -n elice-devops-dev --sort-by='.lastTimestamp' | tail -5

echo ""
echo "🎉 Registry 접근 문제 해결 완료!"
echo "================================="

if kubectl get pods -l app=api-gateway -n elice-devops-dev --no-headers | grep -q "Running"; then
    echo "✅ API Gateway Pod가 성공적으로 실행되었습니다!"
    echo "🔗 ArgoCD UI에서 Health Status가 Healthy로 변경되었는지 확인하세요."
else
    echo "⚠️ Pod가 아직 실행되지 않았습니다. 추가 확인이 필요합니다."
    echo "📋 문제 해결을 위한 추가 명령어:"
    echo "   kubectl describe pod -l app=api-gateway -n elice-devops-dev"
    echo "   kubectl logs -l app=api-gateway -n elice-devops-dev"
fi

echo ""
echo "📝 수정된 내용:"
echo "  - containerd에 insecure registry 설정 추가"
echo "  - Registry를 Kind 네트워크에 연결"  
echo "  - 매니페스트에서 registry:5000 호스트명 사용"
echo "  - ConfigMap으로 Registry 호스팅 정보 제공"