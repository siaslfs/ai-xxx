package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// WebhookResponse 响应结构
type WebhookResponse struct {
	Status    string      `json:"status"`
	Message   string      `json:"message"`
	Timestamp string      `json:"timestamp"`
	Received  interface{} `json:"received,omitempty"`
}

// RequestInfo 请求信息结构
type RequestInfo struct {
	Method        string              `json:"method"`
	URL           string              `json:"url"`
	Headers       map[string][]string `json:"headers"`
	QueryParams   map[string][]string `json:"query_params"`
	Body          interface{}         `json:"body,omitempty"`
	RemoteAddr    string              `json:"remote_addr"`
	ContentLength int64               `json:"content_length"`
	Host          string              `json:"host"`
}

// webhookHandler 处理 webhook 请求
func webhookHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("=== 收到新的 Webhook 请求 ===")
	log.Printf("时间: %s", time.Now().Format("2006-01-02 15:04:05"))
	log.Printf("方法: %s", r.Method)
	log.Printf("URL: %s", r.URL.String())
	log.Printf("远程地址: %s", r.RemoteAddr)
	log.Printf("Host: %s", r.Host)
	log.Printf("Content-Length: %d", r.ContentLength)
	
	// 打印所有请求头
	log.Println("\n--- 请求头 ---")
	for name, values := range r.Header {
		for _, value := range values {
			log.Printf("%s: %s", name, value)
		}
	}
	
	// 打印查询参数
	if len(r.URL.Query()) > 0 {
		log.Println("\n--- 查询参数 ---")
		for name, values := range r.URL.Query() {
			log.Printf("%s: %v", name, values)
		}
	}
	
	// 读取请求体
	var bodyData interface{}
	if r.ContentLength > 0 {
		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("读取请求体错误: %v", err)
		} else {
			bodyStr := string(bodyBytes)
			log.Println("\n--- 请求体 (原始) ---")
			log.Println(bodyStr)
			
			// 尝试解析为 JSON
			contentType := r.Header.Get("Content-Type")
			if strings.Contains(contentType, "application/json") {
				var jsonData interface{}
				if err := json.Unmarshal(bodyBytes, &jsonData); err == nil {
					bodyData = jsonData
					log.Println("\n--- 请求体 (JSON 解析) ---")
					prettyJSON, _ := json.MarshalIndent(jsonData, "", "  ")
					log.Println(string(prettyJSON))
				} else {
					bodyData = bodyStr
					log.Printf("JSON 解析失败: %v", err)
				}
			} else {
				bodyData = bodyStr
			}
		}
		defer r.Body.Close()
	}
	
	// 构建请求信息
	requestInfo := RequestInfo{
		Method:        r.Method,
		URL:           r.URL.String(),
		Headers:       r.Header,
		QueryParams:   r.URL.Query(),
		Body:          bodyData,
		RemoteAddr:    r.RemoteAddr,
		ContentLength: r.ContentLength,
		Host:          r.Host,
	}
	
	// 打印完整的请求信息 JSON
	log.Println("\n--- 完整请求信息 (JSON) ---")
	fullInfoJSON, _ := json.MarshalIndent(requestInfo, "", "  ")
	log.Println(string(fullInfoJSON))
	log.Println("=== Webhook 请求处理完成 ===\n")
	
	// 返回 JSON 响应
	response := WebhookResponse{
		Status:    "success",
		Message:   "Webhook 接收成功",
		Timestamp: time.Now().Format("2006-01-02 15:04:05"),
		Received:  requestInfo,
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// healthHandler 健康检查
func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"status":  "ok",
		"message": "Webhook 服务运行正常",
		"time":    time.Now().Format("2006-01-02 15:04:05"),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	// 注册路由
	http.HandleFunc("/api/callback", webhookHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		response := map[string]string{
			"message": "Webhook 服务",
			"version": "1.0.0",
			"endpoints": "/api/callback, /health",
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	})
	
	port := ":8080"
	log.Printf("Webhook 服务启动在端口 %s", port)
	log.Printf("Webhook 接口: http://localhost%s/api/callback", port)
	log.Printf("健康检查: http://localhost%s/health", port)
	
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("服务启动失败: %v", err)
	}
}
