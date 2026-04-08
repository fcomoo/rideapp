# Uso de imagen completa para máxima compatibilidad con Prisma motores
FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npx prisma generate
RUN npm run build

EXPOSE 3000
# El comando start ejecuta: npx prisma migrate deploy && node dist/index.js
CMD ["npm", "start"]
