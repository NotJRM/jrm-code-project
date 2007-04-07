;;; -*- Mode:LISP; Package:TRAP; Base:10; Readtable:CL -*-

(export '(
          *magic-garbage-location*

          trap-on
          without-traps
          without-interrupts
          ))

  ;saving trap state, general.
  ;  the "return-register" is pretty much the most volatile thing, since they would be clobberred by practically
  ; any LISP call or call-hardware operation.  The "return-register" means the hardware
  ; R register and the GR:*RETURN-n* registers.  The tricky saving operation is done only by the macro
  ; SAVING-RETURN-REGISTER.  It makes three entries on the call stack:  one with the original O and A
  ; (and also the trap-pc filled in for debugging purposes), and two open frames to save the RETURN-n guys.
  ; One point is that the original R register gets swapped into both O and A after the original O and A
  ; have been saved, which is OK, but it will look like an active frame to somebody looking up the call stack.

;;;;;;;;;;;;
;;;;; ILLOP
;;;;;;;;;;;;

;;; This is an improved version that only calls error with the appropriate number of
;;; arguments, instead of 16.
li#:
(defmacro tail-error (a0 &rest arest)
  "When a call is made to error in a tail position use this macro instead to save information."
  (when (> (length arest) 14)
    (global:warn "LI:TAIL-ERROR macro with more than 15 args -- might fail!"))
  `(progn (li:error ,a0 ,@arest)
          nil))

(defmacro tail-illop (illop-string)
  (let ((code (user::allocate-illop-code illop-string)))
    `(progn (TRAP::ILLOP-FUNCTION ,code)
            nil)))

(defmacro illop (illop-string)
  (let ((code (user::allocate-illop-code illop-string)))
    `(TRAP::ILLOP-FUNCTION ,code)))

(defafun illop-function (illop-code)
  ;; This is an afun because we want to get the illop code
  ;; on to the mfio bus when we halt.

  ;; Turn off traps, but they probably are already off....
  (move gr::*trap-temp1* trap-off)
  (nop)
  (nop)

  ;; Get memory control to a convenient place.
  (move gr::*trap-temp4* memory-control)

  ;; Zero out the led field to turn on all the lights.
  (alu-field aligned-field-xor memory-control gr::*trap-temp4* gr::*trap-temp4* hw:%%memory-control-leds)

  ;; Get processor control to a convenient place.
  (move gr::*trap-temp2* processor-control)

  ;; Turn off the icache to make spying easy.
  (alu-field field-xor gr::*trap-temp3* gr::*trap-temp2* gr::*trap-temp2*
             hw:%%processor-control-icache-enables)

  ;; Halt the machine.
  (alu-field set-bit-right processor-control r0 gr::*trap-temp3*
             hw:%%processor-control-halt-processor)

  ;; With mfio has illop code.
  (move nop a0)
  (move nop a0)
  (move nop a0)
  (move nop a0)

  ;; Well, the machine has halted, but maybe someone will proceed it.

  ;; Restore processor-control.
  (move processor-control gr::*trap-temp2*)

  (move nop r0)
  (move nop r0)
  (move nop r0)
  (move nop r0)

  ;; Restore memory control, turn on traps.
  (alu-field field-pass memory-control gr::*trap-temp1* gr::*trap-temp4*
             hw:%%memory-control-master-trap-enable)

  ;; Throw in a few nop's so we can proceed without
  ;; screwing up the memory control register.
  (move nop r0)
  (move nop r0)
  (move nop r0)
  (move nop r0)

  (return a0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Stuff for interrupts.
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconstant *magic-garbage-location* 41.)

(defmacro saving-return-register (thunk)
 ;comments and/or wisecracks by the previous "(mis)management" flagged with ===  -rg 8/20/88
  ;;=== **call hardware cruft alert**
  ;; This looks simple doesn't it.  Just ahh.. Just.. heh heh
  ;; You can't imagine what is going on here.
  ;; The return register is used for temporaries by the compiler.
  ;; Function calls trash the return register, so we must save
  ;; it on interrupts.
  `(LET ((THUNK ,thunk))
;     (trap::illop "saving return frame.")

     ;;=== OPEN-CALL to get a new frame, and we
     ;; save old O and A in the Call stack.
     ;; Call destination is *trap-temp0* so we can trash
     ;; it later when we restore the return flag.
 ;following two instructions added 8/20/88 by RG.
 ;gee- they seem to sort of work as far as writting interesting things on the stack, but I dont see how it
 ; can ever get back properly with or without these.  So lets take them back out for now so as not to disturb things.
     (HW:WRITE-RETURN-PC-RETURN-DEST GR::*SAVE-TRAP-PC*)        ;put trap return on stack so stack trace
     (hw:nop)   ;timing                                         ;will be more comprehensible.
     (HW:CH-OPEN-CALL GR::*TRAP-TEMP1*)         ;WRITE-RETURN-PC-RETURN-DEST above actually occurs here!
                                                ; the RETURN-DEST register of this stack entry will get
                                                ; written GR::*TRAP-TEMP1* unless it is clobberred by the
                                                ; write PC-RETURN-DEST above.  Check hardware..
     ;;=== TAIL-OPEN-CALL to swap R with O and A
     ;; NOTE: THIS DEPENDS ON THE IMPLEMENTATION OF THE CALL HARDWARE.
     (HW:CH-TOPEN-CALL)                         ;R is now fresh frame gotten by OPEN-CALL.

     ;;=== Save the multiple value registers in a couple of OPEN frames.
     ;; Save them in reverse order to make it easy to get to the
     ;; return code.

     (HW:OPEN-FRAME)                    ;the A and O saved are both the original R.  New O (call it O1) loaded.
     (SETF (HW:O0)  GR::*RETURN-16*)
     (SETF (HW:O1)  GR::*RETURN-17*)
     (SETF (HW:O2)  GR::*RETURN-18*)
     (SETF (HW:O3)  GR::*RETURN-19*)
     (SETF (HW:O4)  GR::*RETURN-20*)
     (SETF (HW:O5)  GR::*RETURN-21*)
     (SETF (HW:O6)  GR::*RETURN-22*)
     (SETF (HW:O7)  GR::*RETURN-23*)
     (SETF (HW:O8)  GR::*RETURN-24*)
     (SETF (HW:O9)  GR::*RETURN-25*)
     (SETF (HW:O10) GR::*RETURN-26*)
     (SETF (HW:O11) GR::*RETURN-27*)
     (SETF (HW:O12) GR::*RETURN-28*)
     (SETF (HW:O13) GR::*RETURN-29*)
     (SETF (HW:O14) (HW:LDB (HW:READ-PROCESSOR-STATUS) HW:%%PROCESSOR-STATUS-RETURN-CODE 0.))
     (SETF (HW:O15) GR::*NUMBER-OF-RETURN-VALUES*)

     (HW:OPEN-FRAME)                  ;A saved is still orig R. O1 saved, New O (call it O2) loaded.
     (SETF (HW:O0)  GR::*RETURN-0*)
     (SETF (HW:O1)  GR::*RETURN-1*)
     (SETF (HW:O2)  GR::*RETURN-2*)
     (SETF (HW:O3)  GR::*RETURN-3*)
     (SETF (HW:O4)  GR::*RETURN-4*)
     (SETF (HW:O5)  GR::*RETURN-5*)
     (SETF (HW:O6)  GR::*RETURN-6*)
     (SETF (HW:O7)  GR::*RETURN-7*)
     (SETF (HW:O8)  GR::*RETURN-8*)
     (SETF (HW:O9)  GR::*RETURN-9*)
     (SETF (HW:O10) GR::*RETURN-10*)
     (SETF (HW:O11) GR::*RETURN-11*)
     (SETF (HW:O12) GR::*RETURN-12*)
     (SETF (HW:O13) GR::*RETURN-13*)
     (SETF (HW:O14) GR::*RETURN-14*)
     (SETF (HW:O15) GR::*RETURN-15*)


     ;;=== Now, we just open-call the thunk.  It had better not touch any
     ;; of the active registers or you'll fuck up the R that you're
     ;; trying to save.
     (FUNCALL THUNK)    ;this does an OPEN-CALL, which saves O and A, and loads a fresh frame from heap in O and A.
                        ; on return, this fresh frame will be in R.
     ;;=== Now, we are back from the routine.  Restore the lower multiple value
     ;; registers
     (SETQ GR::*RETURN-0*  (HW:O0))             ;O is O2, A is orig R.
     (SETQ GR::*RETURN-1*  (HW:O1))
     (SETQ GR::*RETURN-2*  (HW:O2))
     (SETQ GR::*RETURN-3*  (HW:O3))
     (SETQ GR::*RETURN-4*  (HW:O4))
     (SETQ GR::*RETURN-5*  (HW:O5))
     (SETQ GR::*RETURN-6*  (HW:O6))
     (SETQ GR::*RETURN-7*  (HW:O7))
     (SETQ GR::*RETURN-8*  (HW:O8))
     (SETQ GR::*RETURN-9*  (HW:O9))
     (SETQ GR::*RETURN-10* (HW:O10))
     (SETQ GR::*RETURN-11* (HW:O11))
     (SETQ GR::*RETURN-12* (HW:O12))
     (SETQ GR::*RETURN-13* (HW:O13))
     (SETQ GR::*RETURN-14* (HW:O14))
     (SETQ GR::*RETURN-15* (HW:O15))

     ;;=== Flush this open frame, get the next one.
     (setq gr::*trap-temp1* (hw:call 'flush-open-frame 0))      ;O (O2) to A. on return A to R.  Also, return
                                        ;restores O = O1, A = orig R.  "Value" (which is NIL) to gr::*trap-temp1*.
     (SETQ GR::*RETURN-16*  (HW:O0))
     (SETQ GR::*RETURN-17*  (HW:O1))
     (SETQ GR::*RETURN-18*  (HW:O2))
     (SETQ GR::*RETURN-19*  (HW:O3))
     (SETQ GR::*RETURN-20*  (HW:O4))
     (SETQ GR::*RETURN-21*  (HW:O5))
     (SETQ GR::*RETURN-22*  (HW:O6))
     (SETQ GR::*RETURN-23*  (HW:O7))
     (SETQ GR::*RETURN-24*  (HW:O8))
     (SETQ GR::*RETURN-25*  (HW:O9))
     (SETQ GR::*RETURN-26* (HW:O10))
     (SETQ GR::*RETURN-27* (HW:O11))
     (SETQ GR::*RETURN-28* (HW:O12))
     (SETQ GR::*RETURN-29* (HW:O13))
     (SETQ GR::*TRAP-TEMP1* (HW:O14))
     (SETQ GR::*NUMBER-OF-RETURN-VALUES* (HW:O15))

     (setq gr::*trap-temp2* (hw:call 'flush-open-frame 0))      ;O (O1) to A. on return A to R. Also, return
                                       ;restores O = A = orig R.  "Value" (which is NIL) to gr::*trap-temp2*.
     ;;=== Trap temp1 now contains the info about whether the
     ;; return mv bit is on or not.
     (if (zerop gr::*trap-temp1*)
         (hw:ch-return-one-value)         ;These guys get dest RETURN and CH-RETURN, but not NEXT-PC-RETURN.
         (hw:ch-return-multiple-values))  ;Thus, they dont actually transfer!

     (hw:nop)

     NIL))

(defun flush-open-frame ()
  nil)

(defmacro saving-trap-frame-for-nonmodifying-exit (thunk)
  ;does not save the VMA, MD.
  `(LET ((THUNK ,thunk)
         (SAVED-OREG   GR::*SAVE-OREG*)
         (SAVED-PC     GR::*SAVE-TRAP-PC*)
         (SAVED-PC+    GR::*SAVE-TRAP-PC+*)
         (SAVED-STATUS GR::*SAVE-STATUS*)
         (SAVED-JCOND  GR::*SAVE-JCOND*)
         (SAVED-Q      (HW:READ-Q-REGISTER))
         (SAVED-SSTEP  (VINC:DISABLE-SINGLE-STEP-TRAP)))
     (FUNCALL THUNK)
     (VINC:RESTORE-SINGLE-STEP-TRAP SAVED-SSTEP)
     (HW:LOAD-Q-REGISTER       SAVED-Q)
     (SETQ GR::*SAVE-OREG*     SAVED-OREG)
     (SETQ GR::*SAVE-TRAP-PC*  SAVED-PC)
     (SETQ GR::*SAVE-TRAP-PC+* SAVED-PC+)
     (SETQ GR::*SAVE-STATUS*   SAVED-STATUS)
     (SETQ GR::*SAVE-JCOND*    SAVED-JCOND)))

(defmacro saving-trap-frame-for-recursive-traps (thunk)
  ;logically similar code to this is also in TRAP:DT-AND-OVF-TRAP-HANDLER-1
  `(LET* ((THUNK        ,thunk)
          (SAVED-OREG   GR::*SAVE-OREG*)
          (SAVED-PC     GR::*SAVE-TRAP-PC*)
          (SAVED-PC+    GR::*SAVE-TRAP-PC+*)
          (SAVED-STATUS GR::*SAVE-STATUS*)
          (SAVED-JCOND  GR::*SAVE-JCOND*)
          (SAVED-Q      (HW:READ-Q-REGISTER))
          (SAVED-SSTEP  (VINC:DISABLE-SINGLE-STEP-TRAP))
          (MEMSTAT      (HW:READ-MEMORY-STATUS))
          (VMA          (HW:READ-VMA))
          (MD (PROGN
                (WHEN (= HW:$$WMD-VALID (HW:LDB MEMSTAT HW:%%MEMORY-STATUS-MD-WRITTEN-LATELY 0))
                  (HW:VMA-START-WRITE-NO-GC-TRAP-UNBOXED TRAP:*MAGIC-GARBAGE-LOCATION*)
                  (HW:MEMORY-WAIT)
                  (HW:MD-START-WRITE-NO-GC-TRAP-UNBOXED (HW:READ-MD)))
                (TRAP:TRAP-ON)          ;any trap must leave valid MD in both read and write MD's.
                (HW:READ-MD))))
     (FUNCALL THUNK SAVED-PC SAVED-PC+)
     (HW:READ-MD)
     (HW:NOP)
     (HW:TRAP-OFF)
     (VINC:RESTORE-SINGLE-STEP-TRAP SAVED-SSTEP)
     (SETQ GR::*SAVE-OREG*     SAVED-OREG)
     (SETQ GR::*SAVE-TRAP-PC*  SAVED-PC)
     (SETQ GR::*SAVE-TRAP-PC+* SAVED-PC+)
     (SETQ GR::*SAVE-STATUS*   SAVED-STATUS)
     (SETQ GR::*SAVE-JCOND*    SAVED-JCOND)
     (HW:LOAD-Q-REGISTER       SAVED-Q)
     (HW:WRITE-MD-UNBOXED MD)
     (HW:VMA-START-WRITE-NO-GC-TRAP-UNBOXED TRAP:*MAGIC-GARBAGE-LOCATION*)
     (VMEM:WRITE-MD-GENERIC MD
                            (HW:LDB-NOT MEMSTAT HW:%%MEMORY-STATUS-MD-NOT-BOXED-BIT 0))
     (VMEM:WRITE-VMA-GENERIC VMA
                             (HW:LDB-NOT MEMSTAT HW:%%MEMORY-STATUS-VMA-NOT-BOXED-BIT 0))))

(defmacro flush-read-errors (thunk)
  ;; We depend on the handler to restore the vma and the md.
  `(LET* ((THUNK    ,thunk)
          (TRANSP-TYPE (HW:LDB-NOT (HW:READ-MEMORY-STATUS) HW:%%MEMORY-STATUS-TRANSPORT-TYPE 0.))
          (MAP-BITS  (map:HW-READ-MAP-safe))    ; $$$ Changed to call hw-read-map-safe <15-Nov-88 JIM>
          (VMA       (HW:READ-VMA))
          (VMA-BOXED (HW:LDB-NOT (HW:READ-MEMORY-STATUS) HW:%%MEMORY-STATUS-VMA-NOT-BOXED-BIT 0.))
          (MD        (HW:READ-MD))
          (MD-BOXED  (HW:LDB-NOT (HW:READ-MEMORY-STATUS) HW:%%MEMORY-STATUS-MD-NOT-BOXED-BIT 0.)))
;     (illop "Flushing read errors")
;     (setq gr:*trap-temp5* vma-boxed)
;     (setq gr:*save-o-a-r* md-boxed)
     (HW:VMA-START-READ-NO-TRANSPORT-VMA-UNBOXED-MD-UNBOXED *MAGIC-GARBAGE-LOCATION*)
     (HW:MEMORY-WAIT)
     (HW:READ-MD)
     (FUNCALL THUNK VMA VMA-BOXED MD MD-BOXED MAP-BITS TRANSP-TYPE)))

(defmacro flush-write-errors (thunk)
  ;; We depend on the handler to restore the vma and the md.
  `(LET* ((THUNK    ,thunk)
          (GC-TRAP   (HW:LDB-NOT (HW:READ-MEMORY-STATUS) HW:%%MEMORY-STATUS-GC-TRAP-ENABLE 0.))
          (MAP-BITS  (map:HW-READ-MAP-safe))    ; $$$ Changed to call hw-read-map-safe <15-Nov-88 JIM>
          (VMA       (HW:READ-VMA))
          (VMA-BOXED (HW:LDB-NOT (HW:READ-MEMORY-STATUS) HW:%%MEMORY-STATUS-VMA-NOT-BOXED-BIT 0.))
          (MD        (HW:READ-MD))
          (MD-BOXED  (HW:LDB-NOT (HW:READ-MEMORY-STATUS) HW:%%MEMORY-STATUS-MD-NOT-BOXED-BIT 0.)))
;     (illop "Flushing write errors")
;     (setq gr:*trap-temp5* vma-boxed)
;     (setq gr:*save-o-a-r* md-boxed)
     (HW:WRITE-MD (HW:UNBOXED-CONSTANT 0) :UNBOXED)
     (HW:VMA-START-WRITE-NO-GC-TRAP-UNBOXED *MAGIC-GARBAGE-LOCATION*)
     (HW:MEMORY-WAIT)
     (HW:READ-MD)
     (FUNCALL THUNK VMA VMA-BOXED MD MD-BOXED MAP-BITS GC-TRAP)))

(defmacro flush-gc-trap (thunk)
  `(PROGN (FUNCALL ,thunk)
          (if (= (HW:LDB-NOT (HW:READ-MEMORY-STATUS)
                             HW:%%MEMORY-STATUS-VMA-NOT-BOXED-BIT 0.)
                 HW:$$BOXED)
              (HW:VMA-START-WRITE-BOXED   (HW:READ-VMA))
              (HW:VMA-START-WRITE-UNBOXED (HW:READ-VMA)))))


;;; Why shouldn't you use these?  Because it can really fuck up the
;;; response of the rest of the system.  If you are not careful, you
;;; can hang the machine up indefinitely, or crash it because page
;;; faults are not able to be taken.  Usually there are "modify-foo"
;;; functions sprinkled around the code.  Use them.

(defmacro disable-traps (thunk)
  `(LET ((OLD-TRAP-STATE (HW:TRAP-OFF))
         (THUNK          ,thunk))
     (FLET ((RESTORE-TRAPS ()
              #+(target falcon)(trap-restore old-trap-state) ;;||| Deal with running on lambda 9/29/88 --wkf
              #+(target lambda)(progn (HW:WRITE-MEMORY-CONTROL
                                        (HW:DPB OLD-TRAP-STATE HW:%%MEMORY-CONTROL-MASTER-TRAP-ENABLE
                                                (HW:READ-MEMORY-CONTROL)))
                                      (HW:NOP)
                                      (HW:NOP)
                                      NIL)
              ))
       (FUNCALL THUNK #'RESTORE-TRAPS))))

(defmacro without-traps (thunk)
  `(LET ((THUNK ,thunk))
     (DISABLE-TRAPS
       #'(LAMBDA (RE-ENABLE-TRAPS)
           (PROG1 (FUNCALL THUNK)
                  (FUNCALL RE-ENABLE-TRAPS))))))

(defmacro without-interrupts (&rest body)
  (let ((old-sequence (zl:gensym)))
    `(let ((,old-sequence gr:*allow-sequence-break*))
       (progn    #+forward-reference li:unwind-protect  ; $$$ Removed forward reference. <22-Nov-88 wkf>
         (progn (setq gr:*allow-sequence-break* (1+ ,old-sequence))
                ,@body)
         (setq gr:*allow-sequence-break* ,old-sequence)))))

(defafun trap-on ()
  (move a0 trap-off boxed-right)
  ;; per Doug S. it is ok to read and write a functional source in the same instruction. --wkf
  ;; gr:*one*  hw:$$trap-enable
  (alu-field field-pass memory-control gr:*one* memory-control (quote 287) pw-ii dt-none unboxed)
  (alu pass-status nop ignore ignore)
  (move return a0 boxed-right ch-return next-pc-return) ;;Returns the old-trap-state
  ;; Takes effect for 3rd cycle/instruction following (i.e. The instruction we return to.) --wkf
  )

(defafun trap-restore (old-trap-state)
  ;; per Doug S. it is ok to read and write a functional source in the same instruction. --wkf
  (alu-field field-pass memory-control a0 memory-control (quote 287) pw-ii dt-none unboxed)
  (alu pass-status nop ignore ignore)
  (move return gr:*nil* boxed-right ch-return next-pc-return)
  ;; Takes effect for 3rd cycle/instruction following (i.e. The instruction we return to.) --wkf
  )

(defmacro %trap-restore (old-trap-state)
  "WARNING: You are responsible for making sure Multi-Function I/O clears out
and no traps happen (including unlinked functions)!!!
(Takes effect for 3rd cycle/instruction following)" ;; --wkf per Doug S.
;;;@@@ This could be one instruction but I can't figure out how to make fleabit do so. --wkf
  `(hw:write-memory-control
     (hw:dpb-unboxed ,old-trap-state hw:%%memory-control-master-trap-enable
                     (hw:read-memory-control))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Initial trap handlers
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun reset-trap-handler ()
  (if (= gr::*save-trap-pc+* 0)
      (illop "Probably undefined function, jump to zero.")
      (illop "TRAP: Unexpected RESET trap.")))

(defun trace-trap-handler ()
  ;(illop "TRAP: Unexpected trace trap.")
  (saving-return-register
    #'(lambda ()
        (k2::kbug-trap-handler-1)))
  (hw:jump 'non-modifying-exit)
  )

(defun icache-parity-trap-handler ()
  (illop "TRAP: ICACHE - Unexpected parity trap."))

(defun icache-nubus-error-trap-handler ()
  (illop "TRAP: ICACHE - Unexpected icache nubus error trap."))

(defun icache-nubus-timeout-trap-handler ()
  (illop "TRAP: ICACHE - Unexpected nubus timeout trap."))

(defun icache-map-fault-trap-handler ()
  (saving-return-register
    #'(lambda ()
        (icache-map-fault-trap-handler-1)))
  (hw:jump 'non-modifying-exit))

(defun icache-map-fault-trap-handler-1 ()
  (saving-trap-frame-for-recursive-traps
    #'(lambda (pc pc+)
        (map-fault:icache-map-fault-handler pc+))))

(defun memory-read-parity-trap-handler ()
  (illop "TRAP: MEMORY READ - Unexpected parity trap."))

(defun memory-read-nubus-error-trap-handler ()
  (illop "TRAP: MEMORY READ - Unexpected nubus error trap."))

(defun memory-read-nubus-timeout-trap-handler ()
  (illop "TRAP: MEMORY READ  - Unexpected nubus timeout trap."))

(defun memory-read-transporter-trap-handler ()
  (saving-return-register
    #'(lambda ()
        (transporter-trap-handler-return-saved)))
  (hw:jump 'non-modifying-exit))

(defun transporter-trap-handler-return-saved ()
  (saving-trap-frame-for-nonmodifying-exit      ;this will affect VMA and MD at non-trap level, so dont save them here.
    #'(lambda ()
        (let ((mstat (hw:read-memory-status)))
          (transporter-ram:transporter-trap-handler
            (hw:read-vma) (hw:ldb-not mstat hw:%%memory-status-vma-not-boxed-bit 0.)
            (hw:read-md)  (hw:ldb-not mstat hw:%%memory-status-md-not-boxed-bit 0.)
            ;; $$$ CXhanged to call hw-read-map-safe <15-Nov-88 JIM>
            (map:hw-read-map-safe) (hw:ldb-not mstat hw:%%memory-status-transport-type 0.)
            )))))

;(defun transporter-trap-handler (vma vma-boxed md md-boxed map-bits transp-type)
;  (trap:trap-on)
;  (li:error "Transporter Trap" vma vma-boxed md md-boxed map-bits transp-type)
;  nil)

(defun memory-write-nubus-error-trap-handler ()
  (illop "TRAP: MEMORY WRITE - Unexpected nubus error trap."))

(defun memory-write-nubus-timeout-trap-handler ()
  (illop "TRAP: MEMORY WRITE - Unexpected nubus timeout trap."))

(defun memory-read-page-fault-trap-handler ()
  (saving-return-register
    #'(lambda ()
        (read-page-fault-handler-return-saved)))
  (hw:jump 'non-modifying-exit))

(defun read-page-fault-handler-return-saved ()
  (saving-trap-frame-for-nonmodifying-exit      ;will deal explicitly with VMA, MD so dont save here.
    #'(lambda ()
        (flush-read-errors
          #'(lambda (vma vma-boxed md md-boxed map-bits transp-type)
              (map-fault::read-fault-handler vma vma-boxed md md-boxed map-bits transp-type))))))


(defun memory-write-page-fault-trap-handler ()
;  (illop "TRAP: MEMORY WRITE - Unexpected page fault trap.")
  (saving-return-register
    #'(lambda ()
        (write-page-fault-handler-return-saved)))
  (hw:jump 'non-modifying-exit))

(defun write-page-fault-handler-return-saved ()
  (saving-trap-frame-for-nonmodifying-exit      ;will deal explicitly with VMA, MD.
    #'(lambda ()
        (flush-write-errors
          #'(lambda (vma vma-boxed md md-boxed map-bits gc-trap)
              (map-fault::write-fault-handler vma vma-boxed md md-boxed map-bits gc-trap))))))

(defun memory-write-gc-trap-handler ()
  (saving-return-register
    #'(lambda ()
;       (trap::illop "entering gc fault handler (This should not happen).")
        (write-gc-trap-handler-return-saved)))
  (hw:jump 'non-modifying-exit))


(defun write-gc-trap-handler-return-saved ()
  (saving-trap-frame-for-nonmodifying-exit      ;must preserve VMA, MD after here.  does it?
    #'(lambda ()
        (flush-gc-trap
          #'(lambda ()
              (gc-fault::gc-fault-handler))))))

(defun floating-point-trap-handler ()
  (illop "TRAP: Unexpected floating point trap."))

(defun spare14-trap-handler ()
  (illop "TRAP: Unexpected spare 14 trap."))

(defun overflow-trap-handler ()
  (hw:jump 'trap::datatype-trap-handler))

(defun datatype-trap-handler ()
  (trap:saving-return-register
    #'(lambda () (dt-and-ovf-trap-handler-1)))  ;does its own saving.
  (if gr:*kbug-trap*
      (hw:jump 'trap::non-modifying-exit)
    (hw:jump 'trap::modifying-exit)))


(defun heap-empty-trap-handler ()
  ;; disable heap empty traps before calling error to avoid infinite heap empty traps
  (hw:write-processor-control (hw:dpb hw:$$call-heap-underflow-trap-disable
                                      hw:%%processor-control-heap-underflow-trap-enable
                                      (hw:read-processor-control)))
  (li:error "Unexpected heap empty trap: Your call stack has overflowed!! Flush call stack to continue ...")
;  (saving-return-register
;    #'(lambda ()
;       (heap-empty-trap-handler-1)))
;  (hw:jump 'non-modifying-exit)
  )

(defun heap-empty-trap-handler-1 ()
  (hw:write-processor-control (hw:dpb hw:$$call-heap-underflow-trap-disable
                                      hw:%%processor-control-heap-underflow-trap-enable
                                      (hw:read-processor-control)))
  (saving-trap-frame-for-recursive-traps
    #'(lambda (pc pc+)
        (li:dump-call-hardware)
        (li:restore-call-hardware nil)
        nil)))

(defun instruction-trap-handler ()
  (saving-return-register
    #'(lambda ()
        (instruction-trap-handler-1)))
  (hw:jump 'non-modifying-exit))

(defun instruction-trap-handler-1 ()
  (saving-trap-frame-for-recursive-traps
    #'(lambda (pc pc+)
        (k2:fix-undefined-function pc pc+))))

(defun spare11-trap-handler ()
  (illop "TRAP: Unexpected spare 11 trap."))

(defun debugger-trap-handler ()
  (saving-return-register               ;this puts two extra frames on stack to save all the *RETURN-n* guys.
    #'(lambda ()
;       (illop "Hah -gotcha debugger entry")
        (k2::kbug-trap-handler-1)))
  (hw:jump 'non-modifying-exit))


(defun interrupt6-trap-handler ()
  (illop "TRAP: Unexpected interrupt 6."))

(defun interrupt5-trap-handler ()
  (illop "TRAP: Unexpected interrupt 5."))

(defun iop-trap-handler ()
  (illop "TRAP: Unexpected IOP interrupt."))

(defun interrupt3-trap-handler ()
  (illop "TRAP: Unexpected interrupt 3."))

(defun interrupt2-trap-handler ()
  (illop "TRAP: Unexpected interrupt 2."))

(defun interrupt1-trap-handler ()
  (illop "TRAP: Unexpected interrupt 1."))

(defun interrupt0-trap-handler ()
  (illop "TRAP: Unexpected interrupt 0."))

(defun timer-1024-trap-handler ()
  ;(illop "TRAP: Unexepected 1024 timer trap.")
  (saving-return-register
    #'(lambda ()
        (timers::handle-1024-microsecond-interrupt)))
  (hw:jump 'non-modifying-exit))

(defun timer-16384-trap-handler ()
  (saving-return-register
    #'(lambda ()
        (timers::handle-16384-microsecond-interrupt)))
  ;; Yow!  Do we have non local exits yet?
  (hw:jump 'non-modifying-exit))

(defun spurious-trap-handler ()
  (illop "TRAP: Spurious trap."))
