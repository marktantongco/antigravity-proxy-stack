FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install express axios cors helmet morgan
COPY . .
EXPOSE 3002
ENV PORT=3002
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3     CMD wget -q --spider http://localhost:3002/health || exit 1
CMD ["node", "index.js"]
