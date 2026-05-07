FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install express redis ioredis
COPY . .
EXPOSE 8081
ENV PORT=8081
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3     CMD wget -q --spider http://localhost:8081/health || exit 1
CMD ["node", "index.js"]
