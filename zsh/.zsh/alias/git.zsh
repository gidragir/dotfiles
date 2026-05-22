git-all() {
    git add . && git commit -m "${1:-Update}"
}