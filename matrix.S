.data
    // Our file blocks. A 1024x1024 matrix (each element representing a block)
    blocks: .space 1048576
    line_size: .long 1024
    total_size: .long 1048576

    // General use
    input_scanf_format: .asciz "%d"
    output_whole_printf_format: .asciz "%d: ((%d, %d), (%d, %d))\n"
    output_just_range_printf_format: .asciz "((%d, %d), (%d, %d))\n"

    file_descriptor: .byte 0
    file_size: .byte 0

    // main
    instruction_count: .byte 0

    // handle_op
    op: .byte 0

    // handle_op_add
    file_count: .byte 0

    // add_file
    line: .long 0
.text
.global main
main:
    lea blocks, %edi
    mov line_size, %ecx
main_zero_loop:
    mov line_size, %eax
    sub %ecx, %eax

    movb $0, (%edi, %eax, 1)
    loop main_zero_loop

    push $instruction_count
    push $input_scanf_format
    call scanf
    add $8, %esp

    mov instruction_count, %ecx
main_read_loop:
    push %ecx
    call handle_op
    pop %ecx

    loop main_read_loop

    push $0
    call fflush
    pop %eax

    mov $1, %eax
    xor %ebx, %ebx
    int $0x80

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Refer to specific procedures. Expect mutations to `blocks` and stdout writes.
handle_op:
    push %ebx
    push %esi
    push %edi

    push $op
    push $input_scanf_format
    call scanf
    add $8, %esp

    cmpb $1, op
    je handle_op_add

    cmpb $2, op
    je handle_op_get

    cmpb $3, op
    je handle_op_delete

    cmpb $4, op
    je handle_op_defrag
handle_op_exit:
    pop %edi
    pop %esi
    pop %ebx
    ret

handle_op_add:
    push $file_count
    push $input_scanf_format
    call scanf
    add $8, %esp

    mov file_count, %ecx
handle_op_add_loop:
    push %ecx
    call add_file
    pop %ecx

    loop handle_op_add_loop

    jmp handle_op_exit

handle_op_get:
    push $file_descriptor
    push $input_scanf_format
    call scanf
    add $8, %esp

    // This reads file_descriptor directly
    call find_fd

    cmp $-1, %eax
    je handle_op_get_not_found

    // eax and edx are "absolute" indeces. We need to re-calc based off of the line

    // save edx, since we're calculating for eax first
    push %edx

    xor %edx, %edx
    divl line_size
    mov %eax, line
    // esi now stores our line, while edx stores the index on the line
    mov %edx, %esi

    // now edx. we need to divide it, so pop it straight into %eax
    pop %eax

    xor %edx, %edx
    divl line_size
    // we already have our line (current eax after divl), and the remainder is already in edx, so now we just print

    push %edx
    push line
    push %esi
    push line
    push $output_just_range_printf_format
    call printf
    add $20, %esp

    jmp handle_op_get_done
handle_op_get_not_found:
    push $0
    push $0
    push $0
    push $0
    push $output_just_range_printf_format
    call printf
    add $20, %esp
handle_op_get_done:
    jmp handle_op_exit

handle_op_delete:
    push $file_descriptor
    push $input_scanf_format
    call scanf
    add $8, %esp

    // This reads file_descriptor directly
    call find_fd

    cmp $-1, %eax
    je handle_op_delete_done

    // 0 out from eax to edx
    lea blocks, %edi
handle_op_delete_loop:
    movb $0, (%edi, %eax, 1)
    inc %eax
    cmp %edx, %eax
    jg handle_op_delete_done

    jmp handle_op_delete_loop
handle_op_delete_done:
    call print_blocks
    jmp handle_op_exit

handle_op_defrag:
    jmp handle_op_exit

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Mutates our main file array, for each file prints out "desc: (blocks_start, blocks_end)"
add_file:
    push %ebp
    mov %esp, %ebp

    push %ebx
    push %esi
    push %edi

    push $file_descriptor
    push $input_scanf_format
    call scanf
    add $8, %esp

    push $file_size
    push $input_scanf_format
    call scanf
    add $8, %esp

    mov file_size, %eax
    xor %edx, %edx
    mov $8, %ecx
    div %ecx

    mov line_size, %ecx

    cmp $0, %edx
    je add_file_loop_begin

    inc %eax
add_file_loop_begin:
    mov line_size, %ebx
    sub %ecx, %ebx

    mov %ebx, line

    // Restoration
    push %eax
    push %ecx

    push %eax
    push line
    call find_empty
    add $8, %esp

    // If one of them is different from -1, we found a spot
    cmp $-1, %eax
    jne add_file_found

    pop %ecx
    pop %eax

    dec %ecx
    cmp $0, %ecx
    je add_file_not_found

    jmp add_file_loop_begin
add_file_found:
    // We don't care about our old eax and ecx anymore. Still, need to reclaim the stack
    add $8, %esp

    xor %ebx, %ebx
    mov file_descriptor, %bl

    // We need to keep in mind line offsetting
    // Restoration
    push %eax
    push %edx

    mov line, %eax
    mull line_size

    lea blocks(%eax), %edi

    pop %edx
    pop %eax

    mov %eax, %ecx

add_file_found_loop:
    // At this point, we have to fill blocks[eax..edx] with file_descriptor
    movb %bl, (%edi, %ecx, 1)

    cmp %ecx, %edx
    je add_file_done

    inc %ecx
    jmp add_file_found_loop
add_file_not_found:
    xor %edx, %edx
    mov file_descriptor, %dl

    push $0
    push $0
    push $0
    push $0
    push %edx
    push $output_whole_printf_format
    call printf
    add $24, %esp

    jmp add_file_ret
add_file_done:
    push %edx
    push line
    push %eax
    push line
    push %ebx
    push $output_whole_printf_format
    call printf
    add $24, %esp
add_file_ret:
    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    ret

// PROCEDURE:
    // CALL STACK: <R.A.>, int line, int size
    // CALL RETURN: eax: start, edx: end
find_empty:
    push %ebp
    mov %esp, %ebp

    push %ebx
    push %esi
    push %edi

    mov 8(%ebp), %eax
    mull line_size
    mov %eax, %ecx

    mov 12(%ebp), %eax

    lea blocks(%ecx), %edi
    mov line_size, %ecx

    xor %edx, %edx
    mov $-1, %esi
find_empty_loop_begin:
    cmp $0, %ecx
    je find_empty_not_found

    mov line_size, %ebx
    sub %ecx, %ebx

    cmpb $0, (%edi, %ebx, 1)
    jne find_empty_loop_reset

    inc %edx

    cmp $-1, %esi
    je find_empty_loop_load_esi
find_empty_loop_continue:
    cmp %eax, %edx
    je find_empty_found

    dec %ecx

    jmp find_empty_loop_begin
find_empty_loop_reset:
    mov $0, %edx
    mov $-1, %esi

    dec %ecx
    jmp find_empty_loop_begin
find_empty_loop_load_esi:
    mov %ebx, %esi
    jmp find_empty_loop_continue
find_empty_found:
    mov %esi, %eax
    mov %ebx, %edx
    jmp find_empty_ret
find_empty_not_found:
    mov $-1, %eax
    mov $-1, %edx
find_empty_ret:
    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    ret

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: eax: start, edx: end
find_fd:
    push %ebp
    mov %esp, %ebp

    push %ebx
    push %esi
    push %edi

    lea blocks, %edi
    mov total_size, %ecx
    mov $-1, %esi

    xor %eax, %eax
    mov file_descriptor, %al
find_fd_loop:
    mov total_size, %ebx
    sub %ecx, %ebx

    // Check if we found our file descriptor, if not, if %esi is already loaded, we might be done
    cmpb %al, (%edi, %ebx, 1)
    jne find_fd_loop_no_match

    cmp $-1, %esi
    je find_fd_loop_load_esi
find_fd_loop_continue:
    dec %ecx

    cmp $0, %ecx
    je find_fd_loop_end

    jmp find_fd_loop
find_fd_loop_load_esi:
    mov %ebx, %esi
    jmp find_fd_loop_continue
find_fd_loop_no_match:
    cmp $-1, %esi
    je find_fd_loop_continue

    dec %ebx

    mov %esi, %eax
    mov %ebx, %edx

    jmp find_fd_ret
find_fd_loop_end:
    mov total_size, %ebx
    cmpb %al, (%edi, %esi, 1)
    je find_fd_loop_no_match

    mov $-1, %eax
    mov $-1, %edx
find_fd_ret:
    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    ret

// PROCEDURE
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Prints all blocks
print_blocks:
    push %ebx
    push %esi
    push %edi

    mov line_size, %ecx
print_blocks_loop_begin:
    mov line_size, %ebx
    sub %ecx, %ebx

    // Restoration
    push %ecx

    push %ebx
    call print_line
    add $4, %esp

    pop %ecx

    dec %ecx
    cmp $0, %ecx
    je print_blocks_ret

    jmp print_blocks_loop_begin
print_blocks_ret:
    pop %edi
    pop %esi
    pop %ebx
    ret

// PROCEDURE
    // CALL STACK: <R.A.>, int line
    // CALL RETURN: void
    // SIDE EFFECTS: Prints all blocks from a certain line
print_line:
    push %ebp
    mov %esp, %ebp

    push %ebx
    push %esi
    push %edi

    mov 8(%ebp), %eax
    mull line_size

    lea blocks(%eax), %edi
    mov line_size, %ecx
    mov $-1, %esi

    xor %eax, %eax
    movb (%edi), %al
print_line_loop_begin:
    mov line_size, %ebx
    sub %ecx, %ebx

    cmpb $0, %al
    je print_line_loop_al_zero

    cmpb %al, (%edi, %ebx, 1)
    jne print_line_loop_no_match

    cmp $-1, %esi
    je print_line_loop_load_esi

    cmp $1023, %ebx
    je print_line_edge_case
print_line_loop_continue:
    dec %ecx

    cmp $0, %ecx
    je print_line_ret

    jmp print_line_loop_begin
print_line_loop_load_esi:
    mov %ebx, %esi
    dec %esi
    jmp print_line_loop_continue
print_line_loop_no_match:
    cmp $-1, %esi
    je print_line_loop_continue

    movb (%edi, %ebx, 1), %al

    dec %ebx

    push %eax
    push %ecx

    xor %edx, %edx
    movb (%edi, %esi, 1), %dl

    push %ebx
    push 8(%ebp)
    push %esi
    push 8(%ebp)
    push %edx
    push $output_whole_printf_format
    call printf
    add $24, %esp

    pop %ecx
    pop %eax

    mov $-1, %esi
    jmp print_line_loop_continue
print_line_loop_al_zero:
    cmpb $0, (%edi, %ebx, 1)
    je print_line_loop_continue

    movb (%edi, %ebx, 1), %al
    mov %ebx, %esi
    jmp print_line_loop_continue
print_line_ret:
    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    ret
print_line_edge_case:
    inc %ebx
    jmp print_line_loop_no_match
