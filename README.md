# ai-xxx

一个Go项目

## 项目结构

```
.
├── cmd/           # 命令行应用程序
├── internal/      # 私有应用程序和库代码
├── pkg/           # 可被外部应用使用的库代码
├── main.go        # 主程序入口
└── go.mod         # Go模块依赖管理
```

## 快速开始

### 运行项目

```bash
go run main.go
```

### 构建项目

```bash
go build -o bin/ai-xxx
```

### 运行测试

```bash
go test ./...
```