# =============================================================================
# ЧтоХочу — public-web (Nuxt 4 SSR) production image
# =============================================================================
# Build context: apps/public-web
#   docker build -t ghcr.io/ruwebdev/chtohochu-web:latest apps/public-web
# Runtime: node .output/server/index.mjs (Nitro), port 3000.
# Env: NUXT_PUBLIC_API_BASE — base URL of the public API.
# =============================================================================

FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    NITRO_HOST=0.0.0.0 \
    NITRO_PORT=3000
COPY --from=build /app/.output ./.output
EXPOSE 3000
CMD ["node", ".output/server/index.mjs"]
