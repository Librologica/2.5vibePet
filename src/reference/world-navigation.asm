; Reuses the qualified yaw acceleration and fixed-point atan steering from
; Mode 8 nav_heading/nav_steer. Waypoints now come from procedural door keys.
nav_goal_lo=$d5
nav_goal_hi=$d6
nav_diff=$da
nav_velocity=$dd
nav_fraction=$de
nav_slow=$df
nav_dx=$e0
nav_dy=$e2
nav_signs=$e4
nav_den=$e5
nav_rem=$e6
nav_ratio=$e7
nav_tmp=$e8
nav_negative=$e9
nav_hold=$ea
nav_move_phase=$ec

eg_nav_init:
 lda #0
 sta nav_velocity
 sta nav_fraction
 sta nav_slow
 sta nav_hold
 sta nav_move_phase
 sta eg_turn_hold
 sta eg_rooms
 sta eg_rooms+1
 lda #2
 sta eg_stage
 ldx #3
eg_nav_init_goal:
 lda cam_x,x
 sta eg_goal,x
 sta eg_far,x
 sta eg_centre,x
 dex
 bpl eg_nav_init_goal
 rts

eg_nav_input:
 jsr nav_difference
 lda nav_dx+1
 ora nav_dy+1
 bne eg_nav_heading
 lda nav_dx
 cmp #64
 bcs eg_nav_heading
 lda nav_dy
 cmp #64
 bcs eg_nav_heading
 lda eg_stage
 beq eg_next_far
 cmp #1
 beq eg_next_centre
 jsr eg_nav_plan
 jmp eg_nav_recompute
eg_next_far:
 ldx #3
eg_far_copy:
 lda eg_far,x
 sta eg_goal,x
 dex
 bpl eg_far_copy
 inc eg_stage
 jmp eg_nav_recompute
eg_next_centre:
 ldx #3
eg_centre_copy:
 lda eg_centre,x
 sta eg_goal,x
 dex
 bpl eg_centre_copy
 inc eg_stage
 inc eg_rooms
 bne eg_nav_recompute
 inc eg_rooms+1
eg_nav_recompute:
 jsr nav_difference
eg_nav_heading:
 jmp nav_heading

eg_nav_plan:
 lda cam_x+1
 sta eg_col
 lda cam_y+1
 sta eg_row
 jsr eg_coordinates
 lda cam_x+1
 sec
 sbc eg_phase_x
 sta eg_room_local_x
 lda cam_y+1
 sec
 sbc eg_phase_y
 sta eg_room_local_y
 lda eg_size_x
 sta eg_room_size_x
 lda eg_size_y
 sta eg_room_size_y
 lda eg_turn_hold
 beq eg_choose_exit
 dec eg_turn_hold
 jmp eg_exit_chosen
eg_choose_exit:
 lda #3
 jsr eg_hash
 lda eg_h0
 and #1
 sta eg_exit_axis
 lda eg_h1
 and #3
 clc
 adc #1
 sta eg_turn_hold
eg_exit_chosen:
 lda eg_exit_axis
 bne eg_look_north
 clc
 lda eg_room_local_x
 adc eg_room_size_x
 sta eg_col
 jmp eg_look_ready
eg_look_north:
 clc
 lda eg_room_local_y
 adc eg_room_size_y
 sta eg_row
eg_look_ready:
 ; Query the actual neighbour before choosing its shared door and centre.
 jsr eg_coordinates
 lda eg_exit_axis
 jsr eg_door_spec
 lda eg_gate
 sta eg_gate_centre
 lda #128
 sta eg_goal
 sta eg_goal+2
 sta eg_far
 sta eg_far+2
 sta eg_centre
 sta eg_centre+2
 lda eg_exit_axis
 bne eg_goal_north
 lda eg_room_local_x
 clc
 adc eg_room_size_x
 sta eg_boundary_pos
 clc
 adc #1
 sta eg_far+1
 lda eg_boundary_pos
 sec
 sbc #2
 sta eg_goal+1
 lda eg_size_x
 lsr
 clc
 adc eg_boundary_pos
 sta eg_centre+1
 lda eg_room_local_y
 clc
 adc eg_gate_centre
 sta eg_goal+3
 sta eg_far+3
 lda eg_size_y
 lsr
 clc
 adc eg_room_local_y
 sta eg_centre+3
 jmp eg_plan_done
eg_goal_north:
 lda eg_room_local_y
 clc
 adc eg_room_size_y
 sta eg_boundary_pos
 clc
 adc #1
 sta eg_far+3
 lda eg_boundary_pos
 sec
 sbc #2
 sta eg_goal+3
 lda eg_size_y
 lsr
 clc
 adc eg_boundary_pos
 sta eg_centre+3
 lda eg_room_local_x
 clc
 adc eg_gate_centre
 sta eg_goal+1
 sta eg_far+1
 lda eg_size_x
 lsr
 clc
 adc eg_room_local_x
 sta eg_centre+1
eg_plan_done:
 ; A wide full-height opening is centred at gate+1, not gate+0.5.
 lda eg_width
 cmp #2
 bne eg_plan_centre_ready
 lda eg_exit_axis
 eor #1
 asl
 tax
 inc eg_goal+1,x
 inc eg_far+1,x
 lda #0
 sta eg_goal,x
 sta eg_far,x
eg_plan_centre_ready:
 lda #0
 sta eg_stage
 rts

nav_difference:
 lda #0
 sta nav_signs
 sec
 lda eg_goal
 sbc cam_x
 sta nav_dx
 lda eg_goal+1
 sbc cam_x+1
 sta nav_dx+1
 bpl eg_dx_ready
 inc nav_signs
 sec
 lda #0
 sbc nav_dx
 sta nav_dx
 lda #0
 sbc nav_dx+1
 sta nav_dx+1
eg_dx_ready:
 sec
 lda eg_goal+2
 sbc cam_y
 sta nav_dy
 lda eg_goal+3
 sbc cam_y+1
 sta nav_dy+1
 bpl eg_difference_done
 inc nav_signs
 inc nav_signs
 sec
 lda #0
 sbc nav_dy
 sta nav_dy
 lda #0
 sbc nav_dy+1
 sta nav_dy+1
eg_difference_done:
 rts

eg_goal: .word 4224,4224
eg_far: .word 4224,4224
eg_centre: .word 4224,4224
eg_stage: .byte 2
eg_exit_axis: .byte 0
eg_turn_hold: .byte 0
eg_gate_centre: .byte 0
eg_room_local_x: .byte 0
eg_room_local_y: .byte 0
eg_room_size_x: .byte 0
eg_room_size_y: .byte 0
eg_boundary_pos: .byte 0
eg_rooms: .word 0

; Qualified steering routines follow.
nav_heading:
 lda nav_dx+1
 ora nav_dy+1
 beq nav_normalized
 lsr nav_dx+1
 ror nav_dx
 lsr nav_dy+1
 ror nav_dy
 jmp nav_heading
nav_normalized:
 lda nav_dx
 cmp nav_dy
 bcc nav_y_major
 beq nav_equal
 lda nav_signs
 ora #4
 sta nav_signs
 lda nav_dx
 sta nav_den
 lda nav_dy
 jmp nav_ratio_begin
nav_y_major:
 lda nav_dy
 sta nav_den
 lda nav_dx
nav_ratio_begin:
 sta nav_rem
 lda #0
 sta nav_ratio
 ldx #7
nav_ratio_bit:
 asl nav_rem
 bcs nav_ratio_subtract
 lda nav_rem
 cmp nav_den
 bcc nav_ratio_keep
nav_ratio_subtract:
 lda nav_rem
 sec
 sbc nav_den
 sta nav_rem
 sec
nav_ratio_keep:
 rol nav_ratio
 dex
 bne nav_ratio_bit
 ldx nav_ratio
 lda nav_atan,x
 jmp nav_octant
nav_equal:
 lda #64
nav_octant:
 sta nav_goal_lo
 lda nav_signs
 and #4
 beq nav_reflect_y
 lda #128
 sec
 sbc nav_goal_lo
 sta nav_goal_lo
nav_reflect_y:
 lda #0
 sta nav_goal_hi
 lda nav_signs
 and #2
 beq nav_reflect_x
 lda #0
 sec
 sbc nav_goal_lo
 sta nav_goal_lo
 lda #1
 sbc #0
 sta nav_goal_hi
nav_reflect_x:
 lda nav_signs
 and #1
 beq nav_steer
 lda #0
 sec
 sbc nav_goal_lo
 sta nav_goal_lo
 lda #0
 sbc nav_goal_hi
 and #1
 sta nav_goal_hi

nav_steer:
 lda #0
 sta nav_negative
 sec
 lda nav_goal_lo
 sbc cam_angle
 sta nav_diff
 lda nav_goal_hi
 sbc cam_angle+1
 and #1
 beq nav_positive_error
 dec nav_negative
 lda #0
 sec
 sbc nav_diff
 bne nav_abs_error
 lda #255 ; -256: saturate absolute magnitude for speed/turn clamps only
 bne nav_abs_error
nav_positive_error:
 lda nav_diff
nav_abs_error:
 ; Reload hold during a turn; count down only after yaw error is small.
 cmp #17
 bcc nav_hold_count
 ldx #150
 stx nav_hold
 jmp nav_hold_ready
nav_hold_count:
 ldx nav_hold
 beq nav_hold_ready
 dec nav_hold
nav_hold_ready:
 ; Earlier braking preserves safe radius with gentler angular motion.
 ; Hysteresis for translation speed: brake at 9/17, release at 6/12.
 ; Do not alternate speed at a quantized heading threshold.
 ldx nav_slow
 cpx #2
 bne nav_speed_normal
 cmp #13
 bcs nav_speed_chosen
 ldx #1
 cmp #7
 bcs nav_speed_chosen
 ldx #0
 beq nav_speed_chosen
nav_speed_normal:
 cmp #17
 bcc nav_speed_lower
 ldx #2
 bne nav_speed_chosen
nav_speed_lower:
 cpx #1
 bne nav_speed_fast
 cmp #7
 bcs nav_speed_chosen
 ldx #0
 beq nav_speed_chosen
nav_speed_fast:
 cmp #9
 bcc nav_speed_chosen
 ldx #1
nav_speed_chosen:
 stx nav_slow
 ; Ignore +/-2 integer yaw units of atan/coordinate rounding noise.
 ; Keep bounded angular acceleration; never snap the actual camera angle.
 sec
 sbc #2
 bcs nav_deadband_done
 lda #0
nav_deadband_done:
 cmp #9
 bcc nav_desired_magnitude
 lda #8
nav_desired_magnitude:
 ldx nav_negative
 beq nav_desired_signed
 eor #$ff
 clc
 adc #1
nav_desired_signed:
 eor #$80
 sta nav_tmp
 lda nav_velocity
 eor #$80
 cmp nav_tmp
 beq nav_integrate
 bcc nav_accelerate
 dec nav_velocity
 jmp nav_integrate
nav_accelerate:
 inc nav_velocity
nav_integrate:
 lda nav_velocity
 clc
 adc nav_fraction
 sta nav_tmp
 and #7
 sta nav_fraction
 lda nav_tmp
 cmp #$80
 ror
 cmp #$80
 ror
 cmp #$80
 ror
 ldx #0
 cmp #$80
 bcc nav_positive_turn
 dex
nav_positive_turn:
 clc
 adc cam_angle
 sta cam_angle
 txa
 adc cam_angle+1
 and #1
 sta cam_angle+1
 lda nav_move_phase
 clc
 adc #1
 and #3
 sta nav_move_phase
 ldx nav_slow
 cpx #2
 bne nav_move_forward
 cmp #0
 beq nav_move_forward
 lda #0
 sta keys
 rts
nav_move_forward:
 lda #1
 sta keys
 rts


nav_scale_speed:
 ldx nav_slow
 beq nav_scale_done
nav_scale_loop:
 lda move_x
 bpl nav_scale_x_positive
 clc
 adc #1 ; signed half, truncate toward zero
nav_scale_x_positive:
 cmp #$80
 ror
 sta move_x
 lda move_y
 bpl nav_scale_y_positive
 clc
 adc #1
nav_scale_y_positive:
 cmp #$80
 ror
 sta move_y
 dex
 bne nav_scale_loop
nav_scale_done:
 rts
