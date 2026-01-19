.text
main:
    # Test 1: Simple Push/Pop
    li $t0, 42
    addi $sp, $sp, -4
    sw $t0, 0($sp)
    
    li $t0, 0   # clear register
    
    lw $t0, 0($sp)
    addi $sp, $sp, 4
    
    # Print result (should be 42)
    move $a0, $t0
    li $v0, 1
    syscall
    
    # Print newline
    li $a0, 10
    li $v0, 11
    syscall

    # Test 2: Nested Call (saving $ra)
    jal nested_func
    
    # Exit
    li $v0, 10
    syscall

nested_func:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal leaf_func
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

leaf_func:
    # Print "Hi" (72, 105)
    li $a0, 72 # 'H'
    li $v0, 11
    syscall
    
    li $a0, 105 # 'i'
    li $v0, 11
    syscall
    
    li $a0, 10 # '\n'
    li $v0, 11
    syscall
    
    jr $ra
