#!/bin/bash
# =============================================================================
# Promptfoo Test Runner Script
# =============================================================================
# Usage: ./run_tests.sh [command]
# Commands:
#   eval      - Run standard evaluation with guardrails
#   redteam   - Run red team adversarial testing
#   all       - Run both evaluations
#   view      - Open results in web browser
#   generate  - Generate red team tests without running
#   help      - Show this help message
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$SCRIPT_DIR"

# Load environment variables from parent directory's .env first
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${BLUE}Loading environment variables from project root .env${NC}"
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | grep -v '^$' | xargs)
fi

# Then load from local .env if it exists (for overrides)
if [ -f .env ]; then
    echo -e "${BLUE}Loading environment variables from promptfoo/.env (overrides)${NC}"
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
fi

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}Error: Node.js is not installed. Please install Node.js v18+${NC}"
        exit 1
    fi

    # Check Promptfoo
    if ! command -v promptfoo &> /dev/null; then
        echo -e "${YELLOW}Promptfoo not found. Installing...${NC}"
        npm install -g promptfoo
    fi

    # Check Python dependencies
    if ! python3 -c "import httpx" &> /dev/null; then
        echo -e "${YELLOW}Python dependencies not found. Installing...${NC}"
        pip install -r requirements.txt
    fi

    # Check required environment variables
    if [ -z "$AZURE_OPENAI_API_KEY" ]; then
        echo -e "${RED}Error: AZURE_OPENAI_API_KEY is not set${NC}"
        echo "Please set it in your .env file"
        exit 1
    fi

    # Check RAG_FILE_ID
    if [ -z "$RAG_FILE_ID" ]; then
        echo -e "${YELLOW}Warning: RAG_FILE_ID is not set${NC}"
        echo "Add RAG_FILE_ID=your-file-id to your .env file"
        echo "Using empty file_id - tests may not retrieve documents"
    fi

    # Check RAG API availability
    RAG_URL="${RAG_API_URL:-http://localhost:8000}"
    if ! curl -s "${RAG_URL}/health" > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: RAG API at ${RAG_URL} is not responding${NC}"
        echo "Make sure your RAG application is running before running tests"
    else
        echo -e "${GREEN}RAG API is available at ${RAG_URL}${NC}"
    fi

    echo -e "${GREEN}Prerequisites check passed!${NC}"
}

# Run standard evaluation
run_eval() {
    echo -e "${BLUE}Running standard evaluation with guardrails...${NC}"
    echo ""
    promptfoo eval -c promptfoo.yaml --output ./results/eval-results.json
    echo ""
    echo -e "${GREEN}Evaluation complete! Results saved to ./results/eval-results.json${NC}"
}

# Run red team evaluation
run_redteam() {
    echo -e "${RED}Running red team adversarial testing...${NC}"
    echo -e "${YELLOW}This may take several minutes depending on the number of tests configured.${NC}"
    echo ""
    promptfoo redteam run -c promptfoo.yaml --output ./results/redteam-results.json
    echo ""
    echo -e "${GREEN}Red team evaluation complete! Results saved to ./results/redteam-results.json${NC}"
}

# Generate red team tests without running
generate_redteam() {
    echo -e "${BLUE}Generating red team test cases...${NC}"
    promptfoo redteam generate -c promptfoo.yaml --output ./results/generated-tests.yaml
    echo ""
    echo -e "${GREEN}Tests generated! Review them at ./results/generated-tests.yaml${NC}"
}

# Run all evaluations
run_all() {
    check_prerequisites
    run_eval
    echo ""
    echo "---"
    echo ""
    run_redteam
    echo ""
    echo -e "${GREEN}All evaluations complete!${NC}"
    echo "View results with: $0 view"
}

# Open results viewer
view_results() {
    echo -e "${BLUE}Opening Promptfoo results viewer...${NC}"
    promptfoo view
}

# Show help
show_help() {
    echo "Promptfoo Test Runner for RAG Application"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  eval      Run standard evaluation with guardrails"
    echo "  redteam   Run red team adversarial testing"
    echo "  all       Run both evaluations"
    echo "  view      Open results in web browser"
    echo "  generate  Generate red team tests without running"
    echo "  check     Check prerequisites only"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 eval          # Run guardrail tests"
    echo "  $0 redteam       # Run security tests"
    echo "  $0 all           # Run everything"
    echo ""
    echo "Environment Variables (from .env):"
    echo "  AZURE_OPENAI_API_KEY           Azure OpenAI API key (required)"
    echo "  AZURE_OPENAI_ENDPOINT          Azure endpoint URL"
    echo "  AZURE_OPENAI_DEPLOYMENT        Model deployment name"
    echo "  RAG_AZURE_OPENAI_API_VERSION   API version"
    echo "  RAG_FILE_ID                    Document file ID to test"
    echo "  RAG_API_URL                    Local RAG API URL (default: http://localhost:8000)"
}

# Main
case "${1:-help}" in
    eval)
        check_prerequisites
        run_eval
        ;;
    redteam)
        check_prerequisites
        run_redteam
        ;;
    all)
        run_all
        ;;
    view)
        view_results
        ;;
    generate)
        check_prerequisites
        generate_redteam
        ;;
    check)
        check_prerequisites
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
