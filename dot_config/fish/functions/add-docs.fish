function add-docs -d "Add documentation site to MCPDocSearch"
    if test (count $argv) -eq 0
        echo "Usage: add-docs <url>"
        echo "Example: add-docs https://example.com/docs"
        return 1
    end

    set url $argv[1]
    set old_pwd (pwd)
    cd /home/mason/MCPDocSearch

    echo "📚 Current documentation sites:"
    if test -d storage; and test (count storage/*.md) -gt 0
        ls storage/*.md 2>/dev/null | sed 's|storage/||g; s|\.md||g' | nl
    else
        echo "  (none yet)"
    end
    echo

    # Extract domain from URL
    set domain (echo $url | sed -E 's|https?://([^/]+).*|\1|')
    set existing_file "storage/$domain.md"

    if test -f $existing_file
        echo "⚠️  Documentation for $domain already exists."
        echo "   File: $existing_file"
        echo "   Continue anyway? (This will overwrite existing content)"
        read -P "   [y/N]: " -n 1 response
        echo
        if not string match -qi 'y' $response
            echo "❌ Crawl cancelled."
            cd $old_pwd
            return 1
        end
    end

    echo "🕷️  Crawling documentation from: $url"
    /home/mason/.local/bin/uv run python crawl.py $url

    if test $status -eq 0
        echo "✅ Documentation crawled and indexed successfully!"
        echo "🔄 Restart Claude Code to refresh the MCP server with new documents."
    else
        echo "❌ Crawl failed. Check the error messages above."
        cd $old_pwd
        return 1
    end

    cd $old_pwd
end
