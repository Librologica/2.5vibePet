; Continuous 2D world, stock 6510. Main-thread SMC only; IRQ preserves A/X/Y
; and does not use $ed-$f0, generator state, or copy operands.
eg_ptr=$ed

eg_init:
.if WORLD_FIXED_SEED >= 0
 lda #<WORLD_FIXED_SEED
 sta eg_seed
 lda #((WORLD_FIXED_SEED >> 8) & 255)
 sta eg_seed+1
 lda #((WORLD_FIXED_SEED >> 16) & 255)
 sta eg_seed+2
 lda #((WORLD_FIXED_SEED >> 24) & 255)
 sta eg_seed+3
.else
 lda $dc04
 eor #$5b
 sta eg_seed
 lda $dc05
 eor $d012
 sta eg_seed+1
 lda $dd04
 eor #$a7
 sta eg_seed+2
 lda $dd05
 eor $dc04
 sta eg_seed+3
.endif
 jsr eg_cache_seed
 lda #$ff
 sta eg_last_domain
 ldx #7
eg_init_origin:
 sta eg_origin_x,x
 dex
 bpl eg_init_origin
 ; Spawn at the clear centre of room (0,0), independent of random dimensions.
 lda #0
 ldx #7
eg_initial_key:
 sta eg_key,x
 sta eg_global,x
 dex
 bpl eg_initial_key
 ldx #0
 jsr eg_axis_shape
 tya
 lsr
 sec
 sbc #WORLD_CENTRE
 sta eg_origin_x
 ldx #4
 jsr eg_axis_shape
 tya
 lsr
 sec
 sbc #WORLD_CENTRE
 sta eg_origin_y
 lda #0
 sta eg_generation_count
 sta eg_generation_count+1
 sta eg_music_ntsc_phase
 sta eg_row
eg_init_rows:
 jsr eg_fill_row
 inc eg_row
 lda eg_row
 cmp #WORLD_SIZE
 bne eg_init_rows
 rts

; Centre both local camera coordinates in cell WORLD_CENTRE. World coordinates do not
; change: each origin increment is paired with the inverse camera/goal shift.
eg_stream:
 lda #0
 sta eg_axis
 lda cam_x+1
 cmp #WORLD_CENTRE+1
 bcs eg_positive
 cmp #WORLD_CENTRE
 bcc eg_negative
 lda #1
 sta eg_axis
 lda cam_y+1
 cmp #WORLD_CENTRE+1
 bcs eg_positive
 cmp #WORLD_CENTRE
 bcc eg_negative
 rts
eg_positive:
 lda #1
 sta eg_direction
 jsr eg_shift
 jmp eg_stream
eg_negative:
 lda #$ff
 sta eg_direction
 jsr eg_shift
 jmp eg_stream

eg_shift:
 lda eg_axis
 asl
 tax
 lda eg_direction
 bmi eg_camera_up
 dec cam_x+1,x
 dec eg_goal+1,x
 dec eg_far+1,x
 dec eg_centre+1,x
 jmp eg_origin_select
eg_camera_up:
 inc cam_x+1,x
 inc eg_goal+1,x
 inc eg_far+1,x
 inc eg_centre+1,x
eg_origin_select:
 txa
 asl
 tax
 lda eg_direction
 bmi eg_origin_sub
 clc
 lda eg_origin_x,x
 adc #1
 sta eg_origin_x,x
 lda eg_origin_x+1,x
 adc #0
 sta eg_origin_x+1,x
 lda eg_origin_x+2,x
 adc #0
 sta eg_origin_x+2,x
 lda eg_origin_x+3,x
 adc #0
 sta eg_origin_x+3,x
 jmp eg_move_select
eg_origin_sub:
 sec
 lda eg_origin_x,x
 sbc #1
 sta eg_origin_x,x
 lda eg_origin_x+1,x
 sbc #0
 sta eg_origin_x+1,x
 lda eg_origin_x+2,x
 sbc #0
 sta eg_origin_x+2,x
 lda eg_origin_x+3,x
 sbc #0
 sta eg_origin_x+3,x
eg_move_select:
 lda #1
 ldx eg_axis
 beq eg_move_distance
 lda #WORLD_SIZE
eg_move_distance:
 sta eg_distance
 lda eg_direction
 bmi eg_move_back
 lda eg_distance
 sta eg_load_forward+1
 sta eg_load_forward_tail+1
 lda #>WORLD_MAP
 sta eg_load_forward+2
 sta eg_store_forward+2
 lda #>(WORLD_MAP+1536)
 sta eg_load_forward_tail+2
 lda #0
 sta eg_store_forward+1
 ldy #6
 ldx #0
eg_page_forward:
eg_load_forward:
 lda WORLD_MAP+40,x
eg_store_forward:
 sta WORLD_MAP,x
 inx
 bne eg_page_forward
 inc eg_load_forward+2
 inc eg_store_forward+2
 dey
 bne eg_page_forward
eg_load_forward_tail:
 lda WORLD_MAP+1536+40,x
 sta WORLD_MAP+1536,x
 inx
 cpx #64
 bne eg_load_forward_tail
 lda #WORLD_SIZE-2
 sta eg_inner
 jmp eg_regenerate
eg_move_back:
 lda #0
 sec
 sbc eg_distance
 sta eg_load_back+1
 sta eg_load_back_tail+1
 lda #>(WORLD_MAP+1280)
 sta eg_load_back_tail+2
 lda #>(WORLD_MAP+1024)
 sta eg_load_back+2
 lda #>(WORLD_MAP+1280)
 sta eg_store_back+2
 lda #0
 sta eg_store_back+1
 ldx #63
eg_load_back_tail:
 lda WORLD_MAP+1536-40,x
 sta WORLD_MAP+1536,x
 dex
 bpl eg_load_back_tail
 ldy #6
 ldx #$ff
eg_page_back:
eg_load_back:
 lda WORLD_MAP+1280-40,x
eg_store_back:
 sta WORLD_MAP+1280,x
 dex
 cpx #$ff
 bne eg_page_back
 dec eg_load_back+2
 dec eg_store_back+2
 dey
 bne eg_page_back
 lda #1
 sta eg_inner
eg_regenerate:
 lda eg_axis
 bne eg_rows
 lda #0
 sta eg_col
 jsr eg_fill_column
 lda eg_inner
 sta eg_col
 jsr eg_fill_column
 lda #WORLD_SIZE-1
 sta eg_col
 jsr eg_fill_column
 jmp eg_finish_shift
eg_rows:
 lda #0
 sta eg_row
 jsr eg_fill_row
 lda eg_inner
 sta eg_row
 jsr eg_fill_row
 lda #WORLD_SIZE-1
 sta eg_row
 jsr eg_fill_row
eg_finish_shift:
 inc eg_generation_count
 bne eg_shift_ready
 inc eg_generation_count+1
eg_shift_ready:
 rts

eg_fill_row:
 lda #0
 sta eg_col
eg_fill_row_next:
 jsr eg_write_cell
 inc eg_col
 lda eg_col
 cmp #WORLD_SIZE
 bne eg_fill_row_next
 rts
eg_fill_column:
 lda #0
 sta eg_row
eg_fill_column_next:
 jsr eg_write_cell
 inc eg_row
 lda eg_row
 cmp #WORLD_SIZE
 bne eg_fill_column_next
 rts
eg_write_cell:
 jsr eg_cell
 pha
 ldy eg_row
 lda world_row_lo,y
 clc
 adc eg_col
 sta eg_ptr
 lda world_row_hi,y
 adc #0
 sta eg_ptr+1
 ldy #0
 pla
 sta (eg_ptr),y
 rts

eg_cell:
 lda eg_col
 beq eg_solid
 cmp #WORLD_SIZE-1
 beq eg_solid
 lda eg_row
 beq eg_solid
 cmp #WORLD_SIZE-1
 beq eg_solid
 jsr eg_coordinates
 lda eg_phase_x
 beq eg_vertical
 lda eg_phase_y
 beq eg_horizontal
 jmp eg_room_interior
eg_vertical:
 lda eg_phase_y
 beq eg_solid
 sta eg_position
 lda #0
 jmp eg_boundary
eg_horizontal:
 lda eg_phase_x
 sta eg_position
 lda #1
eg_boundary:
 jsr eg_door_spec
 lda eg_position
 sec
 sbc eg_gate
 cmp eg_width
 bcc eg_opening
 jmp eg_solid
eg_opening:
 lda eg_material
 rts
eg_room_interior:
 ; Protected three-cell central cross: all four doors stay connected and
 ; the guided path never intersects procedural recesses.
 lda #0
 sta eg_quadrant
 lda eg_size_x
 lsr
 sec
 sbc #1
 sta eg_cross_min
 lda eg_phase_x
 sec
 sbc eg_cross_min
 bcc eg_left_corner
 cmp #3
 bcc eg_open
 inc eg_quadrant
eg_left_corner:
 lda eg_size_y
 lsr
 sec
 sbc #1
 sta eg_cross_min
 lda eg_phase_y
 sec
 sbc eg_cross_min
 bcc eg_top_corner
 cmp #3
 bcc eg_open
 inc eg_quadrant
 inc eg_quadrant
eg_top_corner:
 lda #2
 jsr eg_hash
 lda eg_h0
 and #15
 tay
 lda eg_corner_masks,y
 ldy eg_quadrant
 and eg_corner_bits,y
 bne eg_solid
 beq eg_open
eg_solid:
 lda #1
 rts
eg_open:
 lda #0
 rts

; Each independent world axis splits 16-cell blocks at 6,8,10 cells.
; Room keys remain 29-bit; local phases and sizes replace fixed 8-cell phases.
eg_coordinates:
 jsr eg_cache_seed
 clc
 lda eg_origin_x
 adc eg_col
 sta eg_global
 lda eg_origin_x+1
 adc #0
 sta eg_global+1
 lda eg_origin_x+2
 adc #0
 sta eg_global+2
 lda eg_origin_x+3
 adc #0
 sta eg_global+3
 clc
 lda eg_origin_y
 adc eg_row
 sta eg_global+4
 lda eg_origin_y+1
 adc #0
 sta eg_global+5
 lda eg_origin_y+2
 adc #0
 sta eg_global+6
 lda eg_origin_y+3
 adc #0
 sta eg_global+7
 ldx #0
 jsr eg_cached_axis
 sta eg_phase_x
 sty eg_size_x
 ldx #4
 jsr eg_cached_axis
 sta eg_phase_y
 sty eg_size_y
 rts

; Cache is not world storage: 4 tagged axis blocks per axis, disposable.
; Full seed comparison also makes diagnostic regeneration after seed changes safe.
eg_cache_seed:
 ldx #3
eg_seed_check:
 lda eg_seed,x
 cmp eg_grid_seed,x
 bne eg_seed_changed
 dex
 bpl eg_seed_check
 rts
eg_seed_changed:
 ldx #3
eg_seed_copy:
 lda eg_seed,x
 sta eg_grid_seed,x
 dex
 bpl eg_seed_copy
 lda #0
 ldx #63
eg_coord_clear:
 sta eg_coord_valid,x
 dex
 bpl eg_coord_clear
 ldx #7
eg_cache_clear:
 sta eg_grid_valid,x
 dex
 bpl eg_cache_clear
 rts

; Exact decoded-coordinate cache, 32 entries per axis. A streamed window has
; 32 consecutive coordinates: all but the new edge survive each cell shift.
; Tags include all 32 coordinate bits; seed changes invalidate both caches.
; Renderer and IRQ never access this cache.
eg_cached_axis:
 stx eg_coord_axis
 lda eg_global,x
 and #31
 asl
 sta eg_coord_slot
 txa
 lsr
 lsr
 ora eg_coord_slot
 sta eg_coord_slot
 tay
 lda eg_coord_valid,y
 beq eg_coord_miss
 lda eg_global,x
 cmp eg_coord_tag0,y
 bne eg_coord_miss
 lda eg_global+1,x
 cmp eg_coord_tag1,y
 bne eg_coord_miss
 lda eg_global+2,x
 cmp eg_coord_tag2,y
 bne eg_coord_miss
 lda eg_global+3,x
 cmp eg_coord_tag3,y
 bne eg_coord_miss
 lda eg_coord_key0,y
 sta eg_key,x
 lda eg_coord_key1,y
 sta eg_key+1,x
 lda eg_coord_key2,y
 sta eg_key+2,x
 lda eg_coord_key3,y
 sta eg_key+3,x
 lda eg_coord_size,y
 sta eg_shape_size
 lda eg_coord_phase,y
 ldy eg_shape_size
 rts
eg_coord_miss:
 lda eg_global,x
 sta eg_key,x
 lda eg_global+1,x
 sta eg_key+1,x
 lda eg_global+2,x
 sta eg_key+2,x
 lda eg_global+3,x
 sta eg_key+3,x
 ldy #4
eg_coord_shift:
 lsr eg_key+3,x
 ror eg_key+2,x
 ror eg_key+1,x
 ror eg_key,x
 dey
 bne eg_coord_shift
 jsr eg_axis_shape
 sta eg_shape_phase
 sty eg_shape_size
 ldx eg_coord_axis
 ldy eg_coord_slot
 lda eg_global,x
 sta eg_coord_tag0,y
 lda eg_global+1,x
 sta eg_coord_tag1,y
 lda eg_global+2,x
 sta eg_coord_tag2,y
 lda eg_global+3,x
 sta eg_coord_tag3,y
 lda eg_key,x
 sta eg_coord_key0,y
 lda eg_key+1,x
 sta eg_coord_key1,y
 lda eg_key+2,x
 sta eg_coord_key2,y
 lda eg_key+3,x
 sta eg_coord_key3,y
 lda eg_shape_phase
 sta eg_coord_phase,y
 lda eg_shape_size
 sta eg_coord_size,y
 lda #1
 sta eg_coord_valid,y
 lda eg_shape_phase
 ldy eg_shape_size
 rts

; X=0 (X axis) or 4 (Y axis). eg_key contains the selected 28-bit block.
; Returns A=local phase, Y=room period, updates selected key to 29-bit room ID.
eg_axis_shape:
 stx eg_shape_axis
 lda eg_key,x
 and #3
 ora eg_shape_axis
 sta eg_shape_slot
 tay
 lda eg_grid_valid,y
 beq eg_axis_hash
 lda eg_key,x
 cmp eg_grid_tag0,y
 bne eg_axis_hash
 lda eg_key+1,x
 cmp eg_grid_tag1,y
 bne eg_axis_hash
 lda eg_key+2,x
 cmp eg_grid_tag2,y
 bne eg_axis_hash
 lda eg_key+3,x
 cmp eg_grid_tag3,y
 bne eg_axis_hash
 lda eg_grid_split,y
 jmp eg_axis_found
eg_axis_hash:
 ; Identical byte contract to room_hash(block,0,4+axis,seed).
 txa
 lsr
 lsr
 clc
 adc #4
 eor eg_seed
 sta eg_h0
 lda eg_seed+1
 eor #$a7
 sta eg_h1
 ldy eg_shape_axis
 lda eg_key,y
 jsr eg_mix
 iny
 lda eg_key,y
 jsr eg_mix
 iny
 lda eg_key,y
 jsr eg_mix
 iny
 lda eg_key,y
 jsr eg_mix
 lda #0
 jsr eg_mix
 lda #0
 jsr eg_mix
 lda #0
 jsr eg_mix
 lda #0
 jsr eg_mix
 lda eg_seed+2
 jsr eg_mix
 lda eg_seed+3
 jsr eg_mix
 lda #$ff
 sta eg_last_domain ; h0/h1 no longer hold the general hash cache value
 ldx eg_shape_axis
 ldy eg_shape_slot
 lda eg_key,x
 sta eg_grid_tag0,y
 lda eg_key+1,x
 sta eg_grid_tag1,y
 lda eg_key+2,x
 sta eg_grid_tag2,y
 lda eg_key+3,x
 sta eg_grid_tag3,y
 lda #1
 sta eg_grid_valid,y
 lda eg_h0
 and #3
 tay
 lda eg_split_choices,y
 ldy eg_shape_slot
 sta eg_grid_split,y
eg_axis_found:
 sta eg_shape_size
 lda #0
 sta eg_shape_half
 ldx eg_shape_axis
 lda eg_global,x
 and #15
 cmp eg_shape_size
 bcc eg_axis_first
 sec
 sbc eg_shape_size
 sta eg_shape_phase
 lda #16
 sec
 sbc eg_shape_size
 sta eg_shape_size
 inc eg_shape_half
 jmp eg_axis_key
eg_axis_first:
 sta eg_shape_phase
eg_axis_key:
 asl eg_key,x
 rol eg_key+1,x
 rol eg_key+2,x
 rol eg_key+3,x
 lda eg_key,x
 ora eg_shape_half
 sta eg_key,x
 ldy eg_shape_size
 lda eg_shape_phase
 rts

; A=axis. Inner wall at phase6 shares doorway with the next phase0 wall.
eg_key_next_wall:
 asl
 asl
 tax
 clc
 lda eg_key,x
 adc #1
 sta eg_key,x
 lda eg_key+1,x
 adc #0
 sta eg_key+1,x
 lda eg_key+2,x
 adc #0
 sta eg_key+2,x
 lda eg_key+3,x
 adc #0
 and #$1f
 sta eg_key+3,x
 rts

; A=wall axis, eg_key=room to the positive side of the shared boundary.
; Does not mutate room keys. Other-axis dimensions are shared by both rooms.
eg_door_spec:
 sta eg_door_axis
 jsr eg_hash
 ldx eg_door_axis
 lda eg_size_y,x ; adjacent layout: size_y then size_x
 lsr
 sec
 sbc #1
 sta eg_gate
 lda eg_h0
 and #1
 clc
 adc eg_gate
 sta eg_gate
 lda eg_h1
 and #3
 beq eg_wide_opening
 lda #1
 sta eg_width
 lda #9
 sta eg_material
 rts
eg_wide_opening:
 lda #2
 sta eg_width
 lda #0
 sta eg_material
 rts

; Two permutation streams mix all 64 coordinate bits + 32 seed bits.
; Hash cache is only a speed aid, not persistent world storage.
eg_hash:
 sta eg_domain
 cmp eg_last_domain
 bne eg_hash_new
 ldx #7
eg_hash_compare:
 lda eg_key,x
 cmp eg_last_key,x
 bne eg_hash_new
 dex
 bpl eg_hash_compare
 rts
eg_hash_new:
 lda eg_domain
 sta eg_last_domain
 eor eg_seed
 sta eg_h0
 lda eg_seed+1
 eor #$a7
 sta eg_h1
 ldy #0
eg_hash_bytes:
 lda eg_key,y
 sta eg_last_key,y
 jsr eg_mix
 iny
 cpy #8
 bne eg_hash_bytes
 lda eg_seed+2
 jsr eg_mix
 lda eg_seed+3
 jmp eg_mix
eg_mix:
 sta eg_byte
 eor eg_h0
 tax
 lda eg_perm_a,x
 sta eg_h0
 clc
 adc eg_h1
 clc
 adc eg_byte
 tax
 lda eg_perm_b,x
 sta eg_h1
 rts

eg_collision_value:
 cmp #0
 beq eg_collision_open
 cmp #9
 beq eg_collision_open
 cmp #10
 beq eg_collision_open
 sec
 rts
eg_collision_open:
 clc
 rts

eg_origin_x: .dword 0
eg_origin_y: .dword 0
eg_seed: .dword 0
eg_global: .fill 8,0
eg_key: .fill 8,0
eg_last_key: .fill 8,0
eg_generation_count: .word 0
eg_music_ntsc_phase: .byte 0
eg_last_domain: .byte $ff
eg_domain: .byte 0
eg_h0: .byte 0
eg_h1: .byte 0
eg_byte: .byte 0
eg_row: .byte 0
eg_col: .byte 0
eg_phase_x: .byte 0
eg_phase_y: .byte 0
eg_position: .byte 0
eg_gate: .byte 0
eg_door_axis: .byte 0
eg_wall_parity: .byte 0
eg_inner_wall: .byte 0
eg_gap: .byte 0
eg_width: .byte 1
eg_material: .byte 9
eg_axis: .byte 0
eg_direction: .byte 0
eg_distance: .byte 0
eg_inner: .byte 0
eg_size_y: .byte 0
eg_size_x: .byte 0
eg_cross_min: .byte 0
eg_quadrant: .byte 0
eg_corner_bits: .byte 1,2,4,8
eg_corner_masks: .byte 0,0,0,0,1,2,4,8,3,12,5,10,6,9,15,0
eg_split_choices: .byte 6,8,10,8
eg_shape_axis: .byte 0
eg_shape_slot: .byte 0
eg_shape_size: .byte 0
eg_shape_half: .byte 0
eg_shape_phase: .byte 0
eg_grid_seed: .fill 4,0
eg_grid_valid: .fill 8,0
eg_grid_tag0: .fill 8,0
eg_grid_tag1: .fill 8,0
eg_grid_tag2: .fill 8,0
eg_grid_tag3: .fill 8,0
eg_grid_split: .fill 8,0
eg_coord_axis: .byte 0
eg_coord_slot: .byte 0
eg_coord_valid: .fill 64,0
eg_coord_tag0: .fill 64,0
eg_coord_tag1: .fill 64,0
eg_coord_tag2: .fill 64,0
eg_coord_tag3: .fill 64,0
eg_coord_key0: .fill 64,0
eg_coord_key1: .fill 64,0
eg_coord_key2: .fill 64,0
eg_coord_key3: .fill 64,0
eg_coord_phase: .fill 64,0
eg_coord_size: .fill 64,0
