.data
    msg_num1:       .asciiz "Enter the first number (integer): "
    msg_num2:       .asciiz "Enter the second number (real): "
    msg_op:         .asciiz "Choose operation:\n+ : Addition\n- : Subtraction\n* : Multiplication\n/ : Division\nOperation: "
    msg_res:        .asciiz "Result: "
    msg_continue:   .asciiz "\nDo you want to perform another operation? (y/n): "
    msg_invalid:    .asciiz "Invalid operation!\n"
    newline:        .asciiz "\n"
    buffer:         .space 4

.text

main:
loop_start:
    # prompt first number (int)
    li $v0, 4
    la $a0, msg_num1
    syscall

    li $v0, 5              # read int
    syscall
    move $t0, $v0          # save int to $t0

    # convert int to float
    mtc1 $t0, $f0
    cvt.s.w $f12, $f0      # $f12 = float(num1)

    # prompt second number (real)
    li $v0, 4
    la $a0, msg_num2
    syscall

    li $v0, 6              # read float
    syscall
    mov.s $f13, $f0        # $f13 = num2

    # prompt operation
    li $v0, 4
    la $a0, msg_op
    syscall

    li $v0, 12             # read char
    syscall
    move $s0, $v0          # $s0 = op

    # print newline
    li $v0, 4
    la $a0, newline
    syscall

    # call calc
    jal calc

    # show result
    li $v0, 4
    la $a0, msg_res
    syscall

    mov.s $f12, $f0        # move result to $f12
    li $v0, 2              # print float
    syscall

    # prompt continue
    li $v0, 4
    la $a0, msg_continue
    syscall

    li $v0, 12             # read char
    syscall
    move $t1, $v0

    # print newline
    li $v0, 4
    la $a0, newline
    syscall

    # check continue
    li $t2, 'y'
    beq $t1, $t2, loop_start
    li $t2, 'Y'
    beq $t1, $t2, loop_start

    # exit
    li $v0, 10
    syscall

# calc function
# input: $f12 (n1), $f13 (n2), $s0 (op)
# output: $f0 (result)
calc:
    li $t0, '+'
    beq $s0, $t0, op_add
    li $t0, '-'
    beq $s0, $t0, op_sub
    li $t0, '*'
    beq $s0, $t0, op_mul
    li $t0, '/'
    beq $s0, $t0, op_div

    # invalid
    li $v0, 4
    la $a0, msg_invalid
    syscall
    
    # return 0.0
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    jr $ra

op_mul:
    mul.s $f0, $f12, $f13
    jr $ra

op_div:
    div.s $f0, $f12, $f13
    jr $ra

op_add:
    add.s $f0, $f12, $f13
    jr $ra

op_sub:
    sub.s $f0, $f12, $f13
    jr $ra
