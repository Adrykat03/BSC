FROM mcr.microsoft.com/playwright:v1.60.0-noble

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY screenshot.js ./

CMD ["node", "screenshot.js"]
