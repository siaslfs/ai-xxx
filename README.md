# Webhook 服务

一个使用 Go 语言开发的 Webhook 接收服务，可以接收和打印所有 HTTP 请求信息。

## 功能特性

- ✅ 接收并打印所有请求信息（请求头、查询参数、请求体等）
- ✅ 支持 JSON 格式的请求和响应
- ✅ 自动解析 JSON 请求体
- ✅ 详细的日志输出
- ✅ 健康检查接口

## 接口说明

### Webhook 接口

- **地址**: `/api/callback`
- **方法**: 支持所有 HTTP 方法 (GET, POST, PUT, DELETE 等)
- **请求格式**: 任意格式，建议使用 JSON
- **响应格式**: JSON

**响应示例**:
```json
{
  "status": "success",
  "message": "Webhook 接收成功",
  "timestamp": "2026-01-21 10:30:00",
  "received": {
    "method": "POST",
    "url": "/api/callback?param=value",
    "headers": {...},
    "query_params": {...},
    "body": {...},
    "remote_addr": "127.0.0.1:12345",
    "content_length": 123,
    "host": "localhost:8080"
  }
}
```

### 健康检查接口

- **地址**: `/health`
- **方法**: GET
- **响应格式**: JSON

## 快速开始

### 1. 运行服务

```bash
go run main.go
```

服务将在 `http://localhost:8080` 启动

### 2. 测试 Webhook

使用 curl 发送测试请求：

```bash
# GET 请求
curl http://localhost:8080/api/callback?test=123

# POST 请求 (JSON)
curl -X POST http://localhost:8080/api/callback \
  -H "Content-Type: application/json" \
  -d '{"event": "test", "data": {"key": "value"}}'

# POST 请求 (表单数据)
curl -X POST http://localhost:8080/api/callback \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "field1=value1&field2=value2"
```

### 3. 查看日志

所有接收到的请求信息都会在控制台输出，包括：
- 请求方法和 URL
- 所有请求头
- 查询参数
- 请求体（原始格式和 JSON 解析后的格式）
- 完整的请求信息 JSON

## 编译

```bash
# 编译为可执行文件
go build -o webhook main.go

# 运行编译后的程序
./webhook
```

## 环境要求

- Go 1.21 或更高版本

## 项目结构

```
.
├── main.go        # 主程序文件
├── go.mod         # Go 模块文件
├── .gitignore     # Git 忽略文件
└── README.md      # 项目说明
```

## 日志示例

当收到 webhook 请求时，控制台会输出类似以下内容：

```
=== 收到新的 Webhook 请求 ===
时间: 2026-01-21 10:30:00
方法: POST
URL: /api/callback?param=value
远程地址: 127.0.0.1:12345
Host: localhost:8080
Content-Length: 45

--- 请求头 ---
Content-Type: application/json
User-Agent: curl/7.68.0
Accept: */*

--- 查询参数 ---
param: [value]

--- 请求体 (原始) ---
{"event":"test","data":{"key":"value"}}

--- 请求体 (JSON 解析) ---
{
  "event": "test",
  "data": {
    "key": "value"
  }
}

--- 完整请求信息 (JSON) ---
{
  "method": "POST",
  "url": "/api/callback?param=value",
  ...
}
=== Webhook 请求处理完成 ===
```

## 许可证

MIT
