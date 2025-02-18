.data
    // Our file blocks. A 1024x1024 matrix (each element representing a block)
    blocks: .space 1048576
    line_size: .long 1024
    total_size: .long 1048576

    // General use
    input_scanf_format: .asciz "%d\n"
    output_one_number_printf_format: .asciz "%d\n"
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

    // handle_op_concrete
    // max linux path length is 4096 (including null terminator)
    absolute_path: .space 4096
    file_name_ptr: .long 0

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

    cmpb $5, op
    je handle_op_concrete
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

    push $file_descriptor
    push $input_scanf_format
    call scanf
    add $8, %esp

    push $file_size
    push $input_scanf_format
    call scanf
    add $8, %esp

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
    // To guarantee everything is compact, we need to call defrag n times, where n is the last line with an fd on it
    lea blocks, %edi
    mov total_size, %ecx
handle_op_defrag_find_last:
    cmpb $0, (%edi, %ecx, 1)
    jne handle_op_defrag_found
    loop handle_op_defrag_find_last
handle_op_defrag_found:
    cmp $0, %ecx
    je handle_op_defrag_done

    mov %ecx, %eax
    xor %edx, %edx

    divl line_size

    mov %eax, %ecx
handle_op_defrag_loop:
    push %ecx
    call defrag
    pop %ecx

    cmp $0, %ecx
    je handle_op_defrag_done

    dec %ecx
    jmp handle_op_defrag_loop
handle_op_defrag_done:
    call print_blocks
    jmp handle_op_exit

handle_op_concrete:
    push stdin
    push $4096
    push $absolute_path
    call fgets
    add $12, %esp

    lea absolute_path, %edi
    mov $0, %ecx
handle_op_concrete_strip_newline:
    cmpb $0, (%edi, %ecx, 1)
    je handle_op_concrete_done_strip
    cmpb $'\n', (%edi, %ecx, 1)
    jne handle_op_concrete_continue_strip
    movb $0, (%edi, %ecx, 1)
    jmp handle_op_concrete_done_strip
handle_op_concrete_continue_strip:
    inc %ecx
    jmp handle_op_concrete_strip_newline
handle_op_concrete_done_strip:
    push $absolute_path
    call opendir
    add $4, %esp
    mov %eax, %edi // DIR*

    push $absolute_path
    call chdir
    add $4, %esp

    mov $0, %ecx
handle_op_concrete_file_loop:
    // restoration for the end of the loop
    push %ecx

    push %edi
    call readdir
    add $4, %esp

    cmp $0, %eax // we're done
    je handle_op_concrete_done

    // save the pointer in ebp for later use
    lea 11(%eax), %ebp // 11 is the offset to d_name in dirent, which is char[256]

    // readdir includes . and .., so we need to skip those
    cmpb $'.', (%ebp)
    je handle_op_concrete_skips

    mov %ebp, file_name_ptr

    push $0 // O_RDONLY
    push file_name_ptr 
    call open
    add $8, %esp

    // save the fd in ebx for later
    mov %eax, %ebx

    mov $255, %ebp
    divl %ebp
    mov %edx, %esi
    inc %esi

    push %ecx
    push %esi
    push $output_one_number_printf_format
    call printf
    add $8, %esp
    pop %ecx

    sub $96, %esp // sizeof(struct stat)

    push %esp
    push file_name_ptr
    call stat
    add $8, %esp

    // We need st_size, which is 44 bytes in
    mov 44(%esp), %eax
    add $96, %esp

    mov $1024, %ebp
    divl %ebp

    push %ecx
    push %eax
    push $output_one_number_printf_format
    call printf
    add $4, %esp
    pop %eax
    pop %ecx

    cmp line_size, %eax
    jg handle_op_concrete_bad_size_or_fd

    cmp $0, %eax
    je handle_op_concrete_bad_size_or_fd

    mov %eax, file_size
    xor %eax, %eax
    mov %esi, %eax
    movb %al, file_descriptor

    // if the fd already exists, we need to stop here
    push %esi
    call find_fd
    pop %esi

    cmp $-1, %eax
    jne handle_op_concrete_bad_size_or_fd

    call add_file

    pop %ecx

    // for later closing
    push %ebx

    inc %ecx
    jmp handle_op_concrete_file_loop
handle_op_concrete_bad_size_or_fd:
    push $0
    push $0
    push $0
    push $0
    push %esi
    push $output_whole_printf_format
    call printf
    add $24, %esp

    pop %ecx
    inc %ecx

    push %ebx
    jmp handle_op_concrete_file_loop
handle_op_concrete_done:
    pop %esi // originally %ecx
    dec %esi // otherwise we do one too many
handle_op_concrete_close_loop:
    // stack is set up in such a way to have all the pending fds on hand; we use %esi to loop so we don't
    // worry about restoring it
    call close
    add $4, %esp

    dec %esi
    cmp $-1, %esi
    jne handle_op_concrete_close_loop

    jmp handle_op_exit
handle_op_concrete_skips:
    pop %ecx
    jmp handle_op_concrete_file_loop

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
    cmpb $0, file_descriptor
    jne find_fd_begin

    mov $-1, %eax
    mov $-1, %edx
    ret
find_fd_begin:
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

// PROCEDURE:
    // CALL STACK: <R.A.>, int line
    // CALL RETURN: eax=-1 if the line is full of 0s, any other value otherwise
defrag_line:
    // All analogue to 1d defrag
    push %ebp
    mov %esp, %ebp

    push %ebx
    push %esi
    push %edi
defrag_line_begin:
    mov 8(%ebp), %eax
    mull line_size

    lea blocks(%eax), %edi
    mov line_size, %ecx
    mov $-1, %esi
defrag_line_loop_begin:
    mov line_size, %ebx
    sub %ecx, %ebx

    cmpb $0, (%edi, %ebx, 1)
    jne defrag_line_loop_no_match

    cmp $-1, %esi
    je defrag_line_loop_load_esi
defrag_line_loop_continue:
    dec %ecx

    cmp $0, %ecx
    je defrag_line_ret

    jmp defrag_line_loop_begin
defrag_line_loop_load_esi:
    mov %ebx, %esi
    jmp defrag_line_loop_continue
defrag_line_loop_no_match:
    cmp $-1, %esi
    je defrag_line_loop_continue
defrag_line_loop_shift:
    movb (%edi, %ebx, 1), %al
    movb %al, (%edi, %esi, 1)
    movb $0, (%edi, %ebx, 1)

    inc %ebx
    inc %esi

    cmp line_size, %ebx
    jne defrag_line_loop_shift

    jmp defrag_line_begin
defrag_line_ret:
    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    ret

// PROCEDURE:
    // CALL STACK: <R.A.>, int line
    // CALL RETURN: void
// For all lines, given we're on line n:
    // 1. Call defrag on n
    // 2. If n + 1 doesn't exist (i.e. we're on 1023), we're done
    // 3. Otherwise, count how many blanks (0s) we have at the end of n and how big the first file is on n + 1
    // 4. If it's smaller or equal to our gaps, move it over and defrag n + 1 again, go back to step 3
    // 5. If it's bigger or doesn't exist, increment n and go back to step 1
// This needs to be called repeatedly to guarantee a full defrag
defrag:
    push %ebx
    push %esi
    push %edi
    mov $0, %ecx
defrag_loop_begin:
    // Step 1
    // Serves as both restoration and parameter
    push %ecx
    call defrag_line
    pop %ecx

    // Step 2, finish check
    cmp $1023, %ecx
    je defrag_ret

    // Step 2, defrag n+1
    mov %ecx, %eax
    inc %eax

    push %eax
    call defrag_line
    pop %eax

    dec %eax
    mov %eax, %ecx
defrag_count_blank:
    // Step 3; given we've defragged, all the 0s are at the end, so it makes the most sense to count right->left
    mull line_size

    lea blocks(%eax), %edi

    mov $0, %esi
    mov line_size, %ebx
    dec %ebx
defrag_count_blanks_loop:
    cmpb $0, (%edi, %ebx, 1)
    jne defrag_count_next

    // In case it's all 0s
    cmp $0, %ebx
    je defrag_count_next

    inc %esi
    dec %ebx

    jmp defrag_count_blanks_loop
defrag_count_next:
    // Restoration
    push %ecx
    xor %ecx, %ecx
    movb 1024(%edi), %cl
    movb %cl, file_descriptor
    call find_fd
    pop %ecx

    // Check for an early Step 5, if the fd doesn't exist
    cmp $-1, %eax
    jne defrag_count_carry_on

    inc %ecx
    jmp defrag_loop_begin
defrag_count_carry_on:
    // Restoration
    push %edx

    sub %eax, %edx
    inc %edx

    // %edx is now the length of the first file on n+1
    cmp %esi, %edx
    // Step 4
    jle defrag_move

    // Step 5, but before that, fix the stack
    pop %edx

    inc %ecx
    jmp defrag_loop_begin
defrag_move:
    // This is step 4.
    // We know esi is the start of our empty block; edi is the start of the n line

    // Let's use ebp as a pointer to the start of the matrix, since eax and edx are "absolute indeces"
    lea blocks, %ebp

    pop %edx

    // esi is the number of 0s at the end of n. let's turn it into the index of the first 0
    push %ecx
    mov line_size, %ecx
    sub %esi, %ecx
    mov %ecx, %esi
defrag_move_loop:
    xor %ecx, %ecx

    movb (%ebp, %eax, 1), %cl
    movb %cl, (%edi, %esi, 1)
    movb $0, (%ebp, %eax, 1)

    inc %eax
    inc %esi

    cmp %edx, %eax
    jg defrag_move_done

    jmp defrag_move_loop
defrag_move_done:
    pop %ecx
    // Now we need to defrag n+1
    mov %ecx, %eax
    inc %eax

    push %eax
    call defrag_line
    pop %ecx
    dec %ecx

    // We need to go back to step 3. eax needs to be set back to n
    mov %ecx, %eax
    jmp defrag_count_blank
defrag_ret:
    pop %edi
    pop %esi
    pop %ebx
    ret
