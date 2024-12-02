.data
    // Our file blocks. 1kB of storage total, 1 byte blocks
    blocks: .space 1024

    // General use
    input_scanf_format: .asciz "%d"

    // main
    instruction_count: .long 0

    // handle_op
    op: .long 0

    // handle_op_add
    file_count: .long 0

    // handle_op_add_file
    output_printf_format: .asciz "%d: (%d, %d)\n"
    file_descriptor: .long 0
    file_size: .long 0
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
    // SIDE EFFECTS: Refer to specific handle_op procedures
handle_op:
    // Read op
    push $op
    push $input_scanf_format
    call scanf
    add $8, %esp

    cmpl $1, op
    je handle_op_add
handle_op_exit:
    ret
handle_op_add:
    // Read number of files
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

// PROCEDURE:
    // CALL STACK: <R.A.>
    // CALL RETURN: void
    // SIDE EFFECTS: Mutates our main file array, for each file prints out "desc: (dev_blocks_start, dev_blocks_end)"
handle_op_add_file:
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
    cmpl $0, (%edi, %ebx, 1)
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
    // We have enough, so we want to print out the range. Also, we need %eax later
    push %eax

    push %ebx
    push %esi
    push file_descriptor
    push $output_printf_format
    call printf
    add $16, %esp

    pop %eax

    // Now we also have to go back and write our file descriptor (from %esi to %esi + %eax)
    mov %esi, %ebx
    add %esi, %eax

    mov file_descriptor, %edx

handle_op_add_file_write_found_loop:
    mov %edx, (%edi, %ebx, 1)
    inc %ebx
    cmp %eax, %ebx
    je handle_op_add_file_write_found_loop_end

    loop handle_op_add_file_write_found_loop
handle_op_add_file_write_found_loop_end:
    ret
