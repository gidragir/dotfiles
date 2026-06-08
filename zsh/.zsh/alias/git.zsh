git-all() {
    git add . && git commit -m "${1:-Update}"
}

git-pack() {
    git add . && git commit -m "${1:-Update}" && git push
}