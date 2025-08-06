#!/bin/bash

# Elice DevOps Health Check Script
# Usage: ./health-check.sh [environment] [--verbose]

set -e

ENVIRONMENT=${1:-"dev"}
VERBOSE=${2:-""}
NAMESPACE="elice-devops-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

verbose_log() {
    if [[ "$VERBOSE" == "--verbose" ]]; then
        echo -e "${NC}[DEBUG] $1"
    fi
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Kubernetes cluster connection verified"
}

# Check namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    log_success "Namespace '$NAMESPACE' exists"
}

# Check pod status
check_pods() {
    log_info "Checking pod status in namespace '$NAMESPACE'..."
    
    local total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    local running_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l)
    local pending_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Pending --no-headers | wc -l)
    local failed_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Failed --no-headers | wc -l)
    
    verbose_log "Total pods: $total_pods"
    verbose_log "Running pods: $running_pods"
    verbose_log "Pending pods: $pending_pods"
    verbose_log "Failed pods: $failed_pods"
    
    if [[ $failed_pods -gt 0 ]]; then
        log_error "$failed_pods pods are in failed state"
        kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Failed
        return 1
    fi
    
    if [[ $pending_pods -gt 0 ]]; then
        log_warning "$pending_pods pods are pending"
        kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Pending
    fi
    
    if [[ $running_pods -eq $total_pods ]]; then
        log_success "All $total_pods pods are running"
    else
        log_warning "$running_pods out of $total_pods pods are running"
    fi
}

# Check service endpoints
check_services() {
    log_info "Checking service endpoints..."
    
    local services=("api-gateway" "auth-service" "user-service")
    
    for service in "${services[@]}"; do
        if kubectl get service "$service" -n "$NAMESPACE" &> /dev/null; then
            local endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
            
            if [[ $endpoints -gt 0 ]]; then
                log_success "Service '$service' has $endpoints endpoint(s)"
                verbose_log "Endpoints: $(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}')"
            else
                log_error "Service '$service' has no endpoints"
                return 1
            fi
        else
            log_warning "Service '$service' not found (may not be deployed in this environment)"
        fi
    done
}

# Check resource usage
check_resources() {
    log_info "Checking resource usage..."
    
    # Check if metrics-server is available
    if ! kubectl top nodes &> /dev/null; then
        log_warning "Metrics server not available, skipping resource checks"
        return 0
    fi
    
    # Node resource usage
    log_info "Node resource usage:"
    kubectl top nodes
    
    # Pod resource usage
    log_info "Top 5 pods by CPU usage:"
    kubectl top pods -n "$NAMESPACE" --sort-by=cpu | head -6
    
    log_info "Top 5 pods by memory usage:"
    kubectl top pods -n "$NAMESPACE" --sort-by=memory | head -6
    
    # Check for pods with high resource usage
    local high_cpu_pods=$(kubectl top pods -n "$NAMESPACE" --no-headers | awk '$2 ~ /^[5-9][0-9][0-9]m|^[1-9][0-9][0-9][0-9]m/ {print $1}')
    local high_memory_pods=$(kubectl top pods -n "$NAMESPACE" --no-headers | awk '$3 ~ /^[1-9][0-9][0-9]Mi|^[1-9]Gi/ {print $1}')
    
    if [[ -n "$high_cpu_pods" ]]; then
        log_warning "Pods with high CPU usage detected: $high_cpu_pods"
    fi
    
    if [[ -n "$high_memory_pods" ]]; then
        log_warning "Pods with high memory usage detected: $high_memory_pods"
    fi
}

# Health check HTTP endpoints
check_health_endpoints() {
    log_info "Checking health endpoints..."
    
    local services=("api-gateway")
    
    for service in "${services[@]}"; do
        if kubectl get service "$service" -n "$NAMESPACE" &> /dev/null; then
            local port=$(kubectl get service "$service" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
            
            verbose_log "Port-forwarding $service:$port for health check"
            
            # Start port-forward in background
            kubectl port-forward "service/$service" "$port:$port" -n "$NAMESPACE" &> /dev/null &
            local pf_pid=$!
            
            # Wait a moment for port-forward to establish
            sleep 2
            
            # Check health endpoint
            if curl -f -s "http://localhost:$port/health" &> /dev/null; then
                log_success "Health endpoint for '$service' is responding"
            else
                log_error "Health endpoint for '$service' is not responding"
                kill $pf_pid 2> /dev/null
                return 1
            fi
            
            # Clean up port-forward
            kill $pf_pid 2> /dev/null
        fi
    done
}

# Check database connectivity
check_database() {
    log_info "Checking database connectivity..."
    
    # Look for postgres pods
    local postgres_pods=$(kubectl get pods -n "$NAMESPACE" -l app=postgresql --no-headers | wc -l)
    
    if [[ $postgres_pods -eq 0 ]]; then
        log_warning "No PostgreSQL pods found in namespace '$NAMESPACE'"
        return 0
    fi
    
    local postgres_pod=$(kubectl get pods -n "$NAMESPACE" -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
    
    if kubectl exec -n "$NAMESPACE" "$postgres_pod" -- pg_isready &> /dev/null; then
        log_success "Database is accepting connections"
    else
        log_error "Database is not accepting connections"
        return 1
    fi
    
    # Check database stats if possible
    if kubectl exec -n "$NAMESPACE" "$postgres_pod" -- psql -c "SELECT datname, numbackends FROM pg_stat_database WHERE datname NOT IN ('template0', 'template1', 'postgres');" &> /dev/null; then
        verbose_log "Database connection stats:"
        kubectl exec -n "$NAMESPACE" "$postgres_pod" -- psql -c "SELECT datname, numbackends FROM pg_stat_database WHERE datname NOT IN ('template0', 'template1', 'postgres');"
    fi
}

# Check Redis connectivity
check_redis() {
    log_info "Checking Redis connectivity..."
    
    local redis_pods=$(kubectl get pods -n "$NAMESPACE" -l app=redis --no-headers | wc -l)
    
    if [[ $redis_pods -eq 0 ]]; then
        log_warning "No Redis pods found in namespace '$NAMESPACE'"
        return 0
    fi
    
    local redis_pod=$(kubectl get pods -n "$NAMESPACE" -l app=redis -o jsonpath='{.items[0].metadata.name}')
    
    if kubectl exec -n "$NAMESPACE" "$redis_pod" -- redis-cli ping | grep -q PONG; then
        log_success "Redis is responding to ping"
    else
        log_error "Redis is not responding to ping"
        return 1
    fi
    
    # Check Redis info
    if [[ "$VERBOSE" == "--verbose" ]]; then
        verbose_log "Redis info:"
        kubectl exec -n "$NAMESPACE" "$redis_pod" -- redis-cli info memory | head -5
    fi
}

# Check persistent volumes
check_storage() {
    log_info "Checking persistent volumes..."
    
    local pvcs=$(kubectl get pvc -n "$NAMESPACE" --no-headers | wc -l)
    
    if [[ $pvcs -eq 0 ]]; then
        log_info "No persistent volume claims found"
        return 0
    fi
    
    log_info "Found $pvcs persistent volume claim(s)"
    
    # Check PVC status
    local bound_pvcs=$(kubectl get pvc -n "$NAMESPACE" --no-headers | grep Bound | wc -l)
    local pending_pvcs=$(kubectl get pvc -n "$NAMESPACE" --no-headers | grep Pending | wc -l)
    
    if [[ $pending_pvcs -gt 0 ]]; then
        log_error "$pending_pvcs PVC(s) are in pending state"
        kubectl get pvc -n "$NAMESPACE" | grep Pending
        return 1
    fi
    
    if [[ $bound_pvcs -eq $pvcs ]]; then
        log_success "All $pvcs PVC(s) are bound"
    fi
    
    if [[ "$VERBOSE" == "--verbose" ]]; then
        verbose_log "PVC details:"
        kubectl get pvc -n "$NAMESPACE"
    fi
}

# Check ingress
check_ingress() {
    log_info "Checking ingress configuration..."
    
    local ingresses=$(kubectl get ingress -n "$NAMESPACE" --no-headers | wc -l)
    
    if [[ $ingresses -eq 0 ]]; then
        log_info "No ingress resources found"
        return 0
    fi
    
    log_info "Found $ingresses ingress resource(s)"
    
    if [[ "$VERBOSE" == "--verbose" ]]; then
        verbose_log "Ingress details:"
        kubectl get ingress -n "$NAMESPACE"
    fi
}

# Main health check function
main() {
    log_info "Starting health check for environment: $ENVIRONMENT"
    echo "=================================================="
    
    local exit_code=0
    
    # Run all checks
    check_kubectl || exit_code=1
    check_namespace || exit_code=1
    check_pods || exit_code=1
    check_services || exit_code=1
    check_resources || true  # Don't fail on resource checks
    check_health_endpoints || exit_code=1
    check_database || exit_code=1
    check_redis || true  # Don't fail if Redis is not present
    check_storage || exit_code=1
    check_ingress || true  # Don't fail on ingress checks
    
    echo "=================================================="
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Health check completed successfully for environment: $ENVIRONMENT"
    else
        log_error "Health check failed for environment: $ENVIRONMENT"
    fi
    
    exit $exit_code
}

# Show usage
usage() {
    echo "Usage: $0 [environment] [--verbose]"
    echo ""
    echo "Arguments:"
    echo "  environment    Target environment (dev, stg, prod) [default: dev]"
    echo "  --verbose      Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  $0                    # Check dev environment"
    echo "  $0 prod               # Check prod environment"
    echo "  $0 stg --verbose      # Check staging with verbose output"
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main