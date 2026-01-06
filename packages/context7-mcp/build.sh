#!/bin/sh
mkdir -p node_modules
pnpm install --offline
pnpm build
