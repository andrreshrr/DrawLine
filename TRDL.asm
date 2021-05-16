;Оськин Андрей, группа А-08-18

EnterSymb EQU 0Dh, 0Ah
.model small 	;по сегменту данных на стек, данные и код

.stack 100h	;256 байт под стек 

.data

hello_message db 'Hello, user!', EnterSymb, EnterSymb, 'Manual:', EnterSymb, 'Left mouse button - draw first point / draw line',EnterSymb, 'Right mouse button - clear screen', EnterSymb,'Center Mouse Button - change color', EnterSymb, 'Press ESC to exit', EnterSymb, EnterSymb,'Press ENTER to continue...$'

x0 dw (?) 
y0 dw (?)
x1 dw (?)
y1 dw (?) 
dirY dw (?)
dirX dw (?)
deltaX dw (?)
deltaY dw (?)
error dw 0
color db 1h
count db 0

.code


;------------------------------ПРОЦЕДУРА РИСУЮЩАЯ ПИКСЕЛЬ-------------------------------;
;			es - начало видеопамяти						;
;			cx - x-координата						;
;			dx - y-координата						;
;			портит: ax, di, bx, dx						;


drawpix proc near   
		mov ax, 140h	
		mul dx			; ax=140h*номер строки	 
		mov di, cx
		add di, ax		;тек пиксел = 140h*номер строки + номер колонки
		mov bl, color		;bl - цвет пикселя
		mov es:[di], bl		;вывод
		ret
endp drawpix
;---------------------------------------------------------------------------------------;



;------------------------------ПРОЦЕДУРА РЕАЛИЗУЮЩАЯ АЛГОРИТМ БРЕЗЕНХЕМА----------------;
;			cx - x1-координата						;
;			dx - y1-координата						;
;			в x0 и y0 лежат корректные данные				;
;			портит: ax, cx, bx, dx						;
;			dirX, dirY, x0, y0, error					;	;

bresenham_alg proc near
		sub cx, x0		;cx = x1 - x0
		cmp cx, 0
		jge m1
		neg cx
		mov ax, -1
		jmp m2 
	m1:
		mov ax, 1
	m2:
		mov dirX, ax		;dirX = x1>x0?1:-1
		mov deltaX, cx		;deltaX = abs (x1-x0)
		
		sub dx, y0		;dx = y1 - y0
		cmp dx, 0
		jge m3
		mov ax, -1
		jmp m4 
	m3:
		neg dx
		mov ax, 1
	m4:
		mov dirY, ax		;dirY = y1>y0?1:-1
		mov deltaY, dx		;deltaY = -abs (y1-y0)
		
		mov bx, deltaX
		add bx, deltaY
		mov error, bx
			
	draw_line:
		mov cx, x0
		mov dx, y0
		push dx
		call drawpix		;вывод точки (x0, y0)
		pop dx
;-------------------------------------------------------

		cmp cx, x1		;если текущий X0 = X1 и Y0=Y1
		jne fine		;то линия нарисована и пора выйти		
		cmp dx, y1		
		jne fine					
 		ret
;-------------------------------------------------------
	fine:
		mov bx, error
		sal bx, 1		;bx=2*error

		mov ax, deltaY		
		cmp bx, ax		;if 2*err >=deltaY
		jl esc_block_one	
					;error+=deltaX
		add error, ax		;x0+=dirX	
		mov ax, dirX
		add x0, ax
	
	esc_block_one:

		mov ax, deltaX
		cmp bx, ax		;if 2*error<=deltaX
		jg esc_block_two	
					;error+=deltaY
		add error, ax		;y0+=dirY				
		mov ax, dirY
		add y0, ax

	esc_block_two:

	jmp draw_line
	
	ret
endp bresenham_alg
;---------------------------------------------------------------------------------------;

;-----------------------------ОБРАБОТЧИК КЛАВИШ МЫШИ (должна быть процедура far)--------

mpress proc far
	mov ax,     0002h	;спрятать курсор мыши
        int 33h	

	mov ax, @data		;инициализация ds
	mov ds, ax

	mov ax, 0A000h		;установка ES на начало видеопамяти
	mov es, ax		
	
	mov ah, 03h 		;чтение статуса мыши, bx - какая кнопка нажата
	int 33h			;cx / 2 - column, dx - row
	
	cmp bx, 01b		;01 - left_m; 10 - right_m; 100 - center_m
	je left

	cmp bx, 10b
	je right
;---------------------ОБРАБОТКА ЦЕНТРАЛЬНОГО ЩЕЛЧКА------------------------------

	center:
		mov bl, color		;считываем цвет
		inc bl			;изменяем цвет
		mov color, bl		;загружаем новый цвет   
		jmp endo		;переход в конец обработчика
	
;---------------------ОБРАБОТКА ПРАВОГО ЩЕЛЧКА------------------------------
	right:
		mov bl, 0	;обнуление счетчика точек
		mov count, bl

		mov  ax, 13h	;очистка экрана
	 	int  10h   
		jmp endo	;переход в конец обработчика	
		
;-------------------ОБРАБОТКА ЛЕВОГО ЩЕЛЧКА--------------------------------
	left:
		
		cmp count, 0		;первая точка или вторая?
		jne second_point
			
	first_point:		;обработка первой точки
		sar cx, 1
		mov x0, cx	;сохраняем координаты первой точки 
		mov y0, dx	
		call drawpix	;выводим точку
		inc count
		jmp endo

	second_point:		;обработка второй точки			
		mov count, 0	;обнуляем счетчик точек		
		sar cx, 1
		mov x1, cx	;сохраняем координаты второй точки
		mov y1, dx
	
		call bresenham_alg	;вызываем процедуру, рисующую линию по алгоритму брезенхема	
 	
	endo:		
		mov     ax,     0001h	;сделать видимым курсор мыши
        	int     33h		;
		ret
mpress endp




START:
;-----------------------------НАЧАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ------------------------

	mov ax, @data		;начальная инициализицая
	mov ds, ax		;регистра DS
	push cs
	pop es

	mov ax, 03h		;очистка экрана
	int 10h			;
	
	mov ah, 9h			;вывод инструкции
	mov dx, offset hello_message
	int 21h
	
hello:	
	xor ah, ah		;ожидание нажатия клавиши
	int 16h
	cmp al, 27		;если ESC - выход из программы
	je exit_progr
	cmp al, 0Dh		;если ENTER - запуск основной программы
	jne hello
	
	mov         ax, 13h	; установка видеорежима 13h
        int         10h          ;320x200	256 цветов	
  	
	mov     ax,     0000h	;инициализации мыши, уст драйвера
        int     33h		;в ax статус, в bx число кнопок

        mov     ax,     0001h	;сделать видимым курсор мыши
        int     33h		;

	mov         ax,000Ch     	; установить обработчик событий мыши
	mov         cx, 101010b         ; событие - нажатие правой или левой кнопки
        mov         dx, offset mpress  	; ES:DX - адрес обработчика
        int         33h
	
wait_block:
	xor ah, ah		;ожидание нажатия клавиши выхода
	int 16h
	cmp al, 27
	jne wait_block
	
exit_progr:
	mov ax, 03h		;возвращение в стандартный видеорежим
	int 10h			;
		
	mov         ax,000Ch    ; сбросить обработчик событий мыши
	mov         cx, 0b       
        int         33h	

	mov ah,4ch		;функция выхода из кода  
	int 21h			;(AH=4Ch, Al = exit Code)
        
END START