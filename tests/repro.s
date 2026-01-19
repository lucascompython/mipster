.text
main:
    j target
    li $t0, 1    # Should be skipped
target:
    li $t0, 2    # Should be executed
    li $v0, 10
    syscall
