; *******************************************************************
; *** This software is copyright 2006 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include bios.inc
include kernel.inc

           org     8000h
           lbr     0ff00h
           db      'link2',0
           dw      0b000h
           dw      endrom+0b000h-2000h
           dw      2000h  
           dw      endrom-2000h  
           dw      2000h  
           db      0

           org     2000h
           br      start1              ; jump over version

include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

start1:    lbr     start
; **************************************
; *** Fetch 2 byte value from memory ***
; *** Address follows call           ***
; *** Returns: RF - Value            ***
; **************************************
fetch2:    lda     r6                  ; get high byte of requested address
           phi     rf
           lda     r6                  ; then low
           plo     rf
           lda     rf                  ; fetch high byte from address
           plo     re                  ; save for a moment
           ldn     rf                  ; get low byte
           plo     rf                  ; and set into rf
           glo     re                  ; recover high byte
           phi     rf
           sep     sret                ; return to caller

; ***********************************
; *** Setup RF to transfer buffer ***
; ***********************************
setbuf:    ldi     high buffer         ; setup buffer
           phi     rf
           ldi     low buffer
           plo     rf
           sep     sret                ; and return to caller

; **************************
; *** Setup input fildes ***
; **************************
setin:     ldi     high ifildes        ; point to input filedes
           phi     rd
           ldi     low ifildes
           plo     rd
           sep     sret                ; return to caller

; **************************
; *** Setup input fildes ***
; **************************
setout:    ldi     high ofildes        ; point to input filedes
           phi     rd
           ldi     low ofildes
           plo     rd
           sep     sret                ; return to caller

; *******************************
; *** Read block from file    ***
; *** RD - File Descriptor    ***
; *** Returns: D - Block type ***
; ***          DF=1 - EOF     ***
; *******************************
readblock: sep     scall               ; setup transfer buffer
           dw      setbuf
           ldi     0                   ; need to read 3 bytes
           phi     rc
           ldi     3
           plo     rc
           sep     scall               ; read them
           dw      o_read
           lbdf    readend             ; jump if read past end
           sep     scall               ; point back to beginning of buffer
           dw      setbuf
           lda     rf                  ; get block type
           xri     0ffh                ; check for last block code
           lbz     readend             ; jump if at end
           xri     0ffh                ; put it back
           stxd                        ; set aside for a moment
           lda     rf                  ; get block size
           phi     rc
           ldn     rf
           plo     rc
           dec     rc                  ; minus 3 bytes already read
           dec     rc
           dec     rc
           sep     scall               ; put rf at beginning of buffer
           dw      setbuf
           sep     scall               ; read the rest of the block
           dw      o_read
           irx                         ; recover block type
           ldx
           lbdf    readend             ; jump if read past end
           adi     0                   ; reset DF flag
           sep     sret                ; return to caller
readend:   smi     0                   ; signal end of file
           sep     sret                ; return to caller

; ************************
; *** Move past tables ***
; ************************
tableadd:  lda     rf                  ; get table size
           phi     r7
           lda     rf
           str     r2                  ; store for addition
           glo     rf
           add
           plo     rf
           ghi     r7                  ; now high byte
           str     r2
           ghi     rf
           adc
           phi     rf                  ; rf now points past table 
           sep     sret                ; return to caller

; ****************************
; *** Pass 1 on a file     ***
; *** RD - File Descriptor ***
; ****************************
pass1:     sep     scall               ; setup transfer buffer
           dw      readblock           ; read next block from file
           lbdf    pass1end            ; jump if hit end of file
           smi     1                   ; check for code block
           lbz     p1_code             ; jump if so
           lbr     pass1               ; and keep processing file
pass1end:  sep     scall               ; close the file
           dw      o_close
           sep     sret                ; and return to caller
p1_code:   sep     scall               ; move rf back to beginning of buffer
           dw      setbuf
           lda     rf                  ; retrieve load address
           phi     rc
           lda     rf                  ; rf now points at symbol table size
           plo     rc
           sep     scall               ; move past symbol table
           dw      tableadd
           sep     scall               ; move past externs table
           dw      tableadd
           sep     scall               ; move past relocatable table
           dw      tableadd
           lda     rf                  ; retrieve code block size
           phi     r7
           ldn     rf
           plo     r7
           glo     rc                  ; add in load address
           str     r2
           glo     r7
           add
           plo     r7
           ghi     rc
           str     r2
           ghi     r7
           adc
           phi     r7                  ; r7=highst address used by block


           ldi     high (lowest+1)     ; point to lowest address
           phi     rf
           ldi     low (lowest+1)
           plo     rf
           sex     rf                  ; set x lowest address variable
           glo     rc                  ; subtract from loaded address
           sm
           dec     rf                  ; move to high byte
           ghi     rc                  ; and subtract
           smb
           sex     r2                  ; point x back to stack
           lbdf    checkhi             ; if not lowest, then process next block
           ghi     rc                  ; write new highest address
           str     rf
           inc     rf
           glo     rc
           str     rf
checkhi:
           ldi     high (size+1)       ; point to highest address
           phi     rf
           ldi     low (size+1)
           plo     rf
           sex     rf                  ; set x lowest address variable
           glo     r7                  ; subtract from last address
           sd
           dec     rf                  ; move to high byte
           ghi     r7                  ; and subtract
           sdb
           sex     r2                  ; point x back to stack
           lbdf    pass1               ; if not highest, then process next block
           ghi     r7                  ; write new highest address
           str     rf
           inc     rf
           glo     r7
           str     rf
           lbr     pass1               ; then process next block

; ******************************
; *** Pass 2 on a file       ***
; *** RD - File Descriptor   ***
; *** RA - Output Descriptor ***
; ******************************
pass2:     sep     scall               ; setup transfer buffer
           dw      readblock           ; read next block from file
           lbdf    pass2end            ; jump if hit end of file
           smi     1                   ; check for code block
           lbz     p2_code             ; jump if so
           smi     2                   ; check for exec record
           lbz     p2_exec             ; jump if so
           lbr     pass1               ; and keep processing file
pass2end:  sep     scall               ; close the file
           dw      o_close
           sep     sret                ; and return to caller
p2_exec:   sep     scall               ; setup buffer
           dw      setbuf
           ldi     high startaddr      ; point to start address field
           phi     r8
           ldi     low startaddr
           plo     r8
           lda     rf                  ; transfer start address
           str     r8
           inc     r8
           ldn     rf
           str     r8
           lbr     pass2               ; back for next block
p2_code:   sep     scall               ; move rf back to beginning of buffer
           dw      setbuf
           lda     rf                  ; recover load address
           phi     r7
           lda     rf
           plo     r7
           ldi     high (lowest+1)     ; need to subtract base address
           phi     r8
           ldi     low (lowest+1)
           plo     r8
           sex     r8                  ; point x to lowest address
           glo     r7                  ; now subtract from block address
           sm
           plo     r7
           dec     r8
           ghi     r7
           smb
           phi     r7
           glo     r7                  ; add 6 for executable header
           adi     6
           plo     r7
           ghi     r7                  ; propagate carry
           adci    0
           phi     r7                  ; r7 now has offset into file
           ldi     0                   ; zero high bytes for seek
           phi     r8
           plo     r8
           sep     scall               ; point to output fildes
           dw      setout
           ldi     0                   ; want to seek from beginning
           plo     rc
           sep     scall               ; perform the seek
           dw      o_seek
           sep     scall               ; resetup buffer address
           dw      setbuf
; *** current version does not support the various tables ***
           inc     rf                  ; point to code block size
           inc     rf
           inc     rf
           inc     rf
           inc     rf
           inc     rf
           inc     rf
           inc     rf
           lda     rf                  ; retrieve size
           phi     rc
           lda     rf                  ; rf now pointing at data
           plo     rc                  ; rc now has size
           sep     scall               ; write the bytes to output file
           dw      o_write
           sep     scall               ; point to input fildes
           dw      setin
           lbr     pass2               ; loop back for next block



start:     ldi     high args           ; point to address for args
           phi     rf
           ldi     low args
           plo     rf
           ghi     ra                  ; save arguments address
           str     rf
           inc     rf
           glo     ra
           str     rf
           ghi     ra                  ; transfer arg address to rf
           phi     rf
           glo     ra
           plo     rf
           sep     scall               ; point to input descriptor
           dw      setin
           ldi     0                   ; no open flags
           plo     r7
           sep     scall               ; open the file
           dw      o_open
           lbnf    opened1             ; jump if file was opened
error:     ldi     high errmsg         ; display error message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall
           dw      o_msg
           sep     sret                ; and return to caller
opened1:   sep     scall               ; perform pass 1
           dw      pass1
           ldi     high outname        ; point to output name
           phi     rf
           ldi     low outname
           plo     rf
           sep     scall               ; point to output fildes
           dw      setout
           ldi     11                  ; select exec, create and truncate options
           plo     r7
           sep     scall               ; and open the output file
           dw      o_open
           ldi     high args           ; recover address of input name
           phi     r8
           ldi     low args
           plo     r8
           lda     r8                  ; and retrieve it
           phi     rf
           ldn     r8
           plo     rf
           sep     scall               ; point to input fildes
           dw      setin
           ldi     0                   ; no open flags
           plo     r7
           sep     scall               ; open the file
           dw      o_open
           sep     scall               ; call pass 2
           dw      pass2
           sep     scall               ; point to output fildes
           dw      setout
           ldi     0                   ; need to seek back to beginning
           phi     r7
           plo     r7
           phi     r8
           plo     r8
           ldi     0                   ; seek from beginning
           plo     rc
           sep     scall               ; perform the seek
           dw      o_seek
           ldi     high size           ; poin to size field
           phi     rf
           ldi     low size
           plo     rf
           lda     rf                  ; retrieve it
           phi     r7
           ldn     rf
           plo     r7
           ldi     high (lowest+1)     ; poin to exec header
           phi     rf
           ldi     low (lowest+1)
           plo     rf
           sex     rf                  ; subtract from size
           glo     r7
           sm
           plo     r7
           dec     rf
           ghi     r7
           smb
           phi     r7                  ; r7 now has load size
           sex     r2                  ; point x back to stack
           ldi     high size           ; poin to size field
           phi     rf
           ldi     low size
           plo     rf
           ghi     r7                  ; write size back
           str     rf
           inc     rf
           glo     r7
           str     rf

           ldi     high lowest         ; poin to exec header
           phi     rf
           ldi     low lowest
           plo     rf
           ldi     0                   ; 6 bytes to write
           phi     rc
           ldi     6
           plo     rc
           sep     scall               ; write the header
           dw      o_write
           sep     scall               ; close output file
           dw      o_close
           sep     sret                ; and return to os

errmsg:    db      'File not found',10,13,0
outname:   db      'a.out',0

lowest:    dw      0ffffh
size:      dw      0
startaddr: dw      0

args:      dw      0
ifildes:   db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

ofildes:   db      0,0,0,0
           dw      odta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0


endrom:    equ     $

dta:       ds      512
odta:      ds      512

buffer:    ds      512

