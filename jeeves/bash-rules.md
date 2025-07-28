# Ted's Bash Programming Style

When writing bash scripts, follow these principles learned from Ted's coding style:

## Safe Expansion Foundation
- Always use: `set -eu; set -o noglob; IFS=$'\n'`
- This eliminates word-splitting disasters and allows cleaner code with fewer quotes

## Semantic Quoting Convention
- Variables ending with `_` (underscore) MUST be quoted - they may contain IFS characters
- Variables without `_` are safe to use unquoted (have been sanitized or are controlled)
- This creates visual type safety: `message_` needs quotes, `gateway` does not

## Controlled Sanitization
- Use `printf %q` to render unsafe strings safe, then treat result as safe variable
- Example: `printf -v output '%q ' "$@"` then use `$output` unquoted

## Function Design
- Single responsibility per function
- Clear, descriptive names
- Use local variables appropriately
- Consistent error handling with `fatal()` pattern

## Error Handling
- Use `fatal()` function for consistent error reporting with exit codes
- Validate inputs early (e.g., `isValidIPv4`)
- Use helper functions for common checks (e.g., `isEmpty`)

## Code Organization
- Helper functions at bottom
- Main logic at top
- Use arrays for related data
- Consistent naming conventions

# Advanced Bash Scripting and Testing Patterns

## Dependency Injection for Testability
- **Use wrapper functions + variables**: Create thin wrapper functions (e.g., `showRoutes()`, `addRoute()`) and assign them to PascalCase variables (e.g., `ShowRoutesCmd=showRoutes`)
- **Make external dependencies configurable**: Instead of hardcoding `ip route show`, use `$ShowRoutesCmd` 
- **Keep command complexity in wrappers**: Error handling like `2>/dev/null || true` belongs in the wrapper function, not the caller
- **Variable naming convention**: `AddRouteCmd`, `DelRouteCmd`, `ShowRoutesCmd` - PascalCase for global injection points

## Clean Test Architecture
- **Avoid function shadowing**: Never mock by redefining functions like `ip()` or `sudo()`
- **Use dependency injection in tests**: Set `ShowRoutesCmd=mockShowRoutes` where `mockShowRoutes` is a local function
- **Local mock functions**: Define mocks inside test functions for proper scoping
- **Dynamic scoping advantage**: Mock functions can access test case variables via dynamic scoping
- **Capture output properly**: Use `got_=$(functionCall)` pattern, underscore indicates may contain IFS characters

## Test Data Patterns
- **Associative arrays for test cases**: Use `local -A case1=([name]='...' [input]='...' [want]='...')`
- **Subtest pattern**: Create `subtest()` function that handles `tesht.Inherit` and runs individual cases
- **Data-driven testing**: Use `tesht.Run ${!case@}` to run all case variables as subtests
- **Soft assertions**: Use `tesht.Softly` for multiple related assertions that should all be checked

## Safe Bash Techniques Applied
- **Variable lifecycle management**: Variables like `got_` are scoped appropriately and follow underscore convention
- **Return code handling**: Capture and test return codes explicitly: `func && got=0 || got=1`
- **Array handling**: Use `${args[@]:-}` for optional array expansion with fallback
- **Option parsing sophistication**: Return position of first non-option via return code, enabling `set -- "${@:$?}"`

## Script Architecture Evolution
- **From monolithic to modular**: Original had inline commands, evolved to wrapper functions + dependency injection
- **Separation of concerns**: Command execution (`cue`), route operations (`addRoute`), and business logic separated
- **Testable by design**: Every external dependency is injectable, making comprehensive testing possible
- **Clean interfaces**: Functions have clear single responsibilities and predictable interfaces

## Testing Philosophy
- **Test behavior, not implementation**: Tests verify what commands would be executed, not how
- **Comprehensive coverage**: Test option parsing, validation, main workflows, and edge cases
- **Realistic mocks**: Mock functions simulate real command output and behavior
- **Clear test intent**: Each test has clear arrange/act/assert structure with descriptive names