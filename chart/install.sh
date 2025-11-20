#!/bin/bash
# CTFd Helm Chart Installation Script
# This script helps you install CTFd on OpenShift/Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="ctfd"
RELEASE_NAME="ctfd"
CHART_PATH="./chart"
VALUES_FILE=""
CREATE_NAMESPACE="false"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm 3.x first."
        exit 1
    fi
    
    # Check if kubectl/oc is installed
    if ! command -v kubectl &> /dev/null && ! command -v oc &> /dev/null; then
        print_error "Neither kubectl nor oc is installed. Please install one of them."
        exit 1
    fi
    
    print_info "Prerequisites check passed ✓"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install CTFd using Helm chart

OPTIONS:
    -n, --namespace NAME        Namespace to install CTFd (default: ctfd)
    -r, --release NAME          Helm release name (default: ctfd)
    -f, --values FILE           Path to custom values file
    -c, --create-namespace      Create namespace if it doesn't exist
    -p, --platform PLATFORM     Platform: openshift or kubernetes (auto-detect if not specified)
    -h, --help                  Display this help message

EXAMPLES:
    # Install with defaults
    $0

    # Install in custom namespace with custom values
    $0 -n my-ctfd -f production-values.yaml -c

    # Install with production OpenShift example
    $0 -f chart/examples/production-openshift.yaml -c

    # Install for development
    $0 -f chart/examples/development.yaml -c

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -c|--create-namespace)
            CREATE_NAMESPACE="true"
            shift
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main installation function
main() {
    print_info "CTFd Helm Chart Installation"
    echo "================================"
    
    check_prerequisites
    
    # Detect platform if not specified
    if [ -z "$PLATFORM" ]; then
        if command -v oc &> /dev/null; then
            PLATFORM="openshift"
            print_info "Detected platform: OpenShift"
        else
            PLATFORM="kubernetes"
            print_info "Detected platform: Kubernetes"
        fi
    fi
    
    # Create namespace if requested
    if [ "$CREATE_NAMESPACE" = "true" ]; then
        print_info "Creating namespace: $NAMESPACE"
        if [ "$PLATFORM" = "openshift" ]; then
            oc new-project $NAMESPACE 2>/dev/null || oc project $NAMESPACE
        else
            kubectl create namespace $NAMESPACE 2>/dev/null || true
        fi
    fi
    
    # Build helm install command
    HELM_CMD="helm install $RELEASE_NAME $CHART_PATH --namespace $NAMESPACE"
    
    if [ -n "$VALUES_FILE" ]; then
        if [ ! -f "$VALUES_FILE" ]; then
            print_error "Values file not found: $VALUES_FILE"
            exit 1
        fi
        HELM_CMD="$HELM_CMD --values $VALUES_FILE"
        print_info "Using values file: $VALUES_FILE"
    fi
    
    # Execute helm install
    print_info "Installing CTFd..."
    print_info "Command: $HELM_CMD"
    
    if eval $HELM_CMD; then
        print_info "CTFd installed successfully! ✓"
        echo ""
        
        # Display post-installation information
        print_info "Post-Installation Information"
        echo "================================"
        
        if [ "$PLATFORM" = "openshift" ]; then
            print_info "Getting route URL..."
            sleep 3  # Wait a bit for route to be created
            ROUTE_URL=$(oc get route $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
            if [ -n "$ROUTE_URL" ]; then
                echo ""
                print_info "CTFd is accessible at: https://$ROUTE_URL"
            else
                print_warning "Route not found yet. Run: oc get route $RELEASE_NAME -n $NAMESPACE"
            fi
        else
            print_info "To access CTFd, you can use port-forwarding:"
            echo "  kubectl port-forward svc/$RELEASE_NAME 8000:8000 -n $NAMESPACE"
            echo "  Then access: http://localhost:8000"
        fi
        
        echo ""
        print_info "Check deployment status:"
        echo "  helm status $RELEASE_NAME -n $NAMESPACE"
        echo ""
        print_info "View pods:"
        if [ "$PLATFORM" = "openshift" ]; then
            echo "  oc get pods -n $NAMESPACE"
        else
            echo "  kubectl get pods -n $NAMESPACE"
        fi
        echo ""
        print_info "View logs:"
        if [ "$PLATFORM" = "openshift" ]; then
            echo "  oc logs -f deployment/$RELEASE_NAME -n $NAMESPACE"
        else
            echo "  kubectl logs -f deployment/$RELEASE_NAME -n $NAMESPACE"
        fi
        
    else
        print_error "Installation failed!"
        exit 1
    fi
}

# Run main function
main
