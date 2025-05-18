section .data
    filename db "input.txt", 0
    output_filename db "output.cmp", 0

    O_RDONLY equ 0
    O_WRONLY equ 1
    O_CREAT  equ 64
    O_TRUNC  equ 512
    MODE_644 equ 0o644

    code_table:
        times 256 dw 0
    code_length_table:
        times 256 db 0

section .bss
    buffer resb 4096
    freq_table resq 256
    compressed_output resb 8192
    fd resq 1
    output_fd resq 1

section .text
    global _start

_start:
    ; open input.txt
    mov rax, 2
    mov rdi, filename
    mov rsi, O_RDONLY
    syscall
    mov [fd], rax

    ; read file into buffer
    mov rdi, rax
    mov rax, 0
    mov rsi, buffer
    mov rdx, 4096
    syscall
    mov r13, rax        ; input size

    ; build freq table
    xor rcx, rcx
.count_loop:
    cmp rcx, r13
    jge .done_counting
    movzx rbx, byte [buffer + rcx]
    mov rdx, [freq_table + rbx*8]
    inc rdx
    mov [freq_table + rbx*8], rdx
    inc rcx
    jmp .count_loop
.done_counting:

    ; initialize code table (sabit Huffman benzeri kodlar)
; NASM binary literal desteği sıkıntılı olduğu için 0x formatı kullanalım

mov byte [code_length_table + ' '], 2
mov word [code_table + ' '*2], 0x0000

mov byte [code_length_table + 'e'], 2
mov word [code_table + 'e'*2], 0x0001

mov byte [code_length_table + 'a'], 3
mov word [code_table + 'a'*2], 0x0002

mov byte [code_length_table + 't'], 3
mov word [code_table + 't'*2], 0x0005

mov byte [code_length_table + 'o'], 4
mov word [code_table + 'o'*2], 0x000C


    ; default: 0x000F (binary 1111)
    xor rcx, rcx
.default_loop:
    cmp rcx, 256
    jge .done_default
    cmp byte [code_length_table + rcx], 0
    jne .skip
    mov byte [code_length_table + rcx], 4
    mov word [code_table + rcx*2], 0x000F
.skip:
    inc rcx
    jmp .default_loop
.done_default:

    ; encode buffer
    xor rcx, rcx
    xor r8, r8        ; bit buffer
    xor r9, r9        ; bit count
    xor r10, r10      ; output index

.encode_loop:
    cmp rcx, r13
    jge .flush_bits

    movzx rbx, byte [buffer + rcx]
    movzx rdx, byte [code_length_table + rbx]
    movzx rbx, word [code_table + rbx*2]
    xor r11, r11
.encode_bits:
    test rdx, rdx
    jz .encoded_done
    bt rbx, r11
    jc .bit1
.bit0:
    shl r8, 1
    inc r9
    jmp .check_byte
.bit1:
    shl r8, 1
    or r8, 1
    inc r9
.check_byte:
    cmp r9, 8
    jne .next_bit
    mov [compressed_output + r10], r8b
    inc r10
    xor r8, r8
    xor r9, r9
.next_bit:
    inc r11
    dec rdx
    jmp .encode_bits
.encoded_done:
    inc rcx
    jmp .encode_loop

.flush_bits:
    cmp r9, 0
    je .done_compress
    shl r8, (8 - r9)
    mov [compressed_output + r10], r8b
    inc r10
.done_compress:

    ; open output.cmp
    mov rax, 2
    mov rdi, output_filename
    mov rsi, O_CREAT | O_WRONLY | O_TRUNC
    mov rdx, MODE_644
    syscall
    mov [output_fd], rax

    ; write output
    mov rax, 1
    mov rdi, [output_fd]
    mov rsi, compressed_output
    mov rdx, r10
    syscall

    ; close output
    mov rax, 3
    mov rdi, [output_fd]
    syscall

    ; exit
    mov rax, 60
    xor rdi, rdi
    syscall

