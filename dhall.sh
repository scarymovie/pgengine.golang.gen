#!/bin/bash
# Helper script for running Dhall commands via Docker

DHALL_IMAGE="dhallhaskell/dhall:latest"

# Run dhall command with current directory mounted
dhall_run() {
    docker run --rm -v "$PWD:/work" -w /work "$DHALL_IMAGE" dhall "$@"
}

case "$1" in
    type)
        # Type check a Dhall file
        shift
        dhall_run type --file "$@"
        ;;
    format)
        # Format Dhall files
        shift
        dhall_run format --inplace "$@"
        ;;
    check)
        # Check syntax of a Dhall file
        shift
        dhall_run --file "$@"
        ;;
    freeze)
        # Freeze imports in a Dhall file
        shift
        dhall_run freeze --inplace "$@"
        ;;
    lint)
        # Lint a Dhall file
        shift
        dhall_run lint --inplace "$@"
        ;;
    validate-all)
        # Validate all Dhall files in the project
        echo "Validating Dhall files..."
        for file in gen/**/*.dhall; do
            echo "Checking $file..."
            dhall_run type --file "$file" || exit 1
        done
        echo "✅ All Dhall files are valid"
        ;;
    *)
        echo "Usage: $0 {type|format|check|freeze|lint|validate-all} [file]"
        echo ""
        echo "Commands:"
        echo "  type <file>       - Type check a Dhall file"
        echo "  format <file>     - Format a Dhall file"
        echo "  check <file>      - Check syntax of a Dhall file"
        echo "  freeze <file>     - Freeze imports in a Dhall file"
        echo "  lint <file>       - Lint a Dhall file"
        echo "  validate-all      - Validate all Dhall files in gen/"
        echo ""
        echo "Examples:"
        echo "  $0 type gen/Config.dhall"
        echo "  $0 format gen/**/*.dhall"
        echo "  $0 validate-all"
        exit 1
        ;;
esac
