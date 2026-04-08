FROM node:20-slim
WORKDIR /app
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm install

# Forzamos los target binarios para asegurar consistencia en Railway Debian
ENV PRISMA_CLI_BINARY_TARGETS=debian-openssl-3.0.x

COPY prisma ./prisma

# Invalidación de caché forzada para regenerar el cliente de Prisma
ARG CACHE_BUST=1
RUN npx prisma generate

COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
