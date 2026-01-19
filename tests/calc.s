.data
    msg_num1:       .asciiz "Introduza o primeiro numero (inteiro): "
    msg_num2:       .asciiz "Introduza o segundo numero (real): "
    msg_operacao:   .asciiz "Escolha a operacao:\nM - Multiplicacao\nD - Divisao\nA - Adicao\nS - Subtracao\nOperacao: "
    msg_resultado:  .asciiz "Resultado: "
    msg_continuar:  .asciiz "\nDeseja realizar outra operacao? (S/N): "
    msg_invalida:   .asciiz "Operacao invalida!\n"
    newline:        .asciiz "\n"
    buffer:         .space 4

.text


main:
inicio:
    # solicitar primeiro numero (inteiro)
    li $v0, 4
    la $a0, msg_num1
    syscall

    li $v0, 5              # ler inteiro
    syscall
    move $t0, $v0          # guardar inteiro em $t0

    # converter inteiro para float
    mtc1 $t0, $f0          # mover para coprocessador
    cvt.s.w $f12, $f0      # converter para float e guardar em $f12

    # solicitar segundo numero (real)
    li $v0, 4
    la $a0, msg_num2
    syscall

    li $v0, 6              # ler float
    syscall
    mov.s $f13, $f0        # guardar float em $f13

    # solicitar operacao
    li $v0, 4
    la $a0, msg_operacao
    syscall

    li $v0, 12             # ler caractere
    syscall
    move $s0, $v0          # guardar operacao em $s0

    # imprimir nova linha
    li $v0, 4
    la $a0, newline
    syscall

    # chamar funcao calc
    # $f12 = primeiro numero (float)
    # $f13 = segundo numero (float)
    # $s0 = operacao
    jal calc

    # mostrar resultado
    li $v0, 4
    la $a0, msg_resultado
    syscall

    mov.s $f12, $f0        # mover resultado para $f12
    li $v0, 2              # imprimir float
    syscall

    # perguntar se deseja continuar
    li $v0, 4
    la $a0, msg_continuar
    syscall

    li $v0, 12             # ler caractere
    syscall
    move $t1, $v0

    # imprimir nova linha
    li $v0, 4
    la $a0, newline
    syscall

    # verificar resposta
    li $t2, 'S'
    beq $t1, $t2, inicio
    li $t2, 's'
    beq $t1, $t2, inicio

    # terminar programa
    li $v0, 10
    syscall

# funcao calc
# entrada: $f12 (numero 1), $f13 (numero 2), $s0 (operacao)
# saida: $f0 (resultado)
calc:
    # verificar operação
    li $t0, 'M'
    beq $s0, $t0, multiplicacao
    li $t0, 'm'
    beq $s0, $t0, multiplicacao

    li $t0, 'D'
    beq $s0, $t0, divisao
    li $t0, 'd'
    beq $s0, $t0, divisao

    li $t0, 'A'
    beq $s0, $t0, adicao
    li $t0, 'a'
    beq $s0, $t0, adicao

    li $t0, 'S'
    beq $s0, $t0, subtracao
    li $t0, 's'
    beq $s0, $t0, subtracao

    # operacao invalida
    li $v0, 4
    la $a0, msg_invalida
    syscall

    # retornar 0
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    jr $ra

multiplicacao:
    mul.s $f0, $f12, $f13
    jr $ra

divisao:
    div.s $f0, $f12, $f13
    jr $ra

adicao:
    add.s $f0, $f12, $f13
    jr $ra

subtracao:
    sub.s $f0, $f12, $f13
    jr $ra
