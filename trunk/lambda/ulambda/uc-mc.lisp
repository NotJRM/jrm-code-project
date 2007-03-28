;-*- mode: lisp; base: 8; readtable: ZL -*-

(DEFCONST UC-MC '(
(LOCALITY D-MEM)
;Microcompiled code support
  ;These are in dispatch mem just so can take arg in dispatch constant.
  ;Said arg is the offset into exit-vector-area.

(START-DISPATCH 0 0)
;Read Q from exit vector, leave it in MD.  Does transporting, forwarding, etc.
D-READ-EXIT-VECTOR (P-BIT INHIBIT-XCT-NEXT-BIT MC-READ-EXIT-VECTOR)
(END-DISPATCH)

(START-DISPATCH 0 0)
;Read Q from exit vector, leave it in MD and T.  Does transporting, forwarding, etc.
D-READ-EXIT-VECTOR-AND-LOAD-T (P-BIT INHIBIT-XCT-NEXT-BIT MC-READ-EXIT-VECTOR-AND-LOAD-T)
(END-DISPATCH)

(START-DISPATCH 0 0)
;Write Q from MD thru exit vector.  Does transporting, forwarding, etc.
D-WRITE-EXIT-VECTOR (P-BIT INHIBIT-XCT-NEXT-BIT MC-WRITE-EXIT-VECTOR)
(END-DISPATCH)

(START-DISPATCH 0 0)
;Open micro-macro call block to function from exit vector.
D-CALL-EXIT-VECTOR (P-BIT INHIBIT-XCT-NEXT-BIT MC-CALL-EXIT-VECTOR)
(END-DISPATCH)

;Following for support routines that take arg via DISPATCH-CONSTANT.
(START-DISPATCH 0 0)
D-SE1+  (P-BIT INHIBIT-XCT-NEXT-BIT MC-SE1+)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-SE1-  (P-BIT INHIBIT-XCT-NEXT-BIT MC-SE1-)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-SECDR (P-BIT INHIBIT-XCT-NEXT-BIT MC-SECDR)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-SECDDR (P-BIT INHIBIT-XCT-NEXT-BIT MC-SECDDR)
(END-DISPATCH)

;Links to routines which activate MICRO-MACRO calls
(START-DISPATCH 0 0)
D-MMCALL (P-BIT INHIBIT-XCT-NEXT-BIT MMCALL)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-MMCALT (P-BIT INHIBIT-XCT-NEXT-BIT MC-MMCALT)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-MMCALB (P-BIT INHIBIT-XCT-NEXT-BIT MC-MMCALB)
(END-DISPATCH)

;These bind special vars
(START-DISPATCH 0 0)
D-BNDPOP (P-BIT INHIBIT-XCT-NEXT-BIT MC-BNDPOP)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-BNDNIL (P-BIT INHIBIT-XCT-NEXT-BIT MC-BNDNIL)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-DO-SPECBIND-PP-BASED (P-BIT INHIBIT-XCT-NEXT-BIT MC-DO-SPECBIND-PP-BASED)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-POP-SPECPDL (P-BIT INHIBIT-XCT-NEXT-BIT MC-POP-SPECPDL)
(END-DISPATCH)

(START-DISPATCH 0 0)
D-SETZERO (P-BIT INHIBIT-XCT-NEXT-BIT MC-SETZERO)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-SETNIL (P-BIT INHIBIT-XCT-NEXT-BIT MC-SETNIL)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-GET-LOCATIVE-TO-PDL (P-BIT INHIBIT-XCT-NEXT-BIT MC-GET-LOCATIVE-TO-PDL)
(END-DISPATCH)
(START-DISPATCH 0 0)
D-GET-LOCATIVE-TO-VC (P-BIT INHIBIT-XCT-NEXT-BIT MC-GET-LOCATIVE-TO-VC)
(END-DISPATCH)

;Hairy multiple value stuff.  not really for now, in some cases.
(START-DISPATCH 0 0)            ;open call block with multiple values.
D-XCMV  (P-BIT INHIBIT-XCT-NEXT-BIT MC-XCMV)
(END-DISPATCH)
(START-DISPATCH 0 0)                        ;*CATCH open, multiple values
D-UCTOM  (P-BIT INHIBIT-XCT-NEXT-BIT MC-UCTOM)
(END-DISPATCH)
(START-DISPATCH 0 0)                        ;Prepare to make
D-MMISU  (P-BIT INHIBIT-XCT-NEXT-BIT MC-MMISU)  ; MICRO-MICRO call receiving N values
(END-DISPATCH)
(START-DISPATCH 0 0)
D-MURV   (P-BIT INHIBIT-XCT-NEXT-BIT MC-MURV)   ;RETURN-NEXT-VALUE
(END-DISPATCH)
(START-DISPATCH 0 0)
D-MRNV   (INHIBIT-XCT-NEXT-BIT MC-MRNV)     ;Return N values, number in M-C. Note jump.
(END-DISPATCH)
(START-DISPATCH 0 0)
D-MR2V   (INHIBIT-XCT-NEXT-BIT MC-MR2V)     ;Return 2 values.  Note jump.
(END-DISPATCH)
(START-DISPATCH 0 0)
D-MR3V   (INHIBIT-XCT-NEXT-BIT MC-MR3V)     ;Return 3 values.  Note jump.
(END-DISPATCH)

;Used to effect returns!
(START-DISPATCH 0 0)
D-SUB-PP (INHIBIT-XCT-NEXT-BIT MC-SUB-PP)           ;Note jump.
(END-DISPATCH)
(START-DISPATCH 0 0)
D-POP-SPECPDL-AND-SUB-PP (INHIBIT-XCT-NEXT-BIT MC-POP-SPECPDL-AND-SUB-PP) ;Note jump.
(END-DISPATCH)

(LOCALITY I-MEM)

;microcompiled code runtime support
MC-READ-EXIT-VECTOR             ;Read data from exit vector, leave it in MD
        ((VMA-START-READ) ADD READ-I-ARG A-MC-CODE-EXIT-VECTOR)
        (CHECK-PAGE-READ)
        (POPJ-AFTER-NEXT DISPATCH TRANSPORT READ-MEMORY-DATA)  ;Follow all INVZ
       (NO-OP)

MC-READ-EXIT-VECTOR-AND-LOAD-T          ;Read data from exit vector, leave it in MD, also in T.
        ((VMA-START-READ) ADD READ-I-ARG A-MC-CODE-EXIT-VECTOR)
        (CHECK-PAGE-READ)
        (POPJ-AFTER-NEXT DISPATCH TRANSPORT READ-MEMORY-DATA)  ;Follow all INVZ
       ((M-T) Q-TYPED-POINTER MD)

MC-SETZERO (JUMP-XCT-NEXT MC-WRITE-EXIT-VECTOR)
          ((MD) (A-CONSTANT (BYTE-VALUE Q-DATA-TYPE DTP-FIX)))

MC-SETNIL ((MD) A-V-NIL)
MC-WRITE-EXIT-VECTOR            ;Write Q in MD thru exit vector.  Exit vector itself
        ((M-A) MD)              ;  had better have some kind of forwarding pointer.
        ((VMA-START-READ) ADD READ-I-ARG A-MC-CODE-EXIT-VECTOR)
        (CHECK-PAGE-READ)
        (DISPATCH TRANSPORT-WRITE READ-MEMORY-DATA)     ;Follow all INVZ
        ((MD-START-WRITE) SELECTIVE-DEPOSIT MD Q-ALL-BUT-TYPED-POINTER A-A)
        (CHECK-PAGE-WRITE)
        (GC-WRITE-TEST)
        (popj)

MC-CALL-EXIT-VECTOR
        (CALL MC-READ-EXIT-VECTOR)
        (CALL-XCT-NEXT P3ZERO)
       ((M-T) Q-TYPED-POINTER MD)
        (POPJ-AFTER-NEXT (C-PDL-BUFFER-POINTER-PUSH) M-T)
       (NO-OP)

MC-BNDNIL
        ((C-PDL-BUFFER-POINTER-PUSH) A-V-NIL)
MC-BNDPOP
        ((VMA-START-READ) ADD READ-I-ARG A-MC-CODE-EXIT-VECTOR)  ;Exit vector points to
        (CHECK-PAGE-READ)                       ; internal value cell.
        ((M-LAST-MICRO-ENTRY) MICRO-STACK-DATA-POP)   ;Save return
      ;Return of microcompiled FCTN now in MICRO-STACK-DATA. Depends on M-QBBFL = bit 0
#+LAMBDA((M-FLAGS) LDB %%-PPBSPC
                         MICRO-STACK-PNTR-AND-DATA A-FLAGS) ;Start or continue binding block
#+EXP   ((M-FLAGS) LDB %%-PPBSPC
                         MICRO-STACK-DATA A-FLAGS)
        ((PDL-INDEX) ADD M-AP (A-CONSTANT (EVAL %LP-CALL-STATE)))       ;set attention in
        ((C-PDL-BUFFER-INDEX) IOR C-PDL-BUFFER-INDEX            ;running frame
                           (A-CONSTANT (BYTE-VALUE %%LP-CLS-ATTENTION 1)))
        (CALL MC-BND1)
MC-DOSX ((M-2) MICRO-STACK-DATA-POP)               ;Save M-QBBFL in his return
        ((MICRO-STACK-DATA-PUSH) DPB M-FLAGS %%-PPBSPC A-2)  ;Depends on M-QBBFL = bit 0
        ((OA-REG-LOW) DPB M-LAST-MICRO-ENTRY OAL-JUMP A-ZERO)
        (JUMP 0)        ;RETURN


MC-BND1 (call-xct-next qibnd)
       ((VMA-START-READ) MD)
        ((vma) m-b)
        ((M-T) C-PDL-BUFFER-POINTER-POP)
        ((M-T WRITE-MEMORY-DATA-START-WRITE) SELECTIVE-DEPOSIT M-E
                Q-ALL-BUT-TYPED-POINTER A-T)
        (CHECK-PAGE-WRITE)
        (GC-WRITE-TEST)
        (popj)

;BIND A BLOCK OF SPECIAL VARIABLES.  INTERNAL VALUE CELL POINTERS ARE IN A BLOCK IN EXIT
;VECTOR STARTING AT ADDRESS GIVEN BY DISPATCH CONSTANT.  VALUES ARE IN PDL BUFFER LOCATIONS
;FLAGGED BY ONE BITS IN M-C INTERPRETED AS A BIT VECTOR (I.E. BIT 0, IF ON, SAYS BIND
;0(PP), ETC).
MC-DO-SPECBIND-PP-BASED
        ((M-LAST-MICRO-ENTRY) MICRO-STACK-DATA-POP)   ;Save return
      ;Return of microcompiled FCTN now in MICRO-STACK-DATA. Depends on M-QBBFL = bit 0
#+LAMBDA((M-FLAGS) LDB %%-PPBSPC
                        MICRO-STACK-PNTR-AND-DATA A-FLAGS) ;Start or continue binding block
#+EXP   ((M-FLAGS) LDB %%-PPBSPC
                        MICRO-STACK-DATA A-FLAGS) ;Start or continue binding block
        ((PDL-BUFFER-INDEX M-S) PDL-BUFFER-POINTER)
        ((M-D) ADD READ-I-ARG A-MC-CODE-EXIT-VECTOR)
MC-DOS1 (JUMP-EQUAL M-C A-ZERO MC-DOSX)
        (JUMP-IF-BIT-CLEAR (BYTE-FIELD 1 0) M-C MC-DOS2)
        ((VMA-START-READ) M-D)
        (CHECK-PAGE-READ)
        (CALL-XCT-NEXT MC-BND1)
       ((C-PDL-BUFFER-POINTER-PUSH) C-PDL-BUFFER-INDEX)
        ((M-D) ADD M-D (A-CONSTANT 1))
MC-DOS2 ((M-C) LDB (BYTE-FIELD 31. 1) M-C)
        (JUMP-XCT-NEXT MC-DOS1)
       ((PDL-BUFFER-INDEX M-S) SUB M-S (A-CONSTANT 1))

MC-POP-SPECPDL
        ((M-D) READ-I-ARG)      ;# to pop
        ((M-LAST-MICRO-ENTRY) MICRO-STACK-DATA-POP)   ;Save return
      ;Return of microcompiled FCTN now in MICRO-STACK-DATA. Depends on M-QBBFL = bit 0
#+LAMBDA((M-FLAGS) LDB %%-PPBSPC
                        MICRO-STACK-PNTR-AND-DATA A-FLAGS) ;Start or continue binding block
#+EXP   ((M-FLAGS) LDB %%-PPBSPC
                        MICRO-STACK-DATA A-FLAGS)
MC-POPS1(JUMP-EQUAL M-D A-ZERO MC-DOSX)
        (CALL-IF-BIT-CLEAR M-QBBFL ILLOP)
        (CALL QUNBND)
        (JUMP-XCT-NEXT MC-POPS1)
       ((M-D) SUB M-D (A-CONSTANT 1))

;Special entries used by micro compiled code.  Most take arg via the DISPATCH-CONSTANT.
MC-SE1+ ((M-LAST-MICRO-ENTRY) (A-CONSTANT (I-MEM-LOC X1PLS)))
MC-SOP  (CALL MC-READ-EXIT-VECTOR)
        ((C-PDL-BUFFER-POINTER-PUSH) VMA)
        ((OA-REG-LOW M-LAST-MICRO-ENTRY) DPB M-LAST-MICRO-ENTRY OAL-JUMP A-ZERO)
        (CALL-XCT-NEXT 0)
       ((C-PDL-BUFFER-POINTER-PUSH) MD)
        ((VMA-START-READ) C-PDL-BUFFER-POINTER-POP)
        (CHECK-PAGE-READ)
        (DISPATCH TRANSPORT-WRITE READ-MEMORY-DATA)     ;Follow all INVZ
        ((MD-START-WRITE) SELECTIVE-DEPOSIT MD Q-ALL-BUT-TYPED-POINTER A-T)
        (CHECK-PAGE-WRITE)
        (GC-WRITE-TEST)
        (popj)

MC-SE1- (JUMP-XCT-NEXT MC-SOP)
       ((M-LAST-MICRO-ENTRY) (A-CONSTANT (I-MEM-LOC X1MNS)))

MC-SECDR(JUMP-XCT-NEXT MC-SOP)
       ((M-LAST-MICRO-ENTRY) (A-CONSTANT (I-MEM-LOC XCDR)))

MC-SECDDR
        (JUMP-XCT-NEXT MC-SOP)
       ((M-LAST-MICRO-ENTRY) (A-CONSTANT (I-MEM-LOC XCDDR)))

MC-MMCALB       ;This is supposed to box M-T as well as push it.
MC-MMCALT
        (JUMP-XCT-NEXT MMCALL)
       ((C-PDL-BUFFER-POINTER-PUSH) DPB M-T Q-TYPED-POINTER     ;last arg, CDR-NIL
                        (A-CONSTANT (BYTE-VALUE Q-CDR-CODE CDR-NIL)))

MC-GET-LOCATIVE-TO-PDL
        ((M-TEM) READ-I-ARG)
        (CALL-XCT-NEXT CONVERT-PDL-BUFFER-ADDRESS)
       ((M-K) SUB PDL-BUFFER-POINTER A-TEM)
        (POPJ-AFTER-NEXT (M-T) M-K)
       (NO-OP)

MC-GET-LOCATIVE-TO-VC
        ((VMA-START-READ) ADD READ-I-ARG A-MC-CODE-EXIT-VECTOR)
        (CHECK-PAGE-READ)
        (POPJ-AFTER-NEXT DISPATCH TRANSPORT-WRITE READ-MEMORY-DATA)
       ((M-T) DPB VMA Q-POINTER (A-CONSTANT (BYTE-VALUE Q-DATA-TYPE DTP-LOCATIVE)))

MC-SPREAD       ;%SPREAD expands into this.  Only tries to win for the D-LAST case as
        (CALL-XCT-NEXT MC-SPREAD-0)     ;generated by LEXPR-FUNCALL.
       ((M-C) A-ZERO)                   ;fake out end switch of XSPREAD
        ((C-PDL-BUFFER-POINTER) DPB C-PDL-BUFFER-POINTER Q-TYPED-POINTER
                        (A-CONSTANT (BYTE-VALUE Q-CDR-CODE CDR-NIL)))   ;Fix the last arg.
        (JUMP-XCT-NEXT MMCALL)          ;This has to hack specially since the normal thing
       ((M-R) SUB PDL-BUFFER-POINTER A-IPMARK) ;setting up M-R from the disp constant cant win.

MC-XCMV                 ;OPEN CALL BLOCK, MULTIPLE VALUES.
        ((M-D) READ-I-ARG)              ;# VALUES DESIRED IN D
                        ;FCTN TO BE CALLED IN T
        (CALL LMVRB)                    ;MAKE ROOM ON PDL
        ((PDL-PUSH) M-K)        ;RETURN VALUES BLOCK POINTER
        ((PDL-PUSH) M-D)
        (CALL-XCT-NEXT CBM0)            ;STORE CALL BLOCK
       ((M-C) A-ZERO)           ;JUST LEAVE RESULT IN T, IE, DESTINATION IGNORE.
        (POPJ-AFTER-NEXT
         (PDL-INDEX) ADD M-ZR (A-CONSTANT (EVAL %LP-CALL-STATE)))
       ((PDL-INDEX-INDIRECT) IOR PDL-INDEX-INDIRECT
                (A-CONSTANT (PLUS (BYTE-MASK %%LP-CLS-ADI-PRESENT)
                                  (BYTE-MASK %%LP-CLS-ATTENTION))))

MC-UCTOM(CALL ILLOP)    ;*CATCH open, multiple values

MC-MMISU(CALL ILLOP)    ;Prepare to make MICRO-MICRO call receiving N values.

;For now, works only on for XXX-TO-MACRO call.
MC-MR3V ((A-MICRO-FAULT-DC) READ-I-ARG)  ;Return 3 values.  Is jumped to.
        ((M-S) A-ZERO)
        (CALL-XCT-NEXT XRNVRPI)
       ((PDL-INDEX) SUB PDL-POINTER (A-CONSTANT 2))
        (JUMP-EQUAL M-I A-ZERO MC-MRXX)
        (JUMP MC-MR2V0)

;For now, works only on for XXX-TO-MACRO call.
MC-MR2V ((A-MICRO-FAULT-DC) READ-I-ARG) ;Return 2 values.  Is jumped to.
        ((M-S) A-ZERO)
MC-MR2V0(CALL-XCT-NEXT XRNVRPI)
       ((PDL-INDEX) SUB PDL-POINTER (A-CONSTANT 1))
        (JUMP-EQUAL M-I A-ZERO MC-MRXX)
        ((M-T) Q-TYPED-POINTER PDL-TOP)         ;RETURN LAST VALUE REGULAR WAY
MC-MRXX (POPJ-AFTER-NEXT (PDL-BUFFER-POINTER) SUB PDL-BUFFER-POINTER A-MICRO-FAULT-DC)
       (NO-OP)

MC-MRNV ((A-MICRO-FAULT-DC) READ-I-ARG) ;Return N values, number in M-C.  Is jumped to.
        (CALL FIND-MVR-FRAME)
        (JUMP-IF-BIT-CLEAR (LISP-BYTE %%LP-CLS-ADI-PRESENT) MD MC-MRNV-SINGLE-VALUE)
        (CALL-XCT-NEXT XRETN1)
       ((M-J) M-K)
        (JUMP MC-MRXX)

MC-MRNV-SINGLE-VALUE
        ((PDL-INDEX) M-A-1 PDL-POINTER A-C)     ;NEXT ARGUMENT SLOT
        ((M-T) Q-TYPED-POINTER PDL-INDEX-INDIRECT)
        (JUMP MC-MRXX)


MC-MURV ((A-MICRO-FAULT-DC) READ-I-ARG)         ;RETURN-NEXT-VALUE
        ((M-S) A-ZERO)
        (CALL-XCT-NEXT XRNVR)
       ((M-T) Q-TYPED-POINTER PDL-TOP)   ;Frob to return. PDL-SUB includes this in case of return
   (ERROR-TABLE ARG-POPPED 0 M-T)
        (JUMP-NOT-EQUAL M-I A-ZERO POPTJ) ;Pop arg if continuing.
        (JUMP MC-MRXX)

;Frobs which return.
MC-SUB-PP (POPJ-AFTER-NEXT (M-1) READ-I-ARG)
         ((PDL-BUFFER-POINTER) SUB PDL-BUFFER-POINTER A-1)

MC-POP-SPECPDL-AND-SUB-PP
        ((M-1) READ-I-ARG)
        ((PDL-BUFFER-POINTER) SUB PDL-BUFFER-POINTER A-1)
#+LAMBDA(CALL-IF-BIT-SET %%-PPBSPC
                        MICRO-STACK-PNTR-AND-DATA BBLKP) ;POP BINDING BLOCK (IF STORED ONE)
#+EXP   (CALL-IF-BIT-SET %%-PPBSPC
                        MICRO-STACK-DATA BBLKP)
        (POPJ)

))
