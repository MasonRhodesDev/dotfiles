export PATH="$HOME/.claude/local:$PATH"

# Git commit with Claude-generated message
git-claudmit() {
    # Parse flags
    local prepare_only=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--prepare)
                prepare_only=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: git-claudmit [-p|--prepare]"
                return 1
                ;;
        esac
    done

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi

    # Check if there are staged files
    if ! git diff --cached --quiet 2>/dev/null; then
        # Get staged diff
        local staged_diff=$(git diff --cached)
        local git_dir=$(git rev-parse --git-dir)

        # Generate commit message using Claude
        echo "Generating commit message..."
        local commit_msg=$(claude -p "Analyze these git changes and create a Conventional Commits message.

Format requirements (https://www.conventionalcommits.org/en/v1.0.0/):

<type>[optional !]: <description>

[optional body]

[optional footer(s)]

Rules:
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- NO scope (no parentheses after type)
- Description: imperative mood, lowercase, no period, max 72 chars
- Body: wrap at 72 chars, explain WHY and contrast with previous behavior
- Footer: reference issues or breaking changes
- Use '!' after type OR 'BREAKING CHANGE:' footer for breaking changes

CRITICAL: Output ONLY the commit message. No analysis, explanations, markdown formatting, code blocks, backticks, or extra text. Just the raw commit message that will be passed directly to 'git commit -m'.

Changes:
${staged_diff}")

        # Show commit message
        echo ""
        echo "Commit message:"
        echo "---"
        echo -e "\033[36m${commit_msg}\033[0m"
        echo "---"
        echo ""

        if $prepare_only; then
            # Write message to COMMIT_EDITMSG and open editor
            echo "$commit_msg" > "$git_dir/COMMIT_EDITMSG"
            echo -e "\033[32mOpening editor to finalize commit message...\033[0m"
            echo ""
            git commit -e
        else
            # Normal commit flow with confirmation
            read -p "Commit with this message? (y/n): " -n 1 confirm
            echo ""

            if [[ $confirm =~ ^[Yy]$ ]]; then
                git commit -m "$commit_msg"
            else
                echo "Commit cancelled"
                return 1
            fi
        fi
    else
        echo "Error: No staged files to commit"
        return 1
    fi
}