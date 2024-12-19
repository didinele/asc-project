.data
    // Our file blocks. A 32x32 matrix (each element representing a block). 1kB of storage total
    blocks: .space 1024
    dimesnion: .byte 32

    // General use
    input_scanf_format: .asciz "%d"
    output_whole_printf_format: .asciz "%d: ((%d, %d), (%d, %d))\n"
    output_just_range_printf_format: .asciz "((%d, %d), (%d, %d))\n"

    file_descriptor: .byte 0
    file_size: .byte 0

    // main
    instruction_count: .byte 0
.text
.global main
main:
    lea blocks, %edi
    mov $1024, %ecx
main_zero_loop:
    mov $1024, %eax
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

    mov $1, %eax
    xor %ebx, %ebx
    int $0x80

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Refer to specific procedures. Expect mutations to `blocks` and stdout writes.
handle_op:
    // As per call convention, we have to restore %ebx, %esi, %edi
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
    jmp handle_op_exit

handle_op_delete:
    jmp handle_op_exit

handle_op_defrag:
    jmp handle_op_exit

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Mutates our blocks matrix, for each file prints out "desc: (blocks_start, blocks_end)"
add_file:
    // For restoration
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

    // %eax is the number of bytes, but because we want to round up, if %edx is non-zero, we need to add 1
    cmp $0, %edx
    je add_file_write

    inc %eax
add_file_write:
    // We consider a contigious section only if all blocks are on the same line 
    lea blocks, %edi
    mov $1024, %ecx

    xor %edx, %edx
    mov $-1, %esi
    mov $0, %ebp
add_file_write_loop_begin:
    mov $1024, %ebx
    sub %ecx, %ebx


    cmpb $0, (%edi, %ebx, 1)
    jne add_file_write_loop_reset

    inc %edx

    cmp $-1, %esi
    je add_file_write_loop_load_esi
add_file_write_loop_continue:
    cmp %eax, %edx
    je add_file_write_found

    dec %ecx

    // Check if we changed lines
    push %eax
    push %ecx
    push %edx

    mov %ebx, %eax
    xor %edx, %edx
    xor %ecx, %ecx
    movb dimension, %cl
    div %ecx

    cmp %ebp, %edx
    je add_file_write_loop_begin

    inc %ebp
    mov $-1, %esi
    jmp add_file_write_loop_begin

    pop %edx
    pop %ecx
    pop %eax
add_file_write_loop_reset:
    mov $0, %edx
    mov $-1, %esi

    dec %ecx
    jmp add_file_write_loop_begin
add_file_write_loop_load_esi:
    mov %ebx, %esi
    jmp add_file_write_loop_continue
add_file_write_found:
    xor %edx, %edx
    mov file_descriptor, %dl

    // Restoration
    push %eax

    // BUG: ebx and esi need to be scaled to the line we're on
    push %esi
    push %ebp
    push %ebx
    push %ebp
    push %edx
    push $output_whole_printf_format
    call printf
    add $32, %esp

    pop %eax

    mov %esi, %ebx
    add %esi, %eax

    mov file_descriptor, %dl
