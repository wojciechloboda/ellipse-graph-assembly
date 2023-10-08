	
	DATA segment

	error_msg db "Bad args!$"
	center_x dw ? ;
	center_y dw ?
	k db ?
	a dw ?
	b dw ?
	X_p dw ?
	Y_p dw ?
	TwoASquared dd 00
	TwoBSquared dd 00
	X dw 00
	Y dw 00
	XChange dd 00
	YChange dd 00
	EllipseError dd 00
	StoppingX dd 00
	StoppingY dd 00
	registers dw 00
	mem32a dd 00

	DATA ends

	code segment

start:
	mov ax, seg DATA
	mov ds, ax

	mov ax, seg STACK
	mov ss, ax
	mov sp, offset wstos  

	call parse_arguments

	mov al, 13h
	mov ah, 0 ;graphic mode 320x200
	int 10h

	mov word ptr ds:[center_x], 160 ;center of a coordinate system
	mov word ptr ds:[center_y], 100 

input_loop: ;user input loop
	in al, 60h
	cmp al, 1

	je end_without_g

	cmp al, 75 ;left arrow
	je dec_a

	cmp al, 72 ;up arrow
	je inc_b

	cmp al, 80 ;down arrow
	je dec_b

	cmp al, 77 ;right arrow
	je inc_a

draw: ;;
	mov al, 13h
	mov ah, 0 ;graphic mode for clean up
	int 10h

	call draw_axis ;drawing axis 
	call draw_ellipse ;drawing ellipse

	xor ax, ax
	int 16h ;wait for any button
	jmp input_loop

end_without_g:
	mov ax,0003h
 	int 10h
end_prog:
	mov al, 0
	mov ah, 4ch                  ; program end
	int 21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; semiaxis length change
inc_a:
	mov ax, word ptr ds:[a]
	cmp ax, 160
	jae draw
	inc ax
	mov word ptr ds:[a], ax
	jmp draw
dec_a:
	mov ax, word ptr ds:[a]
	cmp ax, 1
	jbe draw
	dec ax
	mov word ptr ds:[a], ax
	jmp draw
inc_b:
	mov ax, word ptr ds:[b]
	cmp ax, 100
	jae draw
	inc ax
	mov word ptr ds:[b], ax
	jmp draw
dec_b:
	mov ax, word ptr ds:[b]
	cmp ax, 1
	jbe draw
	dec ax
	mov word ptr ds:[b], ax
	jmp draw

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
light_pixel:
	push bp
	mov bp, sp	

	mov ax, 0a000h
	mov es, ax
	mov ax, word ptr ds:[Y_p]
	mov bx, 320
	mul bx
	mov bx, word ptr ds:[X_p]
	add bx, ax
	mov al, byte ptr ds:[k]
	mov byte ptr es:[bx], al

	pop bp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_ellipse: ; Bresenham algorithm implementation for drawing a ellipse
	finit ; init math coprocessor

	;;;;;;;;;;;;;; Kalkulacja pierwszej czeście punktów f'(x) > -1
	mov word ptr ds:[mem32a], 00
	mov word ptr ds:[mem32a + 2], 00

	mov word ptr ds:[StoppingX], 00
	mov word ptr ds:[StoppingX + 2], 00

	mov word ptr ds:[StoppingY], 00
	mov word ptr ds:[StoppingY + 2], 00

	mov word ptr ds:[YChange], 00
	mov word ptr ds:[YChange + 2], 00

	mov word ptr ds:[XChange], 00
	mov word ptr ds:[XChange + 2], 00

	mov word ptr ds:[EllipseError], 00
	mov word ptr ds:[EllipseError + 2], 00
	
	mov ax, 2h
	mov word ptr ds:[TwoASquared], ax
	fild dword ptr ds:[TwoASquared]
	mov ax, word ptr ds:[a]
	mov word ptr ds:[TwoASquared], ax
	fimul dword ptr ds:[TwoASquared]
	fimul dword ptr ds:[TwoASquared]
	fistp dword ptr ds:[TwoASquared]

	mov ax, 2h
	mov word ptr ds:[TwoBSquared], ax
	fild dword ptr ds:[TwoBSquared]
	mov ax, word ptr ds:[b]
	mov word ptr ds:[TwoBSquared], ax
	fimul dword ptr ds:[TwoBSquared]
	fimul dword ptr ds:[TwoBSquared]
	fistp dword ptr ds:[TwoBSquared]

	mov ax, word ptr ds:[a]
	mov ds:[X], ax

	xor ax, ax
	mov ds:[Y], ax

	mov word ptr ds:[mem32a], 1h
	;mov word ptr ds:[mem32a], 0
	fild dword ptr ds:[mem32a]

	mov ax, 2h
	mul word ptr ds:[a]
	mov word ptr ds:[mem32a], ax
	fisub dword ptr ds:[mem32a]

	mov ax, word ptr ds:[b]
	mov word ptr ds:[mem32a], ax 
	fimul dword ptr ds:[mem32a]
	fimul dword ptr ds:[mem32a]
	fistp dword ptr ds:[XChange]

	mov ax, word ptr ds:[a]
	mul word ptr ds:[a]
	mov word ptr ds:[YChange], ax

	mov ax, 0h
	mov word ptr ds:[EllipseError], ax
	fild dword ptr ds:[TwoBSquared]
	mov ax, word ptr ds:[a]
	mov word ptr ds:[mem32a], ax
	fimul ds:[mem32a]
	fistp dword ptr ds:[StoppingX]

	mov ax, 00
	mov word ptr ds:[StoppingY], ax
	mov word ptr ds:[StoppingY], ax

	; first set of point calculation
	jmp first_loop_condition
first_loop:
	call plot_4_points

	inc word ptr ds:[Y]

	fild dword ptr ds:[StoppingY]
	fiadd dword ptr ds:[TwoASquared]
	fistp dword ptr ds:[StoppingY]

	fild dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[YChange]
	fistp dword ptr ds:[EllipseError]

	fild dword ptr ds:[YChange]
	fiadd dword ptr ds:[TwoASquared]
	fistp dword ptr ds:[YChange]

	fild dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[XChange]

	mov word ptr ds:[mem32a], 00
	mov word ptr ds:[mem32a + 2], 00

	ficomp dword ptr ds:[mem32a]

	fstsw ds:[registers]
	mov ax, word ptr ds:[registers]
	sahf
	ja decrement_x

first_loop_condition:
	fild dword ptr ds:[StoppingX] 
	ficomp dword ptr ds:[StoppingY] 
	fstsw ds:[registers]
	mov ax, word ptr ds:[registers]
	sahf
	ja first_loop

	;;;;;;;;;;;;;; Obliczenia dla 2 zbioru punktow f'(x) < -1

	mov word ptr ds:[mem32a], 00
	mov word ptr ds:[mem32a + 2], 00

	mov word ptr ds:[StoppingX], 00
	mov word ptr ds:[StoppingX + 2], 00

	mov word ptr ds:[StoppingY], 00
	mov word ptr ds:[StoppingY + 2], 00

	mov word ptr ds:[YChange], 00
	mov word ptr ds:[YChange + 2], 00

	mov word ptr ds:[XChange], 00
	mov word ptr ds:[XChange + 2], 00

	mov word ptr ds:[EllipseError], 00
	mov word ptr ds:[EllipseError + 2], 00


	mov ds:[X], 00

	mov ax, word ptr ds:[b]
	mov ds:[Y], ax

	mov word ptr ds:[mem32a], 1h
	fild dword ptr ds:[mem32a]

	mov ax, 2h
	mul word ptr ds:[b]
	mov word ptr ds:[mem32a], ax
	fisub dword ptr ds:[mem32a]

	mov ax, word ptr ds:[a]
	mov word ptr ds:[mem32a], ax 
	fimul dword ptr ds:[mem32a]
	fimul dword ptr ds:[mem32a]
	fistp dword ptr ds:[YChange]

	mov ax, word ptr ds:[b]
	mul word ptr ds:[b]
	mov word ptr ds:[XChange], ax

	mov ax, 0h
	mov word ptr ds:[EllipseError], ax

	fild dword ptr ds:[TwoASquared]
	mov ax, word ptr ds:[b]
	mov word ptr ds:[mem32a], ax
	fimul ds:[mem32a]
	fistp dword ptr ds:[StoppingY]

	mov ax, 00
	mov word ptr ds:[StoppingX], ax
	mov word ptr ds:[StoppingX], ax

	;
	jmp second_loop_condition
second_loop:
	call plot_4_points
	inc word ptr ds:[X]

	fild dword ptr ds:[StoppingX]
	fiadd dword ptr ds:[TwoBSquared]
	fistp dword ptr ds:[StoppingX]

	fild dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[XChange]
	fistp dword ptr ds:[EllipseError]

	fild dword ptr ds:[XChange]
	fiadd dword ptr ds:[TwoBSquared]
	fistp dword ptr ds:[XChange]

	fild dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[YChange]
	ftst
	FISTP ds:[mem32a]

	fstsw ds:[registers]
	mov ax, word ptr ds:[registers]
	sahf
	jae decrement_y

second_loop_condition:
	fild dword ptr ds:[StoppingX] 
	ficomp dword ptr ds:[StoppingY] 
	fstsw ds:[registers]
	mov ax, word ptr ds:[registers]
	sahf
	jbe second_loop
	ret

decrement_x:
	dec word ptr ds:[X]

	fild dword ptr ds:[StoppingX]
	fisub dword ptr ds:[TwoBSquared]
	fistp dword ptr ds:[StoppingX]

	fild dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[XChange]
	fistp dword ptr ds:[EllipseError]

	fild dword ptr ds:[XChange]
	fiadd dword ptr ds:[TwoBSquared]
	fistp dword ptr ds:[XChange]

	jmp first_loop_condition

decrement_y:
	dec word ptr ds:[Y]

	fild dword ptr ds:[StoppingY]
	fisub dword ptr ds:[TwoASquared]
	fistp dword ptr ds:[StoppingY]

	fild dword ptr ds:[EllipseError]
	fiadd dword ptr ds:[YChange]
	fistp dword ptr ds:[EllipseError]

	fild dword ptr ds:[YChange]
	fiadd dword ptr ds:[TwoASquared]
	fistp dword ptr ds:[YChange]

	jmp second_loop_condition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
plot_4_points:
	mov byte ptr ds:[k], 2
	mov ax, ds:[X] 
	add ax, word ptr ds:[center_x]
	mov word ptr ds:[X_p], ax
	mov ax, word ptr ds:[center_y]
	sub ax, word ptr ds:[Y]
	mov word ptr ds:[Y_p], ax
	call light_pixel

	mov ax, ds:[X] 
	add ax, word ptr ds:[center_x]
	mov word ptr ds:[X_p], ax
	mov ax, word ptr ds:[center_y]
	add ax, word ptr ds:[Y]
	mov word ptr ds:[Y_p], ax
	call light_pixel 

	mov ax, ds:[center_X] 
	sub ax, word ptr ds:[X]
	mov word ptr ds:[X_p], ax
	mov ax, word ptr ds:[center_y]
	sub ax, word ptr ds:[Y]
	mov word ptr ds:[Y_p], ax
	call light_pixel 

	mov ax, ds:[center_x] 
	sub ax, word ptr ds:[X]
	mov word ptr ds:[X_p], ax
	mov ax, word ptr ds:[center_y]
	add ax, word ptr ds:[Y]
	mov word ptr ds:[Y_p], ax
	call light_pixel 
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
draw_axis:
	mov byte ptr ds:[k], 8
	mov cx, 199
	mov ax, word ptr ds:[center_x]
	mov word ptr ds:[X_p], ax
draw_vert:
	mov word ptr ds:[Y_p], cx
	call light_pixel
	loop draw_vert
	call light_pixel

	mov cx, 319
	mov ax, word ptr ds:[center_y]
	mov word ptr ds:[Y_p], ax
draw_horiz:
	mov word ptr ds:[X_p], cx
	call light_pixel
	loop draw_horiz
	call light_pixel
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
clear_screen:
	mov al, 13h
	mov ah, 0
	int 10h
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
parse_arguments: ;parsing arguments, both arguments must be natural numbers > 0, <= 200, arguments seperated by 1 space
	mov ah, 62h
	int 21h
	mov es, bx 
	mov bx, 80h
	mov al, es:[bx] ; acces to cmd arguments
	inc bx ;
	inc bx

	mov word ptr ax, 0h;
	mov cx, 0h
	mov dl, " "
first_arg_parsing:	;string to int 
	mov cl, byte ptr es:[bx]
	sub cx, 48
	cmp cx, 9
	jg bad_arg
	cmp cx, 0
	jl bad_arg
	add ax, cx
	inc bx
	cmp byte ptr es:[bx], " "
	je end_of_parsing_first
	mov word ptr cx, 10
	mul cx
	jmp first_arg_parsing
end_of_parsing_first:
	cmp ax, 200
	ja bad_arg

	mov dl, 2
	div dl
	mov ah, 0

	cmp ax, 0
	je bad_arg

	mov word ptr ds:[a], ax

	inc bx;
	mov word ptr ax, 0h;
	mov cx, 0h
second_arg_parsing:	
	mov cx, 0h
	mov cl, byte ptr es:[bx]

	sub cx, 48
	cmp cx, 9
	jg bad_arg
	cmp cx, 0
	jl bad_arg

	add ax, cx
	inc bx
	cmp byte ptr es:[bx], 13
	je end_of_parsing_second

	mov word ptr cx, 10
	mul cx
	jmp second_arg_parsing
end_of_parsing_second:
	cmp ax, 200
	ja bad_arg
	mov dl, 2
	div dl
	mov ah, 0
	cmp ax, 0
	je bad_arg

	mov word ptr ds:[b], ax
	ret

bad_arg: ;;; in case of bad args
	mov ah, 09h
	mov dx, offset error_msg
	int 21h

	jmp end_prog
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	code ends  

;......................................
	STACK segment stack          

	dw 200 dup(?)
	wstos dw ?

	STACK ends
	end start
