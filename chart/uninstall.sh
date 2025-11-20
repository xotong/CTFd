#!/bin/bash
# CTFd Helm Chart Uninstallation Script
# This script helps you safely uninstall CTFd from OpenShift/Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="ctfd"
RELEASE_NAME="ctfd"
DELETE_PVC="false"
DELETE_NAMESPACE="false"
CONFIRM="false"

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

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Uninstall CTFd Helm release

OPTIONS:
    -n, --namespace NAME        Namespace where CTFd is installed (default: ctfd)
    -r, --release NAME          Helm release name (default: ctfd)
    --delete-pvc                Also delete PersistentVolumeClaims (THIS WILL DELETE DATA!)
    --delete-namespace          Also delete the namespace
    -y, --yes                   Skip confirmation prompts
    -h, --help                  Display this help message

EXAMPLES:
    # Uninstall CTFd (keeps PVCs and namespace)
    $0

    # Uninstall and delete PVCs (WARNING: deletes data!)
    $0 --delete-pvc -y

    # Complete cleanup including namespace
    $0 --delete-pvc --delete-namespace -y

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
        --delete-pvc)
            DELETE_PVC="true"
            shift
            ;;
        --delete-namespace)
            DELETE_NAMESPACE="true"
            shift
            ;;
        -y|--yes)
            CONFIRM="true"
            shift
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

# Function to confirm action
confirm_action() {
    if [ "$CONFIRM" = "true" ]; then
        return 0
    fi
    
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
}

# Main uninstallation function
main() {
    print_info "CTFd Helm Chart Uninstallation"
    echo "================================"
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed."
        exit 1
    fi
    
    # Detect CLI tool
    if command -v oc &> /dev/null; then
        CLI="oc"
        PLATFORM="OpenShift"
    elif command -v kubectl &> /dev/null; then
        CLI="kubectl"
        PLATFORM="Kubernetes"
    else
        print_error "Neither kubectl nor oc is installed."
        exit 1
    fi
    
    print_info "Platform: $PLATFORM"
    print_info "Release: $RELEASE_NAME"
    print_info "Namespace: $NAMESPACE"
    
    # Check if release exists
    if ! helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        print_error "Release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
        exit 1
    fi
    
    # Display what will be deleted
    echo ""
    print_warning "The following will be removed:"
    echo "  - Helm release: $RELEASE_NAME"
    echo "  - CTFd deployment and pods"
    echo "  - MariaDB StatefulSet (if enabled)"
    echo "  - Redis StatefulSet (if enabled)"
    echo "  - Services, Routes, ConfigMaps, Secrets"
    
    if [ "$DELETE_PVC" = "true" ]; then
        print_warning "  - PersistentVolumeClaims (ALL DATA WILL BE LOST!)"
    else
        print_info "  - PersistentVolumeClaims will be kept"
    fi
    
    if [ "$DELETE_NAMESPACE" = "true" ]; then
        print_warning "  - Namespace: $NAMESPACE"
    fi
    
    echo ""
    confirm_action "Do you want to proceed with uninstallation?"
    
    # Uninstall Helm release
    print_info "Uninstalling Helm release..."
    if helm uninstall $RELEASE_NAME -n $NAMESPACE; then
        print_info "Helm release uninstalled successfully ✓"
    else
        print_error "Failed to uninstall Helm release"
        exit 1
    fi
    
    # Wait a bit for resources to be cleaned up
    sleep 3
    
    # Delete PVCs if requested
    if [ "$DELETE_PVC" = "true" ]; then
        print_warning "Deleting PersistentVolumeClaims..."
        
        # List PVCs
        PVCS=$($CLI get pvc -n $NAMESPACE -l "app.kubernetes.io/instance=$RELEASE_NAME" -o name 2>/dev/null || true)
        
        if [ -n "$PVCS" ]; then
            echo "$PVCS"
            confirm_action "Delete these PVCs? (THIS WILL DELETE ALL DATA!)"
            
            for pvc in $PVCS; do
                print_info "Deleting $pvc..."
                $CLI delete $pvc -n $NAMESPACE
            done
            
            # Also delete standalone PVCs
            $CLI delete pvc -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE 2>/dev/null || true
            
            print_info "PVCs deleted ✓"
        else
            print_info "No PVCs found for release $RELEASE_NAME"
        fi
    else
        print_info "PVCs retained. To delete them manually, run:"
        echo "  $CLI delete pvc -l \"app.kubernetes.io/instance=$RELEASE_NAME\" -n $NAMESPACE"
    fi
    
    # Delete namespace if requested
    if [ "$DELETE_NAMESPACE" = "true" ]; then
        print_warning "Deleting namespace..."
        confirm_action "Delete namespace $NAMESPACE? (This will delete everything in the namespace!)"
        
        if $CLI delete namespace $NAMESPACE; then
            print_info "Namespace deleted ✓"
        else
            print_error "Failed to delete namespace"
            exit 1
        fi
    fi
    
    echo ""
    print_info "Uninstallation complete! ✓"
    
    # Show remaining resources if namespace still exists
    if [ "$DELETE_NAMESPACE" != "true" ]; then
        echo ""
        print_info "Remaining resources in namespace $NAMESPACE:"
        $CLI get all,pvc -n $NAMESPACE 2>/dev/null || print_info "No resources found"
    fi
}

# Run main function
main
