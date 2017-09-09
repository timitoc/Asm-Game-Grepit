; main.asm
bits 16

%include "syntax_macros.mac"
%include "kb_scancodes.mac"

%define WIDTH 320
%define HEIGHT 200

%define BEER_WIDTH 20 
%define MAX_Y 175 

%define SPEED_X 	10
%define SPEED_JUMP 	13
%define GRAVITY_Y	-1

; engine.asm
extern engine_set_init_callback
extern engine_set_shutdown_callback
extern engine_set_update_callback
extern engine_set_render_callback
extern init_engine
extern shutdown_engine
extern engine_mainloop
extern engine_signalstop

; renderer.asm
extern put_pixel
extern draw_rect
extern render_clear
extern render_bitblt
extern render_maskblt

; loader.asm
extern bmp_load
extern bmp_extract_mask
extern bmp_render_background
extern bmp_render
extern bmp_render_masked
%include "bmp_util.inc"

; sprite_util.asm
extern sprite_load
extern sprite_render
extern sprite_update
extern sprite_set_anim_fps_factor
extern sprite_set_anim_index
%include "sprite_util.inc"

; keyboard.asm
extern get_key_pressed

; util.asm
extern rand
extern memset
extern memcpy

%include "random.mac"

%define OBJ_VISIBLE	80h

%define MARIO_STATE_NONE		0
%define MARIO_STATE_RIGHT_LEFT	1h ; bit is set if right, else left
%define MARIO_STATE_WALK		2h
%define MARIO_STATE_JUMP		4h

%define MARIO_ANIM_WALK_RIGHT	0
%define MARIO_ANIM_WALK_LEFT	1
%define MARIO_ANIM_STAND_RIGHT	2
%define MARIO_ANIM_STAND_LEFT	3
%define MARIO_ANIM_JUMP_RIGHT	4
%define MARIO_ANIM_JUMP_LEFT	5

struc GameState
	.pos:		 resw 2
	.speed: 	 resw 2
	.accel: 	 resw 2
	.mario: 	 resb 1
	.coin:		 resb 1
	.win:   	 resb 1
	.crtRand:    resw 2
	.beerPos:    resw 2
	.beerSpeed:	 resw 2
	.beerActive: resb 1
	.isPepsi: resb 1
	.lifes: resb 1
endstruc
%define state(x) fs:game_state + GameState.%+ x
segment code use16 CLASS=code

wait_key:
	mov ah, 0
	int 16h
	ret

proc init_cb
	; load background bmp
	ccall bmp_load, segaddr(bg_bmp_filename), segaddr(bg_bmp_info), segaddr(bg_buffer)

	; load mario sprite
	ccall sprite_load, segaddr(mario_spr_filename), segaddr(mario_sprite), segaddr(mario_spr_bmp_store), segaddr(mario_spr_mask_store)

	ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_RIGHT
	ccall sprite_set_anim_fps_factor, segaddr(mario_sprite), 4
	ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_LEFT
	ccall sprite_set_anim_fps_factor, segaddr(mario_sprite), 4
	ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_STAND_RIGHT

	; load coin sprite
	ccall sprite_load, segaddr(coin_spr_filename), segaddr(coin_sprite), segaddr(coin_spr_bmp_store), segaddr(coin_spr_mask_store)

	; load pepsi sprite

	;ccall sprite_load, segaddr(pepsi_filename), segaddr(pepsi_sprite), segaddr(), segaddr(coin_spr_mask_store)

	; load beer bmp
	ccall bmp_load, segaddr(beer_filename), segaddr(beer_bmp), segaddr(beer_bmp_store)
	ccall bmp_extract_mask, segaddr(beer_bmp), segaddr(beer_bmp_store), 15, segaddr(beer_mask), segaddr(beer_mask_store)

	; load pepsi bmp
	ccall bmp_load, segaddr(pepsi_filename), segaddr(pepsi_bmp), segaddr(pepsi_bmp_store)
	ccall bmp_extract_mask, segaddr(pepsi_bmp), segaddr(pepsi_bmp_store), 15, segaddr(pepsi_mask), segaddr(pepsi_mask_store)

	ccall bmp_load, segaddr(heart_filename), segaddr(heart_bmp), segaddr(heart_bmp_store)
	ccall bmp_extract_mask, segaddr(heart_bmp), segaddr(heart_bmp_store), 15, segaddr(heart_mask), segaddr(heart_mask_store)

	
	; load dead screen
	ccall bmp_load, segaddr(dead_bmp_filename), segaddr(dead_bmp), segaddr(dead_bmp_store)
	ccall bmp_extract_mask, segaddr(dead_bmp), segaddr(dead_bmp_store), 15, segaddr(dead_mask), segaddr(dead_mask_store)
	

	xor ax, ax
endproc

proc shutdown_cb
	; maybe stuff here?
endproc

proc update_input
	movax fs, data

	ccall get_key_pressed, KB_ESC
	if {test ax, ax}, nz
		ccall engine_signalstop
	endif

	; read keyboard input
	if {ccall get_key_pressed, KB_RIGHT_ARROW}, {test ax, ax}, nz
		mov word [state(speed)], SPEED_X

		or word [state(mario)], MARIO_STATE_RIGHT_LEFT | MARIO_STATE_WALK
	elseif {ccall get_key_pressed, KB_LEFT_ARROW}, {test ax, ax}, nz
		mov word [state(speed)], -SPEED_X

		and word [state(mario)], ~MARIO_STATE_RIGHT_LEFT
		or word [state(mario)], MARIO_STATE_WALK
	else
		mov word [state(speed)], 0

		and word [state(mario)], ~MARIO_STATE_WALK
	endif
	
	mov ax, word [state(beerPos) + 2]
	add ax, word [state(beerSpeed) + 2]

	mov word [state(beerPos) + 2], ax

	if {cmp word [state(beerPos) + 2], HEIGHT}, ge
		generate_random_integer
		mov word [state(beerPos)], ax
		mov word [state(beerPos)+2], 10
		generate_random_integer
		getModulo ax, 5
	
		movax fs, data
		if {cmp byte [state(lifes)], 0}, g
			sub byte [state(lifes)], 1
		endif
		
		if {cmp ax, 0}, z
			mov byte [state(isPepsi)], 0
		else
			mov byte [state(isPepsi)], 1
		endif
	endif

	;add word [state(beerPos) + 2], word [state(beerSpeed) + 2]

	; if {ccall get_key_pressed, KB_UP_ARROW}, {test ax, ax}, nz
	; 	mov word [state(speed)+2], SPEED_X
	; elseif {ccall get_key_pressed, KB_DOWN_ARROW}, {test ax, ax}, nz
	; 	mov word [state(speed)+2], -SPEED_X
	; else
	; 	mov word [state(speed)+2], 0
	; endif

	if {ccall get_key_pressed, KB_SPACE}, {test ax, ax}, nz
		if {test byte [state(mario)], MARIO_STATE_JUMP}, z
			mov word [state(speed) + 2], SPEED_JUMP
			or byte [state(mario)], MARIO_STATE_JUMP
		endif
	endif
endproc

proc update_collisions
	movax fs, data

	if {cmp word [state(pos)], 262}, ge
		if {cmp word [state(pos)], 274}, le
			if {cmp word [state(pos) + 2], 62}, ge
				if {cmp word [state(pos) + 2], 94}, le
					and byte [state(coin)], ~OBJ_VISIBLE
					or byte [state(win)], OBJ_VISIBLE
				endif
			endif
		endif
	endif

	mov ax, word [state(pos)]  
	if {cmp ax, word [state(beerPos)]}, ge
		sub ax, word [state(beerPos)]
	else 
		mov ax, word [state(beerPos)]
		sub ax, word [state(pos)]
	endif

	if {cmp ax, BEER_WIDTH}, le
		mov ax, 1
	else
		mov ax, 0
	endif

	if {cmp word [state(beerPos) + 2], MAX_Y}, ge
		mov bx, 1
	else
		mov bx, 0
	endif

	and ax, bx
	if {cmp ax, 1}, z
		if {cmp byte [state(isPepsi)], 1}, z
			; nimika
		else
			if {cmp byte [state(lifes)], 3}, l
				add byte [state(lifes)], 1
			endif
		endif

		generate_random_integer
		mov word [state(beerPos)], ax
		mov word [state(beerPos)+2], 10
		generate_random_integer
		getModulo ax, 5
		
		if {cmp ax, 0}, z
			mov byte [state(isPepsi)], 0
		else
			mov byte [state(isPepsi)], 1
		endif

	endif

endproc

proc update_objects
	movax fs, data

	; update physics
	addax [state(speed)], [state(accel)]
	addax [state(speed) + 2], [state(accel) + 2]

	addax [state(pos)], [state(speed)]
	addax [state(pos) + 2], [state(speed) + 2]

	; limit to lower bound platform
	if {cmp word [state(pos) + 2], 16}, le
		mov word [state(pos) + 2], 16
		mov word [state(speed) + 2], 0

		and byte [state(mario)], ~MARIO_STATE_JUMP
	endif

	; limit left
	if {cmp word [state(pos)], 0}, le
		mov word [state(pos)], 0
	endif

	; limit right
	if {cmp word [state(pos)], 304}, ge
		mov word [state(pos)], 304
	endif 

	; limit top
	if {cmp word [state(pos)+2], 200}, ge
		mov word [state(pos)+2], 200
	endif

	if {test word [state(mario)], MARIO_STATE_JUMP}, nz
		if {test word [state(mario)], MARIO_STATE_RIGHT_LEFT}, nz
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_JUMP_RIGHT
		else
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_JUMP_LEFT
		endif
	elseif {test word [state(mario)], MARIO_STATE_WALK}, nz
		if {test word [state(mario)], MARIO_STATE_RIGHT_LEFT}, nz
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_RIGHT
		else
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_LEFT
		endif
	else
		if {test word [state(mario)], MARIO_STATE_RIGHT_LEFT}, nz
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_STAND_RIGHT
		else
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_STAND_LEFT
		endif
	endif
endproc

proc update_anims
	ccall sprite_update, segaddr(mario_sprite)
	ccall sprite_update, segaddr(coin_sprite)
endproc

proc update_cb
	ccall update_input
	ccall update_collisions
	ccall update_objects
	ccall update_anims
endproc

proc render_objects

	movax fs, data

	if {test byte [state(win)], OBJ_VISIBLE}, nz
		mov ax, HEIGHT
		sub ax, 16+41+64+30
		if {test byte [state(win)], OBJ_VISIBLE}, nz
			ccall bmp_render_masked, segaddr(beer_bmp), segaddr(beer_mask), 25, ax
		endif
	endif

	;movax fs, data
	;mov ax, HEIGHT
	;sub ax, 70
	;if {test byte [state(coin)], OBJ_VISIBLE}, nz
	;	ccall sprite_render, segaddr(coin_sprite), 270, ax
	;endif
	
	movax fs, data

	if {test byte [state(beerActive)], OBJ_VISIBLE}, nz
		;mov ax, HEIGHT
		;sub ax, [state(pos) + 2]
		;ccall sprite_render, segaddr(winner_bmp), word [state(beerPos)], word [state(beerPos) + 2]	
		if {cmp byte [state(isPepsi)], 0}, z
			ccall bmp_render_masked, segaddr(beer_bmp), segaddr(beer_mask), word [state(beerPos)], word [state(beerPos) + 2]
		else
			ccall bmp_render_masked, segaddr(pepsi_bmp), segaddr(pepsi_mask), word [state(beerPos)], word [state(beerPos) + 2]
		endif

	endif

	movax fs, data
	mov ax, HEIGHT
	sub ax, [state(pos) + 2]
	ccall sprite_render, segaddr(mario_sprite), word [state(pos)], ax

;	mov byte [state(lifes)], 2

	;cmp byte [state(lifes)], 3
	;jl l1
	;if {cmp byte [state(lifes)], 3}, ge
	;movax fs, data
	;ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 270, 10
	;endif
	;l1:

	;cmp byte [state(lifes)], 2
	;jl l2
	;movax fs, data
	;ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 285, 10
	;l2:
	;if {cmp byte [state(lifes)], 2}, ge
	;	movax fs, data
	;	ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 285, 10
	;endif
	;mov byte [state(lifes)], 3	
	;add byte [state(lifes)], 1

	movax fs, data
	;mov byte [state(lifes)], 2
	
	if {cmp byte [state(lifes)], 1}, z 
		movax fs, data
		ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 300, 10
	endif

	movax fs, data
	if {cmp byte [state(lifes)], 2}, z
		movax fs, data
		ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 300, 10
		ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 285, 10
	endif

	movax fs, data
	if {cmp byte [state(lifes)], 3}, z 
		movax fs, data
		ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 300, 10
		ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 285, 10
		ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 270, 10
	endif
	;ccall bmp_render_masked, segaddr(heart_bmp), segaddr(heart_mask), 285, 10

	; exit program
	if {cmp byte [state(lifes)], 0}, z
		mov ax, 0
		mov bx, 0
		;int 0x80
		;int 20h
		MOV AH, 4Ch ; Service 4Ch - Terminate with Error Code
		MOV AL, 0 ; Error code
		INT 21h ; Interrupt 21h - DOS General Interrupts
	endif

endproc

proc render_cb
	ccall render_clear

	ccall bmp_render_background, segaddr(bg_bmp_info)
	ccall render_objects
endproc

proc ..start
	movax fs, data
	;rseed DW 23 
	mov word [state(crtRand)], 41
	mov byte [state(lifes)], 3
	; mov ax, word [state(crtRand)]  
	; push engine callbacks
	ccall engine_set_init_callback, segaddr(init_cb)
	ccall engine_set_shutdown_callback, segaddr(shutdown_cb)
	ccall engine_set_update_callback, segaddr(update_cb)
	ccall engine_set_render_callback, segaddr(render_cb)

	; run engine
	ccall init_engine
	mov byte [state(lifes)], 3
	if {test ax, ax}, z
;		generate_random_integer
		;generate_random_integer
		;generate_random_integer



		;IMUL word [state(crtRand)], 1005 

		
		; eax = random % WIDTH


		ccall engine_mainloop
	endif
	ccall shutdown_engine
	if {test ax, ax}, nz
		; print some fail msg
	endif

	mov ax, 4C00h
	int 21h
endproc

;------------------------------------------------------------------------------
; program data segment
;------------------------------------------------------------------------------
segment data use16 CLASS=data

game_state: istruc GameState
	at GameState.pos, dw 10, 10
	at GameState.speed, dw 0, 0
	at GameState.accel, dw 0, GRAVITY_Y
	at GameState.mario, db MARIO_STATE_NONE
	at GameState.coin, db OBJ_VISIBLE
	at GameState.win, db 0
	at GameState.crtRand, dw 9, 9
	at GameState.beerPos, dw 10, 10
	at GameState.beerSpeed, dw 0, 6
	at GameState.beerActive, db OBJ_VISIBLE
	at GameState.isPepsi, db 0
	at GameState.lifes, db 3
iend

bg_bmp_filename: db "bg.bmp", 0
dead_bmp_filename: db "beer.bmp", 0
mario_spr_filename: db "mario.spr", 0
coin_spr_filename: db "coin.spr", 0
pepsi_filename: db "pepsi.bmp", 0
heart_filename: db "life.bmp", 0
beer_filename: db "beer.bmp", 0

;------------------------------------------------------------------------------
; background bmp data segment
;------------------------------------------------------------------------------
segment bg_seg private align=4 CLASS=data

bg_buffer: resb 64000
bg_bmp_info: resb BmpInfo_size

;dead_buffer: resb 64000
;dead_bmp_info: resb BmpInfo_size
;------------------------------------------------------------------------------
; sprite data segment
;------------------------------------------------------------------------------
segment sprite_seg private CLASS=data

mario_sprite: resb Sprite_size
align 4
mario_spr_bmp_store: resb 64*96
align 4
mario_spr_mask_store: resb 64*96

coin_sprite: resb Sprite_size
align 4
coin_spr_bmp_store: resb 128*16
align 4
coin_spr_mask_store: resb 128*16

;------------------------------------------------------------------------------
; other bmp data segment
;------------------------------------------------------------------------------
segment other_seg private CLASS=data

beer_bmp: resb BmpInfo_size
pepsi_bmp: resb BmpInfo_size
heart_bmp: resb BmpInfo_size
dead_bmp: resb BmpInfo_size

beer_mask: resb BmpInfo_size
pepsi_mask: resb BmpInfo_size
heart_mask: resb BmpInfo_size
dead_mask: resb BmpInfo_size

align 4
beer_bmp_store: resb 96*96
align 4
pepsi_bmp_store: resb 96*96
align 4
heart_bmp_store: resb 96*96
align 4
dead_bmp_store: resb 96*96

align 4
beer_mask_store: resb 96*96
align 4
pepsi_mask_store: resb 96*96
align 4
heart_mask_store: resb 96*96
align 4
dead_mask_store: resb 96*96


;------------------------------------------------------------------------------
; stack segment
;------------------------------------------------------------------------------
segment stack stack
    resw 1024
stacktop:

;rseed dd 41
