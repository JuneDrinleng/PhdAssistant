# backend/Dockerfile
FROM node:20-bookworm-slim

# 运行时地区/时区（可选）
ENV TZ=Asia/Shanghai NODE_ENV=production

WORKDIR /app

# 仅复制依赖清单，优先利用缓存
COPY package*.json ./

# 安装生产依赖
RUN npm ci --omit=dev

# 复制源码
COPY . .

# 暴露端口
EXPOSE 3000

# 健康检查（容器内访问 /health）
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "http=require('http');http.get('http://127.0.0.1:3000/health',res=>process.exit(res.statusCode===200?0:1)).on('error',()=>process.exit(1))"

# 启动
CMD ["node", "service.js"]
