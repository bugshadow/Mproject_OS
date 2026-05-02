#!/bin/bash
# Test des regex de détection de danger (Version corrigée)

__blackbox_danger_patterns() {
    cat <<'EOF'
rm[[:space:]]+-rf[[:space:]]+/
chmod[[:space:]]+777[[:space:]]+/
chmod[[:space:]]+777[[:space:]]+/(etc|bin|sbin|lib)
dd[[:space:]]+if=.*[[:space:]]+of=/dev/sd
mkfs\.
:(){ :|:& };:
>[[:space:]]+/dev/sda
EOF
}

test_cmd() {
    local cmd="$1"
    local match=false
    while read -r pattern; do
        [ -z "$pattern" ] && continue
        if echo "$cmd" | grep -Eq "$pattern"; then
            match=true
            break
        fi
    done < <(__blackbox_danger_patterns)
    
    if [ "$match" = true ]; then
        echo -e "[MATCH] '$cmd'"
    else
        echo -e "[FAIL ] '$cmd'"
    fi
}

echo "Testing Dangerous Commands:"
test_cmd "chmod 777 /etc"
test_cmd "chmod 777 /etc/"
test_cmd "  chmod 777 /etc"
test_cmd "sudo chmod 777 /etc"
test_cmd "rm -rf /"
test_cmd "mkfs.ext4 /dev/sdb1"
test_cmd "> /dev/sda"

echo -e "\nTesting Safe Commands:"
test_cmd "ls /etc"
test_cmd "chmod 644 /etc/passwd"
test_cmd "rm -rf ./tmp"
