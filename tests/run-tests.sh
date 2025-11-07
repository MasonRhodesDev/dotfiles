#!/bin/bash
# Main test runner for chezmoi dotfiles
# Runs tests in Docker containers for Fedora and Arch Linux

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMEOUT=${TIMEOUT:-1800}  # 30 minutes default

# Create results directory
mkdir -p "$RESULTS_DIR"

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [DISTRO] [SCENARIO]

Run automated tests for chezmoi dotfiles in Docker containers.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Verbose output
    -k, --keep          Keep containers after tests
    --no-cache          Build containers without cache

DISTRO:
    fedora              Test on Fedora 41 (work profile)
    arch                Test on Arch Linux (personal profile)
    all                 Test on both (default)

SCENARIO:
    basic-install       Basic installation test
    state-tracking      State persistence test
    profile-detection   Profile detection test
    service-validation  Service unit file validation test
    all                 All scenarios (default)

EXAMPLES:
    $0                              # Run all tests on both distros
    $0 fedora                       # Run all tests on Fedora
    $0 fedora basic-install         # Run basic install test on Fedora
    $0 --no-cache arch              # Rebuild Arch container and test

EOF
    exit 0
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Check if Docker/Podman is available
check_container_runtime() {
    if command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
        log_info "Using Docker"
    elif command -v podman &> /dev/null; then
        CONTAINER_CMD="podman"
        log_info "Using Podman"
    else
        log_error "Neither Docker nor Podman found. Please install one of them."
        exit 1
    fi
}

# Build container image
build_container() {
    local distro="$1"
    local no_cache="${2:-false}"

    log_info "Building $distro test container..."

    local build_opts=""
    if [ "$no_cache" = "true" ]; then
        build_opts="--no-cache"
    fi

    if $CONTAINER_CMD build $build_opts \
        -f "$SCRIPT_DIR/Dockerfile.$distro" \
        -t "chezmoi-test-$distro" \
        "$REPO_ROOT" 2>&1 | tee "$RESULTS_DIR/build-$distro.log"; then
        log_success "Container built: chezmoi-test-$distro"
        return 0
    else
        log_error "Failed to build $distro container"
        return 1
    fi
}

# Run test scenario in container
run_test() {
    local distro="$1"
    local scenario="$2"
    local keep_container="${3:-false}"

    local container_name="chezmoi-test-${distro}-${scenario}-$$"
    local result_file="$RESULTS_DIR/${distro}-${scenario}-$(date +%Y%m%d-%H%M%S).log"

    log_info "Running test: $scenario on $distro"

    # Run container with test scenario
    local run_opts="--rm"
    if [ "$keep_container" = "true" ]; then
        run_opts="--name $container_name"
    fi

    if $CONTAINER_CMD run $run_opts \
        -v "$SCRIPT_DIR/scenarios:/tests:ro,Z" \
        "chezmoi-test-$distro" \
        bash /tests/${scenario}.sh 2>&1 | tee "$result_file"; then

        log_success "Test passed: $scenario on $distro"
        echo "  Results: $result_file"
        return 0
    else
        log_error "Test failed: $scenario on $distro"
        echo "  Results: $result_file"
        return 1
    fi
}

# Run all scenarios for a distro
run_distro_tests() {
    local distro="$1"
    local scenarios=("$@")
    shift  # Remove distro from array

    local failed=0
    local passed=0

    for scenario in "${scenarios[@]}"; do
        if run_test "$distro" "$scenario" "$KEEP_CONTAINERS"; then
            ((passed++))
        else
            ((failed++))
        fi
        echo ""
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Results for $distro:"
    echo "    Passed: $passed"
    echo "    Failed: $failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return $failed
}

# Main function
main() {
    local distros=()
    local scenarios=()
    local no_cache=false
    KEEP_CONTAINERS=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -k|--keep)
                KEEP_CONTAINERS=true
                shift
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            fedora|arch)
                distros+=("$1")
                shift
                ;;
            all)
                if [ ${#distros[@]} -eq 0 ]; then
                    distros=("fedora" "arch")
                fi
                shift
                ;;
            basic-install|state-tracking|profile-detection|service-validation)
                scenarios+=("$1")
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                ;;
        esac
    done

    # Set defaults
    if [ ${#distros[@]} -eq 0 ]; then
        distros=("fedora" "arch")
    fi

    if [ ${#scenarios[@]} -eq 0 ]; then
        scenarios=("basic-install" "state-tracking" "profile-detection" "service-validation")
    fi

    # Check container runtime
    check_container_runtime

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Chezmoi Dotfiles Test Suite"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Distributions: ${distros[*]}"
    echo "  Scenarios: ${scenarios[*]}"
    echo "  Results: $RESULTS_DIR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local total_failed=0

    # Build and test each distro
    for distro in "${distros[@]}"; do
        log_info "Testing distribution: $distro"
        echo ""

        # Build container
        if ! build_container "$distro" "$no_cache"; then
            log_error "Skipping $distro tests due to build failure"
            ((total_failed++))
            continue
        fi

        echo ""

        # Run tests
        if ! run_distro_tests "$distro" "${scenarios[@]}"; then
            ((total_failed++))
        fi
    done

    # Final summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ $total_failed -eq 0 ]; then
        log_success "All tests passed!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    else
        log_error "$total_failed distribution(s) had test failures"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 1
    fi
}

main "$@"
