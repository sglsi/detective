# 维多利亚伦敦探案 — 后端服务镜像
# 数据库文件通过 SQLITE_PATH 指向容器外的持久卷（见 docker-compose.yml）
FROM node:20-alpine

WORKDIR /app

# 先装依赖，利用镜像层缓存
COPY package*.json ./
RUN npm install --omit=dev

# 复制源码
COPY . .

# 健康检查（可选）
# HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
#   CMD node -e "require('http').get('http://localhost:'+(process.env.PORT||3000)+'/api/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

EXPOSE 3000
CMD ["node", "src/server.js"]
