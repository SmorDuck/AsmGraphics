sta segment stack
db 256 dup(?)
sta ends

dan segment
	menu_text db '1. Create and save a shape in a file', 0dh, 0ah, '2. Read an image of a shape from a file', 0dh, 0ah, 'Select an option: ','$'
 	sec db 'photo is saved', 0dh, 0ah, '$'
	final db 'press R to go to the menu', 0dh, 0ah, 'press ESC to exit', '$'

 	ErrorMsg db 'error with BMP', 13, 10,'$'
  	filename db 'kpp.bmp',0
	filehandle dw 0
 	bfsize = 54+256*4+320*200  ;размер BMP размер заголовков + размер палитры + размер данных
  	header label byte    ;Header db 54 dup (0)
BMP_file_header      db    "BM"           ; сигнатура 
                     dd    bfsize         ; размер файла 
                     dw    0,0            ; 0
                     dd    bfoffbits      ; адрес начала BMP_data
; информационный заголовок
BMP_info_header      dd    bi_size        ; размер BMP_info_header
                     dd    320            ; ширина 
                     dd    200            ; высота 
                     dw    1              ; число цветовых пикселей
                     dw    8              ; число бит на пиксель
                     dd    0              ; метод сжатия данных
                     dd    320*200        ; размер данных
                     dd    0B13h          ; разрешение по X (пиксель на метр)
                     dd    0B13h          ; разрешение по Y (пиксель на метр)
                     dd    0              ; число используемых цветов (0 - все)
                     dd    0              ; число важных цветов (0 - все)
 	bi_size = $-BMP_info_header             ; размер BMP_info_header
  	bfoffbits = $-BMP_file_header+256*4     ; размер заголовков + размер палитры
  	Palette db 256*4 dup (0)       ;размер палитры
  	ScrLine db 320*200 dup (0)	
dan ends

cod segment
	assume cs:cod,ds:dan,ss:sta

handles proc    
    	sub dx,80   ;проверка координат y
    	ja @test_0
    	jb exitmouse

@test_0:
    	mov ax,3 
    	int 33h

    	sub dx,160 ;проверка координат y
   	jb @test0
    	ja exitmouse
 
@test0:
    	mov ax,3 
    	int 33h
    
    	sub cx,160   ;проверка координат x
    	jb @test
    	ja exitmouse

@test:
    	push es
    	push ds
    	push bp	

    	mov ax,dan
    	mov ds,ax
    	mov es,ax

;сохранение файла	
        call ScreenShot
	call CreateFile
	mov ax,1    ;показать мышь
	int 33h

	mov ax,1300h     ;печатать строки
	mov bl,02h   ;цвет
	mov bh,0    ;страница 
	mov cx,14   ;длина строки
	mov dh,160    ;y
	mov dl,241    ;x
	mov bp,offset sec   ;строка 
	int 10h

	pop bp
	pop ds
	pop es
exitmouse:
	retf
handles endp

ScreenShot proc
	mov ax,1017h            ; функция 1017h - чтение палитры VGA
        mov bx,0                ; ­начиная с регистра палитры 0,
        mov cx,256		; все 256 регистов
        mov dx,offset Palette	; ­начало палитры в BMP
        int 10h                 ; видео сервис BIOS 
;перевести палитру из формата (3 байта на цвет, в каждом байте 6 значимых бит),
;в формат, используемый в BMP файлах (4 байта на цвет, в каждом байте 8 значимых бит)
        std   ; движение от конца к началу
        mov si,offset Palette+256*3-1   ; SI- конец 3-байтной палитры
        mov di,offset Palette+256*4-1   ; DI - конец 4-байтной палитры
        mov cx,256                         ; CX - число цветов
adj_pal:
        mov al,0
        stosb                           ; записать четвертый байт (0)
        lodsb                           ; прочитать третий байт
        shl al,2                 ; масштабировать до 8 бит
        push ax
        lodsb                           ; прочитать второй байт
        shl al,2                 ; масштабировать до 8 бит
        push ax
        lodsb                           ; прочитать третий байт
        shl al,2                 ; масштабировать до 8 бит
        stosb                           ; и записать эти три байта 
        pop ax                   ; в обратном порядке
        stosb
        pop ax
        stosb
loop adj_pal
 
; копирование видеопамяти в BMP.
; в формате BMP строки изображения записываются от последней к первой, так что
; первый байт соотв. нижнему левому пикселю 
        cld                             ; движение от начала к концу (по строке)
        push 0A000h
        pop ds
        mov si,320*200           ; DS:SI - ­начало последней строки на экране 
        mov di,offset ScrLine    ; ES:DI - ­начало данных в BMP
        mov dx,200               ; счетчик строк
bmp_write_loop:
        mov cx,320/2             ; счетчик символов в строке
        rep movsw                ; копировать целыми словами, так быстрее
        sub si,320*2             ; перевести SI­ на начало предыдущей строки
        dec dx                   ; уменьшить сетчик строк,
        jnz bmp_write_loop       ; если 0 - выйти из цикла
	mov ax,es
	mov ds,ax
        ret
endp

CreateFile proc
	mov ah,6Ch               ; функция DOS 6Ch
        mov bx,2                 ; доступ - ­на чтение/запись
        mov cx,0                 ; атрибуты - обычный файл
        mov dx,12h            ; заменять файл, если он существует, создать, если нет
        mov si,offset filename   ; DS:SI - имя файла 
	int 21h                  ; создать/открыть файл
	;mov filehandle, ax
	mov bx,ax                ; идентификатор файла - в BX

        mov ah,40h               ; функция DOS 40h
        mov cx,bfsize            ; размер BMP-файла 
        mov dx,offset header     ; DS:DX - буфер для файла 
        int 21h                  ; записать в файл
 
        mov ah,68h               ; сбросить буфер на диск
        int 21h
 
        mov ah,3Eh               ; записать файл
        int 21h

	ret
endp

beg:
  	mov ax, dan ; через регистр ax в регистр dx засылается начальный
  	mov ds,ax ; адрес сегмента данных
	mov es,ax

main_menu:
  	;очистка экрана
  	mov ax,0600h
  	mov bh,15
  	mov cx,00h
  	mov dx,184fh
  	int 10h
  	;-----------------------
	
	mov ax,13h; устанавливаю режим 
    	int 10h

  	;вывод меню
  	mov ah,09h
  	mov dx, offset menu_text
  	int 21h

  	;ввод пользователя
  	mov ah,01h
  	int 21h

  	;обработка выбора
  	cmp al,'1'
  	je draw_and_save
  	cmp al,'2'
  	je read_from_file
  	cmp al,27
  	jne main_menu
  	jmp exit ;если выбран некорректный пункт, вернуться к главному меню

draw_and_save:
  	push 0A000h; позиционирую ES на область графического видеоадаптера
  	pop es
  	push cs
  	push cx
  	push dx
  
 	mov si,80 ;высота
  	mov dx,160 ;координаты по y
  	metka:
    		mov cx,80 ;длинна
    		mov ah,0Ch
    		mov al,011b 
    		mov bh,0
    		line_hor:
      			int 10h
    		loop line_hor
    		dec dx
    		cmp dx,si
  	jnz metka

;клик мыши
  	mov ax,0  ;инициализация мыши
  	int 33h
    
  	mov ax,1  ;показать курсор
  	int 33h

  	mov ax,000Ch  ;установка обработчика событий мыши
  	mov cx,0002h     ;событие - нажатие левой мыши
  	mov dx, offset handles   ; ES:DX - адрес обработчика
 	mov di,dx 
  	push cs   ;перемещаем cs в es
 	pop  es
  	int 33h

  	mov ax,ds
 	mov es,ax

 	mov ah,01h   ;вывод символа 
  	int 21h 

  	mov ax,0014h
  	mov cx,0000h ;удалить обработчик событий мыши
  	int 33h

  	jmp main_menu

read_from_file:
  	;Process BMP file

	mov ah, 3Dh       ;call OpenFile
	xor al, al
	mov dx, offset filename
	int 21h
	mov filehandle, ax
	
	mov ah,3fh       ;call ReadHeader
    	mov bx, filehandle
    	mov cx,54
   	mov dx,offset Header
    	int 21h
	
	mov ah,3fh      	;call ReadPalette
   	mov cx,400h;256 colors * 4 bytes (400h)
    	mov dx,offset Palette
    	int 21h

	; Скопируйте цветовую палитру в видеопамять
    	; Номер первого цвета должен быть отправлен на порт 3C8h
    	; Палитра отправляется на порт 3C9h
   	mov si,offset Palette     ;call CopyPal
    	mov cx,256
    	mov dx,3C8h
    	mov al,0
    	; Скопируйте начальный цвет в порт 3C8h
    	out dx,al
    	; Скопируйте саму палитру в порт 3C9h
    	inc dx
    	PalLoop:
        ;Примечание: Цвета в BMP-файле сохраняются как значения BGR, а не RGB.
    		mov al,[si + 2]              ; Получаем красное значение.
    		shr al,2    ;Макс. значение равно 255, но палитра видео макс.
    		; значение равно 63. Следовательно, делим на 4.
    		out dx,al      ; Отправь это.
    		mov al,[si+1]   ;  Получите зеленое значение.
    		shr al,2
   		out dx,al ; Отправь это.
    		mov al,[si] ;  Получите синее значение.
    		shr al,2
    		out dx,al    ;Отправь это.
    		add si,4       ;Укажите на следующий цвет.
    	loop PalLoop

	; Графика в формате BMP сохраняется в перевернутом виде.
    	; Прочитайте графику построчно (200 строк в формате VGA),
    	; отображение линий снизу вверх.
    	mov ax, 0A000h     ;call CopyBitmap
    	mov es, ax
    	mov cx,200
    	PrintBMPLoop:
    		push cx
    		; di = cx*320, укажите на правильную линию экрана
    		mov di,cx
    		shl cx,6
    		shl di,8
    		add di,cx
    		; Прочтите одну строчку
    		mov ah,3fh
    		mov cx,320
    		mov dx,offset ScrLine
    		int 21h
    		; Скопируйте одну строку в видеопамять
    		cld 
    		; Флажок четкого направления для movsb
    		mov cx,320
    		mov si,offset ScrLine
    		rep movsb 
    		;Скопируйте строку на экран
    		;rep movsb совпадает со следующим кодом:
    		;mov es:di, ds:si
    		;inc si
    		;inc di
    		;dec cx
    		;loop until cx=0
    		pop cx
    	loop PrintBMPLoop

	xor ax,ax    ;ожидания нажатия
	int 16h

	jmp main_menu

exit:
  	mov  ax,3  ; возврат в текстовый режим
  	int  10h

  	mov ah,01h ; организация точки останова
 	int 21h ; (программа прекращает выполнение кода до нажатия любой клавиши)
 	mov ah,4ch ; обработка окончания
  	int 21h ; программы
cod ends
end beg