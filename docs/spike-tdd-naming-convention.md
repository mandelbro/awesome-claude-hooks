# Spike: TDD Naming-Convention Matcher Design

## Problem

The TDD reminder hook currently classifies files as "test" vs "source" using path-based heuristics (`*test*`, `*spec*`, `*/tests/*`). This is coarse and misses language-specific conventions. A naming-convention matcher would let the hook verify whether a _specific_ source file has a corresponding test file in the tracker window.

## Convention Map

### Python
| Source | Test |
|--------|------|
| `src/auth/middleware.py` | `tests/test_middleware.py` |
| `src/auth/middleware.py` | `tests/auth/test_middleware.py` |
| `src/auth/middleware.py` | `tests/middleware_test.py` |

Pattern: `test_{stem}.py` or `{stem}_test.py` in a `tests/` tree.

### TypeScript / JavaScript
| Source | Test |
|--------|------|
| `src/utils/helpers.ts` | `src/utils/helpers.test.ts` |
| `src/utils/helpers.ts` | `src/utils/__tests__/helpers.test.ts` |
| `src/utils/helpers.tsx` | `src/utils/helpers.spec.tsx` |

Pattern: `{stem}.test.{ext}` or `{stem}.spec.{ext}`, colocated or in `__tests__/`.

### Ruby
| Source | Test |
|--------|------|
| `app/models/user.rb` | `spec/models/user_spec.rb` |
| `lib/auth/token.rb` | `spec/lib/auth/token_spec.rb` |

Pattern: `{stem}_spec.rb` under `spec/` mirroring `app/` or `lib/` structure.

### Go
| Source | Test |
|--------|------|
| `pkg/auth/handler.go` | `pkg/auth/handler_test.go` |

Pattern: `{stem}_test.go` in the same directory. Always colocated.

## Matching Algorithm (Pseudocode)

```
function find_matching_test(source_path, test_paths):
    lang = detect_language(source_path)
    stem = basename_without_ext(source_path)
    ext  = extension(source_path)

    # Build candidate patterns based on language
    candidates = []
    if lang == "python":
        candidates = ["test_{stem}.py", "{stem}_test.py"]
    elif lang in ["typescript", "javascript"]:
        candidates = ["{stem}.test.{ext}", "{stem}.spec.{ext}"]
    elif lang == "ruby":
        candidates = ["{stem}_spec.rb"]
    elif lang == "go":
        candidates = ["{stem}_test.go"]

    # Check each test_path for a basename match
    for test_path in test_paths:
        test_base = basename(test_path)
        if test_base in candidates:
            return test_path  # match found

    return null  # no matching test
```

## Ambiguity Resolution

1. **Multiple matches**: If several test files match one source file (e.g., `test_helpers.py` and `helpers_test.py` both exist), accept any match as valid.
2. **Nested paths**: Ignore directory structure for matching; only compare basenames. Directory-aware matching adds complexity for minimal gain in a reminder hook.
3. **Extension variants**: `.ts` vs `.tsx`, `.js` vs `.jsx` — treat as equivalent for matching purposes (a `.test.ts` file covers a `.tsx` source).
4. **Monorepo overlap**: Two packages could have the same filename. Since the tracker only records files touched in one session, cross-package false positives are unlikely.

## Configuration Proposal

Add an optional config file at `.claude/tdd-conventions.json`:

```json
{
  "conventions": {
    "python": {
      "test_patterns": ["test_{stem}.py", "{stem}_test.py"],
      "test_dirs": ["tests/", "test/"]
    },
    "typescript": {
      "test_patterns": ["{stem}.test.{ext}", "{stem}.spec.{ext}"],
      "test_dirs": ["__tests__/"]
    }
  },
  "ignore_paths": ["scripts/", "migrations/"]
}
```

The hook would load this at runtime if present, falling back to built-in defaults. This keeps zero-config behavior while allowing project-specific overrides.

## Scope and Limitations

### In scope
- Basename-level matching between source and test files in the tracker window
- Language detection from file extension
- Built-in conventions for Python, TypeScript/JS, Ruby, Go
- Optional config file override

### Out of scope
- Verifying test _content_ (that the test actually covers the source)
- Suggesting where to create a missing test file
- Cross-language test detection (e.g., a Python source with a shell test)
- IDE integration or LSP-level analysis

### Known limitations
- Basename-only matching can produce false positives for common names (`utils`, `helpers`)
- Cannot detect test files that use non-standard naming (e.g., `verify_auth.py`)
- Config file adds maintenance burden; most projects should work with defaults

## Implementation Estimate

| Component | Effort |
|-----------|--------|
| Language detection function | 1 point |
| Pattern matching function | 2 points |
| Config file loading (optional) | 2 points |
| Integration into tdd-reminder.sh | 1 point |
| Tests for matcher | 2 points |
| **Total** | **8 points** |

Estimated calendar time: 1-2 sessions.

## Recommendation

**Simplify and defer.**

The current path-based classification (`*test*`, `*spec*`) already catches the majority of cases. The naming-convention matcher adds value only when:
- A developer edits a source file but the _wrong_ test file (unrelated) was also edited
- A project uses unusual test locations

Both are edge cases. The recommendation is:
1. **Now**: Keep the current classifier as-is (it works for 90%+ of projects).
2. **Next phase**: Implement the basename matcher as a standalone function in `lib/common.sh` without the config file (saves 2 points). Use it in `tdd-reminder.sh` to produce more specific messages ("No test found for `middleware.py`" instead of generic "no test files touched").
3. **Later**: Add config file support only if users request project-specific overrides.

This defers 8 points of work to ~4 points of targeted improvement.
