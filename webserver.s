.intel_syntax noprefix

.section .text
.globl _start
_start:
    # Setup stack frame
    push rbp
    mov rbp, rsp
    sub rsp, 0x10             

    # Create socket
    mov rdi, 2                 # AF_INET
    mov rsi, 1                 # SOCK_STREAM
    mov rdx, 0                 # protocol 0
    mov rax, 41    
    syscall
    mov r12, rax  

    # Bind socket
    mov word ptr [rsp+0], 2
    mov word ptr [rsp+2], 0x5000 
    mov dword ptr [rsp+4], 0    
    mov dword ptr [rsp+8], 0   
    mov rdi, r12
    mov rsi, rsp
    mov rdx, 16
    mov rax, 49               
    syscall

    # Listen on socket
    mov rdi, r12
    mov rsi, 0       
    mov rax, 50     
    syscall

loop_accept:
    # Accept connection
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    mov rax, 43       
    syscall
    mov r13, rax     

    # Fork process
    mov rax, 57     
    syscall
    cmp rax, 0
    je child

    # Parent: close accepted connection and loop back
    mov rdi, r13  
    mov rax, 3   
    syscall
    jmp loop_accept

child:
    # Child process: close the server socket
    mov rdi, r12
    mov rax, 3      
    syscall

    # Read HTTP request into file_read_buf
    mov rdi, r13          
    lea rsi, file_read_buf
    mov rdx, 1024
    mov rax, 0           
    syscall
    mov r12, rax

    # Figure out request type
    mov dil, [file_read_buf]
    cmp dil, 0x47
    jne POST

GET:
    # Extract file name
    lea rsi, file_read_buf
    add rsi, 4
    lea rdi, get_file
extract_loop:
	mov al, byte ptr [rsi]
	cmp al, 0x20
	je done_extracting
	mov byte ptr [rdi], al
	inc rsi
	inc rdi
	jmp extract_loop
done_extracting:
	mov byte ptr [rdi], 0

    # Open get_file
    lea rdi, get_file
    mov rsi, 0
    mov rdx, 0
    mov rax, 2
    syscall
    mov r14, rax

    # Read get file
    mov rdi, r14
    lea rsi, get_file_content
    mov rdx, 256
    mov rax, 0
    syscall
    mov rbx, rax

    # close get file
    mov rdi, r14
    mov rax, 3
    syscall

    # Write statique GET response
    mov rdi, r13
    lea rsi, msg
    mov rdx, 19
    mov rax, 1
    syscall
    
    # Write get file
    mov rdi, r13
    lea rsi, get_file_content
    mov rdx, rbx
    mov rax, 1
    syscall

    jmp EXIT

POST:
    # Extract POST filename from request.
    lea rsi, file_read_buf
    add rsi, 5           
    lea rdi, post_file       
extract:
    mov al, byte ptr [rsi] 
    cmp al, 0x20          
    je done_extract
    mov byte ptr [rdi], al
    inc rsi
    inc rdi
    jmp extract
done_extract:
    mov byte ptr [rdi], 0  

    # Open file for writing (O_WRONLY|O_CREAT, mode 0777)
    lea rdi, post_file
    mov rsi, 0x41         
    mov rdx, 0777        
    mov rax, 2          
    syscall
    mov r14, rax       

    # Find end of header
    lea rsi, file_read_buf
find_body:
    cmp byte ptr [rsi], 0x0d
    jne not_found_body
    cmp byte ptr [rsi+1], 0xA
    jne not_found_body
    cmp byte ptr [rsi+2], 0xD
    jne not_found_body
    cmp byte ptr [rsi+3], 0xA
    jne not_found_body
    add rsi, 4           # POST body starts after "\r\n\r\n"
    jmp body_found

not_found_body:
    inc rsi
    jmp find_body

body_found:
    # Get the length of POST content
    xor rcx, rcx
compute_len:
    cmp byte ptr [rsi+rcx], 0
    je len_done
    inc rcx
    jmp compute_len

len_done:
    # Write post content
    mov rdi, r14
    mov rdx, rcx  
    mov rax, 1
    syscall

    # Close the file.
    mov rdi, r14
    mov rax, 3         
    syscall

    # Write HTTP response to client.
    mov rdi, r13
    lea rsi, msg
    mov rdx, 19           
    mov rax, 1           
    syscall

EXIT:
    # Close connection
    mov rdi, r13
    mov rax, 3
    syscall

    # Exit the child process.
    mov rdi, 0
    mov rax, 60         
    syscall

.section .data
msg: .string "HTTP/1.0 200 OK\r\n\r\n"
file_read_buf: .space 1024
post_file: .space 256
get_file_content: .space 1024
get_file: .space 1024
