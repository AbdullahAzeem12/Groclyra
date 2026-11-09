# Project Guidelines (Karpathy Principles)

This repository follows the **Karpathy Coding Guidelines** (inspired by Andrej Karpathy's observations on LLM coding pitfalls):

## 1. Think Before Coding
- **Don't assume, don't hide confusion**: If anything in the prompt is ambiguous or underspecified, surface assumptions or ask for clarification.
- **Surface tradeoffs**: When multiple valid approaches exist, present them briefly with pros and cons rather than picking silently.
- **Stop when confused**: Clearly identify contradictions or missing details before writing code.

## 2. Simplicity First
- **Minimum viable solution**: Write the absolute minimum code necessary to solve the problem.
- **Avoid speculative abstractions**: No premature generalizations, unrequested configuration layers, or over-engineered boilerplate.
- **Reuse existing patterns**: Use the existing database, state management (Riverpod), and routing (GoRouter) already established in Groclyra.

## 3. Surgical Changes
- **Strictly scoped edits**: Touch only what is strictly necessary for the request.
- **Preserve existing code & comments**: Never reformat unrelated files or wipe existing comments.
- **Zero collateral damage**: Every change must directly serve the user's explicit objective without breaking existing functionality.

## 4. Goal-Driven Execution
- **Verifiable success criteria**: Ensure all changes compile cleanly (`flutter analyze` with 0 errors) and pass all tests (`flutter test` 100% pass rate).
- **Evidence-backed delivery**: Verify correctness through automated tools before presenting solutions.
