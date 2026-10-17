; per stage: 3 route-mask bytes + 1 flag byte (bit0 = sub-level 0 walks left, bit1 = sub-level 1 walks left)
mask_tab:
    .byte 0,0,0,0   ; stage 0
    .byte 0,0,0,0   ; stage 1
    .byte 0,0,0,0   ; stage 2
    .byte 0,0,0,0   ; stage 3
    .byte 0,0,0,3   ; stage 4
    .byte 0,0,0,3   ; stage 5
    .byte 1,0,0,3   ; stage 6
    .byte 0,0,0,0   ; stage 7
    .byte 0,0,0,0   ; stage 8
    .byte 0,0,0,0   ; stage 9
    .byte 0,0,0,0   ; stage 10
    .byte 0,0,0,0   ; stage 11
    .byte 0,0,0,0   ; stage 12
    .byte 0,0,0,0   ; stage 13
    .byte 0,0,0,3   ; stage 14
    .byte 0,0,0,3   ; stage 15
    .byte 0,0,0,3   ; stage 16
    .byte 0,0,0,3   ; stage 17
