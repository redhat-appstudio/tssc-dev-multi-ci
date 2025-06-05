package main

import (
	"bytes"
	_ "embed"
	"log"
	"net/http"
	"os"
	"sync"
)

//go:embed www/index.html
var index_html []byte

func init() {
	gitRepo := "UNKNOWN"
	if env_git_repo := os.Getenv("GIT_REPO"); env_git_repo != "" {
		gitRepo = env_git_repo
	}
	index_html = bytes.Replace(index_html, []byte("GIT_REPO"), []byte(gitRepo), -1)
}

func handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(index_html)
}

func startServer(port string, wg *sync.WaitGroup) {
	defer wg.Done()

	mux := http.NewServeMux()
	mux.HandleFunc("/", handler)

	server := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	log.Printf("Starting server on port %s\n", port)
	if err := server.ListenAndServe(); err != nil {
		log.Printf("Server on port %s failed: %v\n", port, err)
	}
}

func main() {
	ports := []string{"8080", "8081", "3001"}
	var wg sync.WaitGroup

	for _, port := range ports {
		wg.Add(1)
		go startServer(port, &wg)
	}

	wg.Wait()
}
