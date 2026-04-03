# 使用轻量级的 Python 3.10 镜像
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 先把依赖清单拷进去，并安装依赖（这一步放在前面可以利用缓存加速构建）
COPY requirements.txt .
RUN pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ -r requirements.txt

# 把剩下的所有后端代码拷进去
COPY . .

# 暴露 8000 端口
EXPOSE 8000

# 启动命令 (假设你的入口文件是 main.py，FastAPI 实例叫 app)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]