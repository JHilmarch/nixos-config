______________________________________________________________________

## name: hybrid_code_search_ck description: Use ck to search code by meaning, keyword, hybrid matching, or regex. Best for locating concepts, symbols, TODOs, and implementation patterns across a codebase.

# Hybrid Code Search with ck

Use `ck` for finding code by meaning, not just keywords.

## Search Modes

- `ck --sem "concept"` - Semantic search (by meaning)
- `ck --lex "keyword"` - Lexical search (full-text)
- `ck --hybrid "query"` - Combined regex + semantic
- `ck --regex "pattern"` - Traditional regex search

## Best Practices

1. **Index once per session**: Run `ck --index .` at project start
1. **Use semantic for concepts**: "error handling", "database queries"
1. **Use lexical for names**: "getUserById", "AuthController"
1. **Use hybrid for best results**: Combines both approaches
1. **Tune threshold**: `--threshold 0.7` for high-confidence results
1. **Limit results**: `--limit 20` for focused output
