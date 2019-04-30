assume cs:code, ds:data, ss:stack

data segment
	time dw 0
	score dw 0
	snake db 40, 12, 2046 dup (0)
	len dw 1
	gameEnd db 'game over'
	fruit db 20, 7
	current_sec db 0
data ends

stack segment
	db 256 dup (0)
stack ends

code segment

	    gamescreen: push ax
			push dx
			push ds
			push si
			push es
			push cx

			mov ax, data	
			mov ds, ax
			update:	push ax							; store previous direction (ah)
				cmp ah, 10h
				jne continue_game
				pop ax
				jmp near ptr gameover
		 continue_game:	call getInput
					mov dl, snake[0]				; detect if input is valid
					mov dh, snake[1]
					cmp ah, 48h					
					je detect_upper_pixel
					cmp ah, 50h
					je detect_lower_pixel
					cmp ah, 4bh
					je detect_left_pixel
					cmp ah, 4dh
					je detect_right_pixel
						detect_upper_pixel: dec dh
								    cmp dl, snake[2]
								    jne ok_to_turn
								    cmp dh, snake[3]
								    je not_ok_to_turn
								    jmp short ok_to_turn
						detect_lower_pixel: inc dh
								    cmp dl, snake[2]
								    jne ok_to_turn
								    cmp dh, snake[3]
								    je not_ok_to_turn
								    jmp short ok_to_turn
						 detect_left_pixel: dec dl
								    cmp dl, snake[2]
								    jne ok_to_turn
								    cmp dh, snake[3]
								    je not_ok_to_turn
								    jmp short ok_to_turn
						detect_right_pixel: inc dl
								    cmp dl, snake[2]
								    jne ok_to_turn
								    cmp dh, snake[3]
								    je not_ok_to_turn
								    jmp short ok_to_turn
			    ok_to_turn: pop dx
					jmp short detect_fruit
		        not_ok_to_turn: pop ax

		  detect_fruit:	mov al, 0
				mov dl, snake[0]
				cmp dl, fruit[0]
				jne length_hold
				mov dl, snake[1]
				cmp dl, fruit[1]
				jne length_hold
				inc al							; snake eats fruit
		   length_hold:	call clear
				call update_snake

				cmp byte ptr ds:[snake], 0				; collisions detect
				je gameover
				cmp byte ptr ds:[snake], 79
				je gameover
				cmp byte ptr ds:[snake+1], 2
				je gameover
				cmp byte ptr ds:[snake+1], 24
				je gameover
				cmp al, 1
				je too_short_or_elongated

				mov bl, snake[0]
				mov bh, snake[1]
				mov cx, len
				dec cx
				jcxz too_short_or_elongated
				mov si, 2
	        self_collision: cmp bl, ds:[si+snake]
				jne no_collision
				cmp bh, ds:[si+snake+1]
				je gameover
		  no_collision:	add si, 2
				loop self_collision

	too_short_or_elongated:	call update_time
				call delay
				jmp near ptr update

              gameover:	mov ax, 0b800h
			mov es, ax
			mov si, 0
			mov di, 160*12+2*35
			mov cx, 9
	    gameoverpr:	mov al, ds:[si+gameEnd]
			mov byte ptr es:[di], al
			mov byte ptr es:[di+1], 7
			add di, 2
			inc si
			loop gameoverpr
			
			pop cx
			pop es
			pop si
			pop ds
			pop dx	
			pop ax
			ret 
	
	 initialscreen: push bx
			push es
			push ds
			push cx
			push si
			push di
			push ax
				jmp short initbeg
				start_label: db 'start'
				quit_label: db ' quit'

		       initbeg:	mov bx, 0b800h
				mov es, bx
				mov bx, cs
				mov ds, bx

				mov si, offset start_label
				mov di, 160*10+30*2
				mov cx, 5
			 copy1:	mov bl, ds:[si]
				mov es:[di], bl
				add di, 2
				inc si
				loop copy1				; write start
				
				add di, 4
				mov byte ptr es:[di], '*'		; select start
				mov byte ptr es:[di+1], 10000111b
				
				mov si, offset quit_label
				mov di, 160*12+30*2
				mov cx, 5
		 	 copy2:	mov bl, ds:[si]
				mov es:[di], bl
				add di, 2
				inc si
				loop copy2				; write quit
				
			select:	mov ah, 0				; read input
				int 16h

				cmp ah, 50h
				je to_quit
				cmp ah, 48h
				je to_start
				cmp ah, 1ch 
				je to_enter
				jmp short select

		       to_quit: mov di, 160*10 + 30*2+5*2 + 4
				mov byte ptr es:[di], ' '
				mov di, 160*12 + 30*2+5*2 + 4
				mov byte ptr es:[di], '*'
				mov byte ptr es:[di+1], 10000111b
				jmp short select

		      to_start: mov di, 160*12 + 30*2+5*2 + 4
				mov byte ptr es:[di], ' '
				mov di, 160*10 + 30*2+5*2 + 4
				mov byte ptr es:[di], '*'
				mov byte ptr es:[di+1], 10000111b
				jmp short select

		      to_enter: mov al, es:[160*10 + 30*2+5*2 + 4]	
				cmp al, '*'				; if * at start, game begin
				je game_begin
				jmp short initialret

		    game_begin: call clear				; clear screen and begin game
				call gamescreen

	    initialret: pop ax
			pop di
			pop si
			pop cx
			pop ds
			pop es
			pop bx
		       	ret

 start:	mov ax, stack
	mov ss, ax
	mov sp, 256
	mov ax, data
	mov ds, ax	

	call clear
	call initialscreen
	
	mov ax, 4c00h
	int 21h

 
 clear: push ds
	push si
	push bx
	push es
	push cx
	push di
		mov bx, data
		mov ds, bx

		mov bx, 0b800h
		mov es, bx
		mov bx, 0
		mov cx, 2000
	clears: mov byte ptr es:[bx], ' '
		mov byte ptr es:[bx+1], 00000111b
		add bx, 2
		loop clears

		mov di, 160*2 + 1
		mov cx, 80
    draw_edge1:	mov byte ptr es:[di], 00010000b
		add di, 2
		loop draw_edge1
		
		mov di, 160*24 + 1
		mov cx, 80
    draw_edge2:	mov byte ptr es:[di], 00010000b
		add di, 2
		loop draw_edge2

		mov di, 160*2 + 1
		mov cx, 22
    draw_edge3:	mov byte ptr es:[di], 00010000b
		add di, 160
		loop draw_edge3
		
		mov di, 160*2 + 79*2 + 1
		mov cx, 22
    draw_edge4:	mov byte ptr es:[di], 00010000b
		add di, 160
		loop draw_edge4
		

     draw_time: call print_time

		mov di, 160 + 76*2
		mov cx, 4
    draw_score: mov byte ptr es:[di], '0'
		mov byte ptr es:[di+1], 00000110b
		inc si
		add di, 2
		loop draw_score
		call print_score
	pop di
	pop cx
	pop es
	pop bx
	pop si
	pop ds
	ret

   update_time: push ax
			mov al, 0
			out 70h, al
			in al, 71h
			cmp al, current_sec[0]
			je update_time_end
			inc time[0]
			mov current_sec[0], al
update_time_end:	
		pop ax
		ret

    draw_snake: push ax
		push bx
		push es
		push cx
		push di
		push si
			mov bx, 0b800h
			mov es, bx 
			mov bx, data
			mov ds, bx
			mov si, 0
			mov cx, len
		 draws: mov bl, ds:[si+snake]
			mov bh, ds:[si+snake+1]
			mov al, 160
			mul bh				; bh is row
			mov di, ax
			mov al, 2
			mul bl				; bl is column		
			add di, ax
			mov byte ptr es:[di+1], 01000000b
			add si, 2
			loop draws	
		pop si
		pop di
		pop cx
		pop es
		pop bx
		pop ax
		ret
    
    draw_fruit: push bx
		push es
		push di
		push ax
			mov bx, 0b800h
			mov es, bx 
			mov bx, data
			mov ds, bx
			mov bl, ds:[fruit]
			mov bh, ds:[fruit+1]
			mov al, 160
			mul bh
			mov di, ax
			mov al, 2
			mul bl
			add di, ax
			mov byte ptr es:[di+1], 01100000b
		pop ax
		pop di
		pop es
		pop bx
		ret

 refresh_fruit: push ax
		push bx
		push ds
		push si
			mov bx, data
			mov ds, bx
			mov bl, 78
			call getRandom
			inc ah
			mov byte ptr ds:[fruit], ah
			mov bl, 21
			call getRandom
			add ah, 3
			mov byte ptr ds:[fruit+1], ah
		pop si
		pop ds
		pop bx
		pop ax
		ret

  update_snake: push bx
		push ds
		push si 
		push ax
		push cx
			mov bx, data
			mov ds, bx

			call draw_snake
			call draw_fruit

			cmp al, 0
			je len_no_change
			cmp al, 1
			je len_change
	
	 len_no_change: mov si, 0				; snake head
			mov bl, ds:[si+snake]			; bx store previous block
			mov bh, ds:[si+snake+1]
			cmp ah, 48h
			je moveup
			cmp ah, 50h
			je movedown
			cmp ah, 4bh
			je moveleft
			cmp ah, 4dh
			je moveright
			jmp short update_snake_ret

			moveup: dec byte ptr ds:[si+snake+1]		; move up (row - 1)
				jmp short movebody
		      movedown:	inc byte ptr ds:[si+snake+1]		; move down (row + 1)
				jmp short movebody
		      moveleft: dec byte ptr ds:[si+snake]		; move left (column - 1)
				jmp short movebody
		     moveright:	inc byte ptr ds:[si+snake]		; move right (column + 1)
				jmp short movebody

		      movebody: mov cx, len
				dec cx				; update body after head
				jcxz update_snake_ret
				mov si, 2
		        movelp: mov al, snake[si]
				mov ah, snake[si+1]
				mov snake[si], bl
				mov snake[si+1], bh
				mov bx, ax			; exchange data in bx and ds:[si]
				add si, 2
				loop movelp
				jmp update_snake_ret				

	    len_change:	mov si, len
			mov di, si
			add di, si
			mov al, snake[di-2]
			mov ah, snake[di-1]
			inc al
			mov snake[di], al
			mov snake[di+1], ah
			inc si
			mov ds:[len], si			; length increase
			inc ds:[score]				; increase score		
			call refresh_fruit
			jmp len_no_change
			
update_snake_ret: pop cx
		  pop ax
		  pop si
		  pop ds
		  pop bx
		  ret

 delay: push ax
	push dx
	mov ax, 8000h
	mov dx, 1
	delays:	sub ax, 1
		sbb dx, 0
		cmp ax, 0
		jne delays
		cmp dx, 0
		jne delays
	pop dx
	pop ax
	ret

getInput: push bx
	  push ax
	  mov al, 0
	  mov ah, 1
	  int 16h
	  cmp ah, 1
	  je getInputEnd
	  mov al, 0	
	  mov ah, 0
	  int 16h
	  pop bx
	  pop bx
	  jmp short getInputRet
getInputEnd: pop ax
	     pop bx
getInputRet: ret 

	; store random number in ah
	; bl-1 is the upperbound of random rumber
getRandom: mov ax, 0
	   out 43h, al
	   in al, 40h
	   in al, 40h
           in al, 40h
	   div bl
	   ret	

 print_time: 
	push bx
	push cx
	push di
	push ax
	push dx
	push es
	push ds
		mov bx, 0b800h
		mov es, bx
		mov di, 160+4*2
		mov ax, ds:[time]
		mov dx, 0
		mov cx, 60
		call divdw			; ax is minute, cx is second
		push ax				; minute in stack
		mov ax, cx
print_second_lp: 
		mov dx, 0
		mov cx, 10
		call divdw
		add cl, 30h
		mov es:[di], cl
		mov byte ptr es:[di+1], 6
		sub di, 2
		cmp ax, 0
		jne print_second_lp
		
		mov byte ptr es:[di], '0'
		mov byte ptr es:[di+1], 6
		mov di, 160+2*2
		mov byte ptr es:[di], ':'
		mov byte ptr es:[di+1], 6	; print :
		sub di, 2
		
		pop ax
print_minute_lp: 
		mov dx, 0
		mov cx, 10
		call divdw
		add cl, 30h
		mov es:[di], cl
		mov byte ptr es:[di+1], 6
		sub di, 2
		cmp ax, 0
		jne print_minute_lp
		
		cmp di, 160
		jne print_time_end
		mov byte ptr es:[di], '0'
		mov byte ptr es:[di+1], 6
print_time_end:	
	pop ds
	pop es
	pop dx
	pop ax
	pop di
	pop cx
	pop bx
	ret

 print_score: 
	push bx
	push cx
	push di
	push ax
	push dx
	push es
	push ds
		mov bx, 0b800h
		mov es, bx
		mov di, 160+79*2
		mov ax, ds:[score]
print_score_lp:	mov dx, 0
		mov cx, 10
		call divdw
		add cl, 30h
		mov es:[di], cl
		mov byte ptr es:[di+1], 6
		sub di, 2
		cmp ax, 0
		jne print_score_lp
	pop ds
	pop es
	pop dx
	pop ax
	pop di
	pop cx
	pop bx
	ret

	; precondition:
	; ax -> low 16 bits of divident
	; dx -> high 16 bits of divident
	; cx -> divisor
	; postcondition:
	; ax -> low 16 bits of result
	; dx -> high 16 bits of result
	; cx -> remainder
 divdw: push bx
	
	push ax			; push L
	mov ax, dx
	mov dx, 0
	div cx			; ax = quotient, dx = remainder
	mov bx, ax		; bx = quotient of int(H/N)
	pop ax			; ax = L, dx = rem(H/N)
	div cx			; ax = quotient of (rem(H/N)*65536+L)/N, dx = remainder of (rem(H/N)*65536+L)/N
	mov cx, dx		; cx = remainder of X/N
	mov dx, bx	
	
	pop bx
	ret

	; for debug purpose
  prax: push es
        push bx
	push di	
	push ax
	push cx
		mov bx, 0b800h
		mov es, bx
		mov di, 160*18+40*2
		mov cx, 16
       prax_lp: shl ax, 1
		pushf	
		pop bx
		mov bh, 0
		and bl, 00000001b
		add bl, 30h
		mov es:[di], bl
		mov byte ptr es:[di+1], 2
		add di, 2
		loop prax_lp
	pop cx
  	pop ax
	pop di
    	pop bx
	pop es
  	ret 



code ends
end start
















