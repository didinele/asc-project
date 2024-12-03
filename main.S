.data
    // Our file blocks. 1kB of storage total, 1 byte blocks
    blocks: .space 1024

    // General use
    input_scanf_format: .asciz "%d"
    output_whole_printf_format: .asciz "%d: (%d, %d)\n"
    output_just_range_printf_format: .asciz "(%d, %d)\n"

    file_descriptor: .byte 0
    file_size: .byte 0

    // main
    instruction_count: .byte 0

    // handle_op
    op: .byte 0

    // handle_op_add
    file_count: .byte 0

.text
.global main
main:
    // Zero out our blocks
    lea blocks, %edi
    mov $1024, %ecx
zero_loop:
    mov $1024, %eax
    sub %ecx, %eax

    movb $0, (%edi, %eax, 1)
    loop zero_loop

    // Read the number of instructions
    push $instruction_count
    push $input_scanf_format
    call scanf
    add $8, %esp

    mov instruction_count, %ecx
read_loop:
    push %ecx
    call handle_op
    pop %ecx

    loop read_loop

    // Exit
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

    // Read op
    push $op
    push $input_scanf_format
    call scanf
    add $8, %esp

    cmpl $1, op
    je handle_op_add

    cmpl $2, op
    je handle_op_get
handle_op_exit:
    pop %edi
    pop %esi
    pop %ebx
    ret

handle_op_add:
    // Read the number of files
    push $file_count
    push $input_scanf_format
    call scanf
    add $8, %esp

    mov file_count, %ecx
handle_op_add_loop:
    push %ecx
    call handle_op_add_file
    pop %ecx

    loop handle_op_add_loop

    jmp handle_op_exit

handle_op_get:
    // Read file descriptor
    push $file_descriptor
    push $input_scanf_format
    call scanf
    add $8, %esp

    mov file_descriptor, %al

    // We need to find the range and print it in the format (blocks_start, blocks_end).

    // Find the start
    lea blocks, %edi
    mov $1024, %ecx
    mov $-1, %esi
handle_op_get_loop:
    // Use %ebx for indexing
    mov $1024, %ebx
    sub %ecx, %ebx

    // Check if we found our file descriptor, if not, if %esi is already loaded, we might be done
    cmpb %al, (%edi, %ebx, 1)
    jne handle_op_get_loop_continue_no_match

    // We found our file descriptor, load esi if it's not loaded
    cmp $-1, %esi
    je handle_op_get_loop_load_esi

handle_op_get_loop_continue:
    dec %ecx
    jmp handle_op_get_loop
handle_op_get_loop_load_esi:
    mov %ebx, %esi
    jmp handle_op_get_loop_continue
handle_op_get_loop_continue_no_match:
    cmp $-1, %esi
    je handle_op_get_loop_continue

    dec %ebx

    push %ebx
    push %esi
    push $output_just_range_printf_format
    call printf
    add $12, %esp

    jmp handle_op_exit

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Mutates our main file array, for each file prints out "desc: (blocks_start, blocks_end)"
handle_op_add_file:
    // As per call convention, we have to restore %ebx, %esi, %edi
    push %ebx
    push %esi
    push %edi

    // Read file descriptor
    push $file_descriptor
    push $input_scanf_format
    call scanf
    add $8, %esp

    // Read kB size
    push $file_size
    push $input_scanf_format
    call scanf
    add $8, %esp

    // As per spec, we are to treat the kB size as bits
    mov file_size, %eax
    xor %edx, %edx
    mov $8, %ecx
    div %ecx

    // %eax is the number of bytes, but because we want to round up, if %edx is non-zero, we need to add 1
    cmp $0, %edx
    je handle_op_add_file_write

    inc %eax
handle_op_add_file_write:
    // Find %eax consecutive 0'ed blocks
    lea blocks, %edi
    mov $1024, %ecx

    // Store how many we have right now in %edx
    xor %edx, %edx
    mov $-1, %esi

handle_op_add_file_write_loop_begin:
    // Use %ebx for indexing
    mov $1024, %ebx
    sub %ecx, %ebx

    // Check if we found a 0, and if so, we want to continue
    cmpb $0, (%edi, %ebx, 1)
    jne handle_op_add_file_write_loop_reset

    // We found a 0
    inc %edx

    cmp $-1, %esi
    je handle_op_add_file_write_loop_load_esi
handle_op_add_file_write_loop_continue:
    // Check if we have enough
    cmp %eax, %edx
    je handle_op_add_file_write_found

    dec %ecx
    jmp handle_op_add_file_write_loop_begin
handle_op_add_file_write_loop_reset:
    mov $0, %edx
    mov $-1, %esi

    dec %ecx
    jmp handle_op_add_file_write_loop_begin
handle_op_add_file_write_loop_load_esi:
    mov %ebx, %esi
    jmp handle_op_add_file_write_loop_continue
handle_op_add_file_write_found:
    xor %edx, %edx
    mov file_descriptor, %dl

    // We have enough, so we want to print out the range. Also, we need %eax later
    push %eax

    push %ebx
    push %esi
    push %edx
    push $output_whole_printf_format
    call printf
    add $16, %esp

    pop %eax

    // Now we also have to go back and write our file descriptor (from %esi to %esi + %eax)
    mov %esi, %ebx
    add %esi, %eax

    mov file_descriptor, %dl

handle_op_add_file_write_found_loop:
    movb %dl, (%edi, %ebx, 1)
    inc %ebx
    cmp %eax, %ebx
    je handle_op_add_file_write_found_loop_end

    jmp handle_op_add_file_write_found_loop
handle_op_add_file_write_found_loop_end:
    pop %edi
    pop %esi
    pop %ebx
    ret
