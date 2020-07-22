
ORG 0
BAL stack_init

ORG 0x4

INCLUDE image.s

image_end			DEFB		0x00


ALIGN 4

bus_addr 			DEFW 		0x30000000
stack 				DEFS 		0x50  					; 32 byte stack for now



stack_init
							ADR			SP, stack
							ADD			SP, SP, #0x50
							BAL			main

do_wait			 	STMFD		SP!, {LR, R0-R2}
							LDR			R0, bus_addr
wait_loop			LDRH		R1,	[R0, #30]
							ANDS		R2, R1, #2
							SUBS		R2, R2, #2
							BEQ			wait_loop
							LDMFD		SP!, {PC, R0-R2}


;							R1 = color
clear					STMFD		SP!, {LR, R0-R1}
							LDR			R0, bus_addr
							STRH		R1, [R0]
							MOV			R1, #3 						; 3 is clear
							STRH		R1, [R0, #16]
							BL			do_wait
							LDMFD		SP!, {PC, R0-R1}

; R1 = x, R2 = y, R3 = w, R4 = h, R5 = color
draw_rect 		STMFD 	SP!, {LR, R0-R4}
							LDR			R0, bus_addr
							STRH		R1, [R0]
							STRH		R2, [R0, #2]
							STRH 		R3, [R0, #4]
							STRH 		R4, [R0, #6]
							STRH		R5, [R0, #8]
							MOV			R1, #2 					; 2 is code for rect
							STRH		R1, [R0, #16]		; send command
							BL			do_wait
							LDMFD		SP!, {PC, R0-R4}

draw_img			STMFD		SP!, {LR, R0-R4}
							MOV			R0, #0
							BL			clear
							ADR			R6, image_end
							MOV			R7, #0x4			; image starts at 0x4
draw_loop			LDRH		R1,	[R7]
							LDRH		R2, [R7, #2]
							LDRH		R3, [R7, #4]
							LDRH		R4, [R7, #6]
							LDRH		R5, [R7, #8]
							BL			draw_rect
							ADD			R7, R7, #12
							CMP			R7, R6
							BLT			draw_loop
							LDMFD		SP!, {PC, R0-R4}

main
							MOV			R1, #0
							BL			clear
							BL 			draw_img
stop					B				stop
