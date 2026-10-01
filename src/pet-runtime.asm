; PET-specific original runtime. PolyForm Noncommercial 1.0.0.
; VIA T1 IRQ saves A/X/Y through PET editor ROM; no renderer ZP touched.
; Main-thread world SMC and DDA scratch never shared with IRQ.
screen_ptr=$70
door_ptr=$72
line_ptr=$74
index_ptr=$76

entry:
 sei
 cld
 lda #$7f
 sta $e84e
 lda $e811
 and #$f6
 sta $e811
 lda $e813
 and #$f6
 sta $e813
 lda $e821
 and #$f6
 sta $e821
 lda $e823
 and #$f6
 sta $e823
 lda #$0e ; CA2 high: graphics character bank.
 sta $e84c
 lda #$1e
 sta $e842
 lda #$40 ; T1 continuous, shift register disabled: no audio.
 sta $e84b
 lda #0
 sta $e84a
 sta ticks_pending
 sta frame_count
 sta frame_count+1
 sta tick_count
 sta tick_count+1
 sta second_ticks
 sta fps_current
 sta fps_window
 jsr init_camera
 jsr init_simulation
 jsr eg_init
 jsr eg_nav_init
 jsr init_screen
 lda #<irq
 sta $0090
 lda #>irq
 sta $0091
 lda #$1e ; 19998+2 cycles = 20,000 at 1 MHz
 sta $e844
 lda #$4e
 sta $e845
 lda #$c0
 sta $e84e
 cli
main_loop:
 jsr consume_ticks
 jsr latch_pose
render_frame_begin:
 jsr raycast_all
geometry_done:
 jsr compose
render_frame_end:
 jsr show_screen
 inc frame_count
 bne frame_count_ready
 inc frame_count+1
frame_count_ready:
 inc fps_window
presentation_done:
 jmp main_loop

consume_ticks:
 sei
 lda ticks_pending
 beq consume_done
 dec ticks_pending
 cli
 jsr simulation_tick
 jsr eg_stream
 jmp consume_ticks
consume_done:
 cli
 rts

irq:
 lda $e84d
 and #$40
 beq irq_exit
 lda $e844
 inc ticks_pending
 inc tick_count
 bne irq_tick_high_done
 inc tick_count+1
irq_tick_high_done:
 inc second_ticks
 lda second_ticks
 cmp #50
 bcc irq_no_second
 lda #0
 sta second_ticks
 lda fps_window
 sta fps_current
 lda #0
 sta fps_window
irq_no_second:
irq_exit:
 pla
 tay
 pla
 tax
 pla
 rti

init_screen:
 lda #32
 ldx #0
init_screen_loop:
 sta $8000,x
 sta $8100,x
 sta $8200,x
 sta $8300,x
 inx
 bne init_screen_loop
 ldx #39
init_title:
 lda title,x
 sta back_screen,x
 lda controls,x
 sta back_screen+40,x
 dex
 bpl init_title
 rts

; Screen RAM has no second hardware page. Copy only a completed back image.
show_screen:
 lda fps_current
 ldx #0
fps_tens:
 cmp #10
 bcc fps_digits
 sec
 sbc #10
 inx
 bne fps_tens
fps_digits:
 clc
 adc #48
 sta back_screen+39
 txa
 clc
 adc #48
 sta back_screen+38
show_wait_active:
 lda $e840
 and #$20
 beq show_wait_active
show_wait_blank:
 lda $e840
 and #$20
 bne show_wait_blank
 ldx #0
show_copy:
 lda back_screen,x
 sta $8000,x
 lda back_screen+256,x
 sta $8100,x
 lda back_screen+512,x
 sta $8200,x
 inx
 bne show_copy
 ldx #0
show_tail:
 lda back_screen+768,x
 sta $8300,x
 inx
 cpx #232
 bne show_tail
 rts

; Correct perpendicular Q8.8 depth for the centred ray.
pet_depth:
 lda hit_t
 sta mul_a
 lda hit_t+1
 sta mul_a+1
 ldx ray_index
 lda ray_cos_axis,x
 beq pet_depth_product
 lda hit_t
 sta mul_r
 lda hit_t+1
 sta mul_r+1
 rts
pet_depth_product:
 lda ray_cos,x
 sta mul_b
 jsr mul16x8_shift8
 rts

; Projection lookup in Q5.4. T=$ffff saturates, not wraps.
height_index:
 lda mul_r+1
 cmp #32
 bcc height_in_range
 lda #$ff
 sta index_ptr
 lda #1
 sta index_ptr+1
 rts
height_in_range:
 lda mul_r
 sta index_ptr
 lda mul_r+1
 sta index_ptr+1
 ldx #4
height_shift:
 lsr index_ptr+1
 ror index_ptr
 dex
 bne height_shift
 rts

; A=cell. Continue through doors, storing eight upper-volume intervals per ray.
; Front top + far lower edge also represents the underside of a thick lintel.
pet_cell:
 sta cell_material
 lda door_active
 beq pet_no_door_exit
 jsr pet_depth
 jsr height_index
 jsr door_lookup_bottom
 ldy #0
 sta (door_ptr),y
 lda #0
 sta door_active
pet_no_door_exit:
 lda cell_material
 cmp #9
 bne pet_not_door
 lda door_count
 cmp #8
 bcs pet_door_overflow
 jsr pet_depth
 jsr height_index
 lda index_ptr+1
 clc
 adc #>height_top
 sta line_ptr+1
 lda index_ptr
 sta line_ptr
 ldy #0
 lda (line_ptr),y
 pha
 jsr door_address
 pla
 sta (door_ptr),y
 ; Shade belongs to the actual doorway face, not the wall behind it.
 clc
 lda door_ptr
 adc #<(door_shade-door_top)
 sta line_ptr
 lda door_ptr+1
 adc #>(door_shade-door_top)
 sta line_ptr+1
 lda #1
 ldx hit_side
 beq door_bright
 lda #3
door_bright:
 sta (line_ptr),y
 clc
 lda door_ptr
 adc #<320
 sta door_ptr
 lda door_ptr+1
 adc #>320
 sta door_ptr+1
 jsr door_lookup_bottom
 ldy #0
 sta (door_ptr),y
 inc door_count
 lda #1
 sta door_active
 ldx ray_index
 lda door_count
 sta ray_doors,x
 lda #0
 clc
 rts
pet_door_overflow:
 lda #1 ; Defined safe fallback if >8 lintels: close at that wall.
 sec
 rts
pet_not_door:
 cmp #0
 beq pet_free_cell
 sec
 rts
pet_free_cell:
 clc
 rts
door_lookup_bottom:
 lda index_ptr
 sta line_ptr
 lda index_ptr+1
 clc
 adc #>height_door
 sta line_ptr+1
 ldy #0
 lda (line_ptr),y
 rts
door_address:
 lda ray_index
 sta door_ptr
 lda #0
 sta door_ptr+1
 asl door_ptr
 rol door_ptr+1
 asl door_ptr
 rol door_ptr+1
 asl door_ptr
 rol door_ptr+1
 clc
 lda door_ptr
 adc door_count
 clc
 adc #<door_top
 sta door_ptr
 lda door_ptr+1
 adc #>door_top
 sta door_ptr+1
 rts

compose:
 lda #0
 sta column
compose_column:
 ldx column
 lda depth_lo,x
 sta mul_r
 lda depth_hi,x
 sta mul_r+1
 jsr height_index
 ldx column
 lda #>sample_profile_lo
 ldy ray_side,x
 beq compose_profile_selected
 lda #>dark_profile_lo
compose_profile_selected:
 clc
 adc index_ptr+1
 sta line_ptr+1
 lda index_ptr
 sta line_ptr
 ldy #0
 lda (line_ptr),y
 pha
 inc line_ptr+1
 inc line_ptr+1
 lda (line_ptr),y
 sta line_ptr+1
 pla
 sta line_ptr
__COPY_COLUMN__
 lda column
 sta ray_index
 lda #0
 sta door_count
 jsr door_address
 ldx column
 lda ray_doors,x
 sta compose_doors
 beq compose_pairs
compose_door_loop:
 ldy #0
 lda (door_ptr),y
 sta span_top
 clc
 lda door_ptr
 adc #<320
 sta line_ptr
 lda door_ptr+1
 adc #>320
 sta line_ptr+1
 lda (line_ptr),y
 sta span_bottom
 clc
 lda door_ptr
 adc #<(door_shade-door_top)
 sta line_ptr
 lda door_ptr+1
 adc #>(door_shade-door_top)
 sta line_ptr+1
 lda (line_ptr),y
 sta wall_shade
 jsr fill_span
 inc door_ptr
 bne compose_door_advance
 inc door_ptr+1
compose_door_advance:
 dec compose_doors
 bne compose_door_loop
compose_pairs:
__STORE_COLUMN__
 inc column
 lda column
 cmp #40
 bne compose_column
 rts
fill_span:
 ldx span_top
 lda wall_shade
fill_span_next:
 cpx span_bottom
 bcs fill_span_done
 sta column_samples,x
 inx
 bne fill_span_next
fill_span_done:
 rts

ticks_pending: .byte 0
tick_count: .word 0
frame_count: .word 0
second_ticks: .byte 0
fps_current: .byte 0
fps_window: .byte 0
door_count: .byte 0
door_active: .byte 0
cell_material: .byte 0
column: .byte 0
row: .byte 0
logical_y: .byte 0
span_top: .byte 0
span_bottom: .byte 0
sample_code: .byte 0
compose_doors: .byte 0
wall_shade: .byte 1
column_samples: .fill 44,0
.enc "screen"
title: .text "2.5VIBEPET INFINITE              FPS  00"
.if AUTO_RUN
controls: .text "AUTO EXPLORE / CLEAR WALLS + DOT FLOOR   "
.else
controls: .text "W/S MOVE A/D TURN / CLEAR WALLS          "
.endif
