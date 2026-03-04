# Edge Label Validation Rules

## Edge Label to Connection Type Mappings

EDGE LABEL RULES:
- "then"/"afterwards": Sequential
- "while"/"at same time": PARALLEL
- "if X"/"otherwise": CONDITIONAL
- "either way": ONLY for conditional convergence (NOT parallel)

## Common Mistakes

1. "either way" on parallel convergence → should be "then"
2. Missing "if X" or "otherwise" labels on conditional branches
3. Parallel tasks missing "while" label
