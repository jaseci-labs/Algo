# Client Build Fix Documentation

## Problem
When running `jac serve src/app.jac`, the server would start but fail during the client bundle compilation with the following error:

```
subprocess.CalledProcessError: Command '['npm', 'run', 'compile']' returned non-zero exit status 127.
```

Exit code 127 typically means "command not found", indicating that either `npm` or `babel` couldn't be found in the subprocess environment.

## Root Cause Analysis

The Jac client build system works as follows:

1. When `jac serve` starts, it needs to compile the client-side code
2. The babel_processor (located in `jaseci/jac-client/jac_client/plugin/src/impl/babel_processor.impl.jac`) handles this compilation
3. The babel_processor runs from the `.client-build/` directory
4. It temporarily copies `package.json` from `.client-build/.jac-client.configs/` to `.client-build/`
5. If `node_modules` doesn't exist, it runs `npm install`
6. Then it runs `npm run compile` to compile the JavaScript with Babel
7. Finally, it cleans up the temporary `package.json`

**The Issue:** The `package.json` in `.client-build/.jac-client.configs/` was missing critical dependencies:
- No Babel packages (`@babel/cli`, `@babel/core`, `@babel/preset-env`, `@babel/preset-react`)
- No React packages (`react`, `react-dom`, `react-router-dom`)
- No Vite package needed for bundling
- Empty `devDependencies: {}`

When the babel_processor ran `npm install`, it didn't install Babel because it wasn't listed as a dependency. Then when it tried to run `npm run compile`, the `babel` command couldn't be found, resulting in exit code 127.

## Solution

Updated `.client-build/.jac-client.configs/package.json` to include all necessary dependencies.

### Changes Made

#### File: `.client-build/.jac-client.configs/package.json`

**Before:**
```json
{
  "dependencies": {
    "@openai/agents": "latest",
    "zod": "3",
    "@hpcc-js/wasm": "latest"
  },
  "devDependencies": {},
  ...
}
```

**After:**
```json
{
  "dependencies": {
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "react-router-dom": "^6.30.1",
    "@openai/agents": "latest",
    "zod": "3",
    "@hpcc-js/wasm": "latest"
  },
  "devDependencies": {
    "vite": "^6.4.1",
    "@babel/cli": "^7.28.3",
    "@babel/core": "^7.28.5",
    "@babel/preset-env": "^7.28.5",
    "@babel/preset-react": "^7.28.5",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18"
  },
  ...
}
```

### Additional Step Required

After updating the package.json, you must remove the existing `node_modules` in `.client-build/` to force a fresh install:

```bash
rm -rf .client-build/node_modules
```

This ensures that when `jac serve` runs next time, the babel_processor will:
1. Detect missing `node_modules`
2. Copy the updated `package.json` with Babel dependencies
3. Run `npm install` which will now install Babel
4. Successfully run `npm run compile`

## How the Build System Works

### Directory Structure
```
Algo/
├── .client-build/
│   ├── .jac-client.configs/
│   │   ├── package.json          # Source package.json (we updated this)
│   │   ├── vite.config.js
│   │   └── tsconfig.json
│   ├── compiled/                 # Jac compiler output (JSX files)
│   ├── build/                    # Babel output (compiled JS)
│   ├── node_modules/             # Installed dependencies
│   └── package.json              # Temporary (created/deleted by babel_processor)
└── package.json                  # Root package.json (for manual builds)
```

### Build Flow

1. **Jac Compilation**: Jac files (.jac) → JSX files (`.client-build/compiled/`)
2. **Babel Compilation**: JSX files → JavaScript (`.client-build/build/`)
   - Handled by `npm run compile` which runs: `babel compiled --out-dir build --extensions ".jsx,.js" --out-file-extension .js`
3. **Vite Bundling**: JavaScript → Bundled client code (`.client-build/dist/`)

### Why Two package.json Files?

- **Root `package.json`**: Used when you manually run `npm run build` from the project root
- **`.client-build/.jac-client.configs/package.json`**: Used by the Jac build system when running `jac serve`

The babel_processor only uses the configs version, which is why updating that file was essential.

## Testing the Fix

After making these changes:

1. Stop any running `jac serve` processes
2. Remove `.client-build/node_modules`: `rm -rf .client-build/node_modules`
3. Run `jac serve src/app.jac`
4. The first start will take longer as it installs all dependencies
5. The server should start successfully without the subprocess error

## Dependencies Added

### Production Dependencies
- `react` (^19.2.0) - React library
- `react-dom` (^19.2.0) - React DOM rendering
- `react-router-dom` (^6.30.1) - Client-side routing

### Development Dependencies
- `vite` (^6.4.1) - Build tool and dev server
- `@babel/cli` (^7.28.3) - Babel command-line interface
- `@babel/core` (^7.28.5) - Babel core compiler
- `@babel/preset-env` (^7.28.5) - Babel preset for modern JavaScript
- `@babel/preset-react` (^7.28.5) - Babel preset for React/JSX
- `@vitejs/plugin-react` (^4.2.1) - Vite plugin for React
- `typescript` (^5.3.3) - TypeScript compiler
- `@types/react` (^18.2.45) - TypeScript types for React
- `@types/react-dom` (^18.2.18) - TypeScript types for React DOM

## Summary

The fix ensures that when the Jac build system runs, all necessary build tools (especially Babel) are installed in `.client-build/node_modules`, allowing the compilation process to complete successfully. This is a one-time configuration change that should persist across development sessions.
