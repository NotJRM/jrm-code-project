;;; -*- Mode: LISP; Package: lambda; Base:8; readtable: ZL -*-
;       ** (c) Copyright 1980 Massachusetts Institute of Technology **

;Managing microcode entries and stuff:
;  All actual microcode entry address are stored in MICRO-CODE-SYMBOL-AREA.
;This area is 1000 locations long.  The first 600 are accessible via
;misc macroinstruction (values 200-777).
;  How DTP-U-ENTRY works:  DTP-U-ENTRY is sort of an indirect pointer relative
;to the origin of MICRO-CODE-ENTRY-AREA.  The Q referenced is to be interpreted
;in functional context in the normal fashion, with one exception: If the
;data type is DTP-FIX,  this is a "real" ucode entry.
;In that case, various data (the number of args, etc), can be obtained
;by referencing various other specified areas with the same offset as was used
;to reference MICRO-CODE-ENTRY-AREA.  The address to transfer to in microcode
;is gotten by referencing MICRO-CODE-SYMBOL-AREA at the relative address
;that was obtained from MICRO-CODE-ENTRY-AREA.  The reason for the indirecting
;step from MICRO-CODE-ENTRY-AREA to MICRO-CODE-SYMBOL-AREA is to separate
;the world into two independant pieces.  (The microcode and MICRO-CODE-SYMBOL-AREA
;separate from the rest of the load).

;  Making new microcoded functions.  Two "degrees of commitment" are available,
;ie, the newly added function can be made available as a misc instruction or not.
;If it is available as a misc instruction, the system becomes completely committed
;to this function remaining microcoded forever.  If not, it is possible in the future to
;decommit this function from microcode, reinstating the macrocoded definition.

;  Decommiting can be done either by restoring the DTP-FEF-POINTER to the function cell,
;or by putting it in the MICRO-CODE-ENTRY-AREA position.  This latter option allows
;the microcoded definition to be quickly reinstalled.

;RE A-MEM AND M-MEM.  SEPARATE REGISTER ADDRESSES HAVE BEEN RETAINED SINCE
; THERE REALLY ARE TWO REGISTERS IN THE HARDWARE AND WE WANT TO BE
; ABLE TO EXAMINE BOTH IN LAM. HOWEVER, IN THE FOLLOWING, THERE IS
; REALLY ONLY ONE ARRAY, 0-77 OF WHICH IS CONSIDERED TO BE M-MEM, THE REST, A-MEM.

;A "TOTAL" SNAPSHOT OF THE PROCESSOR CONSISTS OF A UCODE-IMAGE AND A UCODE-STATE.
;THE UCODE-IMAGE CONTAINS QUANTITIES WHICH ARE UNCHANGED ONCE THEY ARE LOADED,
;WHILE ALL "DYNAMIC" QUANTITIES ARE CONTAINED IN THE UCODE-STATE.  THE ASSIGNMENT
;AS TO WHICH ONE IS MADE ON A MEMORY BY MEMORY BASIS EXCEPT FOR A-MEMORY
;IS ASSIGNED ON A LOCATION BY LOCATION BASIS.  AS WELL AS THE
;CONTENTS OF ALL HARDWARE MEMORIES, THE COMBINED UCODE-IMAGE AND UCODE-STATE
;ALSO CONTAIN COPIES OF MICRO-CODE-RELATED MAIN MEMORY
;AREAS SUCH AS MICRO-CODE-SYMBOL-AREA AND PAGE-TABLE-AREA.  THE INTENTION IS THAT
;ALL DATA WHICH CHANGES "MAGICALLY" FROM THE POINT OF VIEW OF LISP BE INCLUDED IN UCODE-STATE.
;THUS THE INCLUSION OF PAGE-TABLE-AREA.  ONE MOTOVATION FOR HAVING SUCH AN INCLUSIVE
;UCODE-STATE IS TO BE ABLE TO FIND POSSIBLE BUGS BY CHECKING THE PAGE-TABLES ETC, FOR
;CONSISTENCY.  ALSO, IT MAY BE POSSIBLE IN THE FUTURE TO SINGLE STEP MICROCODE
;VIA THIS MECHANISM (EITHER VIA HARDWARE OR VIA A SIMULATOR).

(DECLARE (SPECIAL CURRENT-UCODE-IMAGE CURRENT-ASSEMBLY-DEFMICS CURRENT-ASSEMBLY-TABLE
                  CURRENT-ASSEMBLY-HIGHEST-MISC-ENTRY))

;;; SETQ'ed by files in Lambda-Diag directory...
(proclaim '(special RAAME RAAMO RACME RACMO RADME RADMO RAM1E RAM2E #|RAMBO|# RAPBE RAUSE RAMME))

(DEFVAR NUMBER-MICRO-ENTRIES NIL)  ;Should have same value as SYSTEM:%NUMBER-OF-MICRO-ENTRIES
                                   ;Point is, that one is stored in A-MEM and is reloaded
                                   ;if machine gets warm-booted.

;A UCODE-IMAGE AND ASSOCIATED STUFF DESCRIBE THE COMPLETE STATE OF A MICRO-LOAD.
; NOTE THAT THIS IS NOT NECESSARILY THE MICRO-LOAD ACTUALLY LOADED INTO THE MACHINE
; AT A GIVEN TIME.
(DEFSTRUCT (UCODE-IMAGE :ARRAY :NAMED)
   UCODE-IMAGE-VERSION            ;VERSION # OF MICROCODE THIS IS.
   UCODE-IMAGE-MODULE-POINTS      ;LIST OF UCODE-MODULE STRUCTURES, "MOST RECENT" FIRST.
                                  ; THESE GIVE MODULES
                                  ;THAT WERE LOADED AND STATE OF LOAD AFTER EACH SO
                                  ;THAT IT IS POSSIBLE TO UNLOAD A MODULE, ETC. (IN PUSH
                                  ;DOWN FASHION.  ALL MODULES LOADED SINCE THAT
                                  ; MODULE MUST ALSO BE UNLOADED, ETC.)
   UCODE-IMAGE-MODULE-LOADED      ;A TAIL OF UCODE-IMAGE-MODULE-POINTS, WHICH IS
                                  ;  IS LIST OF MODULES ACTUALLY LOADED NOW.
   UCODE-IMAGE-TABLE-LOADED       ;THE CONCENTATIONATION OF THE UCODE-TABLES FOR
                                  ;  THE MODULES LOADED.
   UCODE-IMAGE-ASSEMBLER-STATE       ;ASSEMBLER STATE AFTER MAIN ASSEMBLY
   (UCODE-IMAGE-CONTROL-MEMORY-ARRAY      ;DATA AS LOADED INTO CONTROL MEMORY
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-CONTROL-MEMORY))  ;SIZE-OF-HARDWARE-EXISTING-CONTROL-MEMORY
                         ;SIZE-OF-HARDWARE-CONTROL-MEMORY
   (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY     ;DATA AS LOADED INTO DISPATCH MEMORY
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-DISPATCH-MEMORY))
   (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE ;1 -> THIS A-MEM LOCATION PART OF UCODE-IMAGE
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-A-MEMORY ':TYPE 'ART-1B))
   (UCODE-IMAGE-A-MEMORY-ARRAY    ;DATA AS LOADED INTO A MEMORY
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-A-MEMORY))
   (UCODE-IMAGE-ENTRY-POINTS-ARRAY        ;IMAGE OF THE STUFF THAT NORMALLY GETS
    (MAKE-ARRAY 1000 ':LEADER-LIST '(577)))
                                  ; MAIN MEMORY, W/ FILL POINTER.
                                  ;   FIRST 600 LOCS ARE ENTRIES FOR MISC
                                  ;     INSTS 200-777.
                                  ;   NEXT 200 ARE FOR MICRO-CODE-ENTRIES
                                          ;     (SPECIFIED VIA MICRO-CODE-ENTRY PSEUDO IN
                                          ;      CONSLP)
                                          ;   REST ARE ENTRY POINTS TO MICROCOMPILED FCTNS.
   (UCODE-IMAGE-SYMBOL-ARRAY      ;CONSLP SYMBOLS. ALTERNATING SYMBOL, TYPE, VALUE
    (MAKE-ARRAY 3000 ':LEADER-LIST '(0)))
)

(DEFUN (UCODE-IMAGE NAMED-STRUCTURE-INVOKE) (OP &OPTIONAL UCODE-IMAGE &REST ARGS)
  (SELECTQ OP
    (:WHICH-OPERATIONS '(:PRINT-SELF))
    ((:PRINT-SELF)
     (SI:PRINTING-RANDOM-OBJECT (UCODE-IMAGE (CAR ARGS) :NO-POINTER)
       (FORMAT (CAR ARGS) "UCODE-IMAGE version ~d, modules ~s"
               (UCODE-IMAGE-VERSION UCODE-IMAGE)
               (UCODE-IMAGE-MODULE-POINTS UCODE-IMAGE))))
    (OTHERWISE (FERROR NIL "~S Bad operation for a named-structure" op))))

(DEFUN (UCODE-MODULE NAMED-STRUCTURE-INVOKE) (OP &OPTIONAL UCODE-MODULE &REST ARGS)
  (SELECTQ OP
    (:WHICH-OPERATIONS '(:PRINT-SELF))
    ((:PRINT-SELF)
     (SI:PRINTING-RANDOM-OBJECT (UCODE-MODULE (CAR ARGS) :NO-POINTER)
       (FORMAT (CAR ARGS) "UCODE-MODULE ~s" (UCODE-MODULE-SOURCE UCODE-MODULE))))
    (OTHERWISE (FERROR NIL "~S Bad operation for a named-structure" op))))

(DEFVAR CURRENT-UCODE-IMAGE (MAKE-UCODE-IMAGE))
(DEFVAR CURRENT-ASSEMBLY-DEFMICS NIL)
(DEFVAR CURRENT-ASSEMBLY-TABLE NIL)

(DEFVAR LAM-UCODE-IMAGE (MAKE-UCODE-IMAGE)) ;Use this for frobbing other machine with LAM.

; A UCODE-MODULE IS THE UNIT IN WHICH UCODE IS LOADED.  THE UCODE-MODULE
;CONTAINTS ENUF INFORMATION TO COMPLETELY HOLD THE LOGICAL STATE OF THE UCODE-LOADER
;JUST AFTER THE MODULE WAS LOADED.  THUS, MODULES MAY BE OFF-LOADED IN REVERSE
;ORDER FROM THAT IN WHICH THEY WERE LOADED.  THE ACTIVE UCODE-MODULES ARE
;CONTAINED IN A LIST OFF OF UCODE-IMAGE-MODULE-POINTS, THE LAST ELEMENT IN THAT
;LIST REFERS TO THE INITIAL MICROCODE LOAD.
; A-MEMORY IS ALLOCATED IN TWO REGIONS, AN ASCENDING CONSTANTS BLOCK, AND A
;VARIABLE BLOCK DESCENDING FROM THE TOP.  IF THE TWO COLLIDE, A-MEMORY IS EXHAUSTED.
(DEFSTRUCT (UCODE-MODULE :ARRAY :NAMED)
   UCODE-MODULE-IMAGE                   ;IMAGE THIS MODULE PART OF
   UCODE-MODULE-SOURCE                  ;WHERE CAME FROM: A pathname
   UCODE-MODULE-GENERIC-PATHNAME        ;of the source
   UCODE-MODULE-ASSEMBLER-STATE         ;assembler state after module assembly
   UCODE-MODULE-TABLE                   ;as output by assembler.
   UCODE-MODULE-ENTRY-POINTS-INDEX      ;fill-pointer of UCODE-IMAGE-ENTRY-POINTS-ARRAY
   UCODE-MODULE-DEFMICS
   UCODE-MODULE-SYM-ADR                 ;final fill pointer for UCODE-IMAGE-SYMBOL-ARRAY
   UCODE-MODULE-I-MEM-ALIST             ;Alist of I-MEM array resulting from assembly.
   UCODE-MODULE-D-MEM-ALIST             ;Alist of D-MEM array resulting from assembly.
   UCODE-MODULE-A-MEM-ALIST             ;Alist of A-MEM array resulting from assembly.
)

(DEFSTRUCT (UCODE-STATE)

;THE FOLLOWING REGISTERS "SHOULD" BE IN THE UCODE-STATE.  HOWEVER, THEY ARE
;COMMENTED OUT FOR THE TIME BEING BECAUSE (1) THEY ARE NOT NEEDED FOR PRESENT
;PURPOSES. (2) THEY ARE AWKWARD TO DO WITHOUT BIGNUMS, ETC.  THEY
;ARE IN THE SAME ORDER THEY ARE IN (ALMOST) THE
; REGISTER ADDRESS SPACE

; (UCODE-STATE-PC 0)    ;     PC  (PC)
;  (UCODE-STATE-USP 0)  ;     U STACK POINTER  (USP)
;;RAIR==62562   ;     .IR (PUT IN DIAG INST REG, THEN LOAD INTO IR, THEN
;;              ;         UPDATE OBUS DISPLAY. DIAGNOSTIC ONLY)
;  (UCODE-STATE-IR 0)   ;     SAVED IR (THE ONE SAVE ON FULL STATE SAVE
;               ;      AND RESTORED ON FULL RESTORE)
;               ;      THIS IS NORMALLY THE UINST ABOUT TO GET EXECUTED.
;  (UCODE-STATE-Q 0)    ;     Q REGISTER  (Q)
;  (UCODE-STATE-DISPATCH-CONSTANT 0)    ;     DISPATCH CONSTANT REGISTER (DC)
;;RARSET==62566 ;     RESET REGISTER!  DEPOSITING HERE
;               ;       CLEARS ENTIRE C, D, P, M1, M2, A, U AND
;               ;       M MEMORIES!
;;RASTS==62567  ;     STATUS REGISTER (32 BIT, AS READ BY ERERWS)
;  (UCODE-STATE-OUTPUT-BUS 0)   ;     OUTPUT BUS STATUS (32 BITS)
;
;;DUE TO LOSSAGE, THE FOLLOWING 4 ARE IN THE REGISTER ADDRESS SPACE AT A RANDOM PLACE
;  (UCODE-STATE-MEM-WRITE-REG 0)        ;MAIN MEM WRITE DATA REGISTER
;  (UCODE-STATE-VMA 0)          ;VMA (VIRTUAL MEMORY ADDRESS)
;  (UCODE-STATE-PDL-POINTER 0)  ;PDL POINTER (TO PDL BUFFER)
;  (UCODE-STATE-PDL-INDEX 0)    ;PDL INDEX (TO PDL BUFFER)

   (UCODE-STATE-A-MEMORY-ARRAY    ;DATA AS LOADED INTO A MEMORY
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-A-MEMORY ':TYPE 'ART-16B))
   (UCODE-STATE-PDL-BUFFER-ARRAY  ;DATA AS LOADED INTO PDL BUFFER
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-PDL-BUFFER ':TYPE 'ART-16B))
   (UCODE-STATE-MICRO-STACK-ARRAY ;DATA AS LOADED INTO USTACK
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-MICRO-STACK))
   (UCODE-STATE-LEVEL-1-MAP       ;DATA AS LOADED INTO LEVEL 1 MAP.
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-LEVEL-1-MAP ':TYPE 'ART-8B))
   (UCODE-STATE-LEVEL-2-MAP       ;DATA AS LOADED INTO LEVEL 2 MAP
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-LEVEL-2-MAP ':TYPE 'ART-16B))
   (UCODE-STATE-UNIBUS-MAP        ;DATA AS LOADED INTO UNIBUS MAP.
    (MAKE-ARRAY SI:SIZE-OF-HARDWARE-UNIBUS-MAP ':TYPE 'ART-16B))
   (UCODE-STATE-PAGE-TABLE        ;COPY OF PAGE-TABLE-AREA
    (MAKE-ARRAY (SI:ROOM-GET-AREA-LENGTH-USED PAGE-TABLE-AREA)))
   (UCODE-STATE-PHYSICAL-PAGE-AREA-NUMBER       ;COPY OF LIKE NAMED AREA
    (MAKE-ARRAY (SI:ROOM-GET-AREA-LENGTH-USED PHYSICAL-PAGE-AREA-NUMBER)))
)

;This is really useful only for wired areas, but may as well work for all.
(DEFUN LOWEST-ADDRESS-IN-AREA (AREA)
  (DO ((REGION (si:%AREA-REGION-LIST AREA) (si:%REGION-LIST-THREAD REGION))
       (BSF (%LOGDPB 0 %%Q-BOXED-SIGN-BIT -1)
            (MIN BSF (SI:REGION-ORIGIN-TRUE-VALUE REGION))))
      ((LDB-TEST %%Q-BOXED-SIGN-BIT REGION)
       BSF)))

(DEFUN UCODE-IMAGE-STORE-ASSEMBLER-STATE (STATE UCODE-IMAGE)
   (SETF (UCODE-IMAGE-ASSEMBLER-STATE UCODE-IMAGE) STATE)
)

(DEFUN UCODE-IMAGE-INITIALIZE (UCODE-IMAGE &AUX TEM)
  (COND ((NULL UCODE-IMAGE)
         (MAKE-UCODE-IMAGE))
        (T (SETF (UCODE-IMAGE-MODULE-POINTS UCODE-IMAGE) NIL)  ;RESET POINTERS, ETC
           (SETQ TEM (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE UCODE-IMAGE))
           (DO I 0 (1+ I) (= I SI:SIZE-OF-HARDWARE-A-MEMORY)
               (AS-1 0 TEM I))
           (STORE-ARRAY-LEADER 577
                               (UCODE-IMAGE-ENTRY-POINTS-ARRAY UCODE-IMAGE)
                               0)
           (STORE-ARRAY-LEADER 0
                               (UCODE-IMAGE-SYMBOL-ARRAY UCODE-IMAGE)
                               0)
           UCODE-IMAGE)) )

(DEFUN READ-SIGNED-OCTAL-FIXNUM (&OPTIONAL (STREAM STANDARD-INPUT))
  (PROG (NUM CH SIGN)
        (SETQ SIGN 1)
        (SETQ NUM 0)
     L1 (COND ((= (SETQ CH (FUNCALL STREAM ':TYI)) #/-)
               (SETQ SIGN (* SIGN -1))
               (GO L1))
              ((OR (< CH 60)
                   (> CH 71))
                (GO L1)))       ;FLUSH ANY GARBAGE BEFORE NUMBER (CR-LF MOSTLY)
     L2 (SETQ NUM (+ (* NUM 10) (- CH 60)))
        (COND ((= (SETQ CH (FUNCALL STREAM ':TYI)) #/_)
               (RETURN (* SIGN (LSH NUM (READ-SIGNED-OCTAL-FIXNUM STREAM)))))
              ((OR (< CH 60)
                   (> CH 71))
                (RETURN (* NUM SIGN))))
        (GO L2)))

(DEFUN ADD-ASSEMBLY (&OPTIONAL FILE-NAME (IMAGE CURRENT-UCODE-IMAGE)
                     &AUX ASSEMBLER-STATE-AFTER PATHNAME GENERIC-PATHNAME)
  (COND ((NULL (BOUNDP 'RACMO))
         (READFILE "SYS: LAMBDA-DIAG; LAMREG LISP >")))
  (COND ((NOT (EQ %MICROCODE-VERSION-NUMBER
                  (UCODE-IMAGE-VERSION IMAGE)))
         (READ-UCODE-VERSION %MICROCODE-VERSION-NUMBER IMAGE)))
  (SETQ PATHNAME (FS:MERGE-PATHNAME-DEFAULTS FILE-NAME)
        GENERIC-PATHNAME (FUNCALL PATHNAME ':GENERIC-PATHNAME))
  (AND (EQ (UCODE-MODULE-GENERIC-PATHNAME (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE)))
           GENERIC-PATHNAME)
       (FLUSH-MODULE NIL IMAGE))        ;Evidently a new version, flush the old
 ;(UA-DEFINE-SYMS IMAGE)
  (ASSEMBLE PATHNAME (UCODE-MODULE-ASSEMBLER-STATE
                       (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE))))
  (SETQ ASSEMBLER-STATE-AFTER (MAKE-ASSEMBLER-STATE-LIST))
;MERGE RESULTS AND FORM NEW MODULE
  (MERGE-MEM-ARRAY I-MEM RACMO IMAGE)
  (MERGE-MEM-ARRAY D-MEM RADMO IMAGE)
  (MERGE-MEM-ARRAY A-MEM RAAMO IMAGE)
  (LET ((MODULE (MAKE-UCODE-MODULE)))
    (SETF (UCODE-MODULE-I-MEM-ALIST MODULE)
          (ALIST-DESCRIBING-ARRAY I-MEM))
    (SETF (UCODE-MODULE-D-MEM-ALIST MODULE)
          (ALIST-DESCRIBING-ARRAY D-MEM))
    (SETF (UCODE-MODULE-A-MEM-ALIST MODULE)
          (ALIST-DESCRIBING-ARRAY A-MEM))
    (SETF (UCODE-MODULE-IMAGE MODULE) IMAGE)
    (SETF (UCODE-MODULE-SOURCE MODULE) PATHNAME)
    (SETF (UCODE-MODULE-GENERIC-PATHNAME MODULE) GENERIC-PATHNAME)
    (SETF (UCODE-MODULE-ASSEMBLER-STATE MODULE) ASSEMBLER-STATE-AFTER)
    (SETF (UCODE-MODULE-ENTRY-POINTS-INDEX MODULE)
          (ARRAY-LEADER (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) 0))
    (SETF (UCODE-MODULE-DEFMICS MODULE)
          CURRENT-ASSEMBLY-DEFMICS)
    (SETF (UCODE-MODULE-TABLE MODULE)
          CURRENT-ASSEMBLY-TABLE)
    (SETF (UCODE-MODULE-SYM-ADR MODULE)
          (ARRAY-LEADER (UCODE-IMAGE-SYMBOL-ARRAY IMAGE) 0))
    (SETF (UCODE-IMAGE-MODULE-POINTS IMAGE)
          (CONS MODULE
                (UCODE-IMAGE-MODULE-POINTS IMAGE))))
)

(DEFUN ALIST-DESCRIBING-ARRAY (ARRAY)
  (LET ((ALIST))
    (DOTIMES (I (LENGTH ARRAY))
      (LET ((ELT (AREF ARRAY I)))
        (WHEN ELT (PUSH (CONS I ELT) ALIST))))
    ALIST))

(DEFCONST I-MEM-LENGTH SI:SIZE-OF-HARDWARE-CONTROL-MEMORY)
(DEFCONST A-MEM-LENGTH 2000)
(DEFCONST D-MEM-LENGTH 4000)

(DEFCONST NEEDED-CADREG-SYMBOLS
          '(RAPC RASIR RAOBS RASTS
                    RACMO RACME RADME RAPBE RAM1E RAM2E RAAME RAUSE RAMME RAFSE RAFDE
                    RARGE RACSWE RARDRE RACIBE RAGO RASTOP RARDRO RAFDO RAOPCE
                    RARS RASTEP RASA RAAMO RAMMO RARCON RAPBO RAUSO RADMO RADME)
  "Symbols from CADREG that must be dumped in dumped modules.
This saves the user loading a dumped module from having to load CADREG.")

(DEFUN DUMP-MODULE (&OPTIONAL OUTPUT-FILE MODULE
                    &AUX IMAGE FIRST-USER-MODULE-P)
  "Write a QFASL file containing the assembly of in ucode module MODULE.
Loading this file will be equivalent to repeating the ADD-ASSEMBLY that made MODULE.
MODULE defaults to the last one assembled (loaded?).
OUTPUT-FILE defaults based on MODULE's source file."
  (UNLESS MODULE
    (SETQ MODULE (CAR (UCODE-IMAGE-MODULE-POINTS CURRENT-UCODE-IMAGE))))
  (SETQ IMAGE (UCODE-MODULE-IMAGE MODULE))
  (SETQ FIRST-USER-MODULE-P
        (NULL (CDDR (MEMQ MODULE
                          (UCODE-IMAGE-MODULE-POINTS IMAGE)))))
  (SETQ OUTPUT-FILE (FS:MERGE-PATHNAME-DEFAULTS (OR OUTPUT-FILE "")
                                                (SEND (UCODE-MODULE-SOURCE MODULE)
                                                      ':NEW-CANONICAL-TYPE ':QFASL)
                                                ':QFASL))
  (SI:DUMP-FORMS-TO-FILE OUTPUT-FILE
                         `(,@(WHEN FIRST-USER-MODULE-P
                               ;; (If not first user module, CADREG must already be there).
                               (MAPCAR #'(LAMBDA (SYM)
                                           `(SETQ ,SYM ,(SYMEVAL SYM)))
                                       NEEDED-CADREG-SYMBOLS))
                           (RELOAD-MODULE
                             ',(UCODE-MODULE-I-MEM-ALIST MODULE)
                             ',(UCODE-MODULE-D-MEM-ALIST MODULE)
                             ',(UCODE-MODULE-A-MEM-ALIST MODULE)
                             ',(UCODE-MODULE-SOURCE MODULE)
                             ',(UCODE-MODULE-ASSEMBLER-STATE MODULE)
                             ',(UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE)
                             ',(UCODE-MODULE-DEFMICS MODULE)
                             ',(UCODE-MODULE-TABLE MODULE)
                             ',NIL
                             ',(MAPCAR 'UCODE-MODULE-GENERIC-PATHNAME
                                       (CDR (MEMQ MODULE
                                                  (UCODE-IMAGE-MODULE-POINTS IMAGE))))
                             ',%MICROCODE-VERSION-NUMBER
                             ',(WHEN FIRST-USER-MODULE-P
                                 ;; Only one previous module => it is the ucode,
                                 ;; so save data on it to don't need to read UCADR.SYM
                                 ;; to get the data.
                                 (UCODE-MODULE-ASSEMBLER-STATE
                                   (CADR (MEMQ MODULE
                                               (UCODE-IMAGE-MODULE-POINTS IMAGE)))))))
                         '(:PACKAGE :USER)))

;; QFASL files containing saved out incremental assemblies
;; contain calls to this function, which serves to recreate the module
;; as if it had just been assembled.
(DEFUN RELOAD-MODULE (I-MEM D-MEM A-MEM PATHNAME ASSEMBLER-STATE-AFTER
                      ENTRY-POINTS-ARRAY DEFMICS TABLE IGNORE
                      PREV-MODULES
                      &OPTIONAL ASSEMBLED-UCODE-VERSION UCODE-ASSEMBLER-STATE
                      &AUX (IMAGE CURRENT-UCODE-IMAGE)
                      (GENERIC-PATHNAME (SEND PATHNAME ':GENERIC-PATHNAME)))
  (UNLESS (EQ ASSEMBLED-UCODE-VERSION %MICROCODE-VERSION-NUMBER)
    (FERROR NIL "File was dumped under a different microcode version."))
  (COND ((NOT (EQ %MICROCODE-VERSION-NUMBER
                  (UCODE-IMAGE-VERSION IMAGE)))
         (IF UCODE-ASSEMBLER-STATE
             (RELOAD-UCODE-VERSION %MICROCODE-VERSION-NUMBER IMAGE UCODE-ASSEMBLER-STATE)
           (READ-UCODE-VERSION %MICROCODE-VERSION-NUMBER IMAGE))))
  (LET ((ACTUAL-PREV-MODULES
          (MAPCAR 'UCODE-MODULE-GENERIC-PATHNAME (UCODE-IMAGE-MODULE-POINTS IMAGE))))
    (UNLESS (EQUAL ACTUAL-PREV-MODULES PREV-MODULES)
      (FERROR "Current microcode state does not match that of this file,
which is ~A." PREV-MODULES)))
  (AND (EQ (UCODE-MODULE-GENERIC-PATHNAME (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE)))
           GENERIC-PATHNAME)
       (FLUSH-MODULE NIL IMAGE))        ;Evidently a new version, flush the old
  (DOLIST (D DEFMICS)
    (APPLY 'UA-DO-DEFMIC D))
  (LET ((MODULE (MAKE-UCODE-MODULE)))
    (MERGE-MEM-ALIST I-MEM RACMO IMAGE)
    (MERGE-MEM-ALIST D-MEM RADMO IMAGE)
    (MERGE-MEM-ALIST A-MEM RAAMO IMAGE)
    (SETF (UCODE-MODULE-I-MEM-ALIST MODULE) I-MEM)
    (SETF (UCODE-MODULE-D-MEM-ALIST MODULE) D-MEM)
    (SETF (UCODE-MODULE-A-MEM-ALIST MODULE) A-MEM)
    (SETF (UCODE-MODULE-IMAGE MODULE) IMAGE)
    (SETF (UCODE-MODULE-SOURCE MODULE) PATHNAME)
    (SETF (UCODE-MODULE-GENERIC-PATHNAME MODULE) GENERIC-PATHNAME)
    (SETF (UCODE-MODULE-ASSEMBLER-STATE MODULE) ASSEMBLER-STATE-AFTER)
    (SETF (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) ENTRY-POINTS-ARRAY)
    (SETF (UCODE-MODULE-ENTRY-POINTS-INDEX MODULE)
          (ARRAY-LEADER (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) 0))
    (SETF (UCODE-MODULE-DEFMICS MODULE)
          DEFMICS)
    (SETF (UCODE-MODULE-TABLE MODULE)
          TABLE)
;    (SETF (UCODE-IMAGE-SYMBOL-ARRAY IMAGE) SYMBOL-ARRAY)
    (SETF (UCODE-MODULE-SYM-ADR MODULE)
          (ARRAY-LEADER (UCODE-IMAGE-SYMBOL-ARRAY IMAGE) 0))
    (SETF (UCODE-IMAGE-MODULE-POINTS IMAGE)
          (CONS MODULE
                (UCODE-IMAGE-MODULE-POINTS IMAGE)))))

(DEFUN UNLOAD-MODULE (&OPTIONAL MOD (IMAGE CURRENT-UCODE-IMAGE))
  (COND ((NULL MOD)
         (SETQ MOD (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE)))))
  (COND ((NOT (EQ MOD (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE))))
         (FERROR NIL "Must unload modules in reverse order loaded")))
  (COND ((EQ (UCODE-IMAGE-MODULE-POINTS IMAGE)
             (UCODE-IMAGE-MODULE-LOADED IMAGE))
         (SETF (UCODE-IMAGE-MODULE-LOADED IMAGE)
               (CDR (UCODE-IMAGE-MODULE-POINTS IMAGE)))))
)

(DEFUN FLUSH-MODULE (&OPTIONAL MOD (IMAGE CURRENT-UCODE-IMAGE))
  (COND ((NULL MOD)
         (SETQ MOD (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE)))))
  (COND ((NOT (EQ MOD (CAR (UCODE-IMAGE-MODULE-POINTS IMAGE))))
         (FERROR NIL "Must flush modules in reverse order loaded")))
  (COND ((EQ (UCODE-IMAGE-MODULE-POINTS IMAGE)
             (UCODE-IMAGE-MODULE-LOADED IMAGE))
         (SETF (UCODE-IMAGE-MODULE-LOADED IMAGE)
               (CDR (UCODE-IMAGE-MODULE-POINTS IMAGE)))))
  (SETF (UCODE-IMAGE-MODULE-POINTS IMAGE)
        (CDR (UCODE-IMAGE-MODULE-POINTS IMAGE))))

;UA-DEFMIC is called during readin phase for incremental assemblies.
;Dont do anything immediately, since the world might bomb
;  out before you really win. Just buffers it up for later processing.
;OPCODE is value to appear in MISC instructions.  The entry point is stored in
;  MICRO-CODE-SYMBOL-AREA at this location less 200.  The OPCODE can also be
;  NIL, in which case the system will assign the next available one.
;  Note, however, that there is a possible screw in using NIL in conjunction
;  with a QINTCMP property and compiling QFASL files to disk: the compiled file
;  might be loaded at a later time when the actual OPCODE was different and lose.
(DEFUN UA-DEFMIC (&QUOTE NAME OPCODE ARGLIST LISP-FUNCTION-P &OPTIONAL (NO-QINTCMP NIL))
  (SETQ CURRENT-ASSEMBLY-DEFMICS
        (CONS (LIST NAME OPCODE ARGLIST LISP-FUNCTION-P NO-QINTCMP)
              CURRENT-ASSEMBLY-DEFMICS)))

;This called on buffered stuff from LAM:ASSEMBLE just before assembly actually done.
;ASSEMBLER-STATE environment has been established.
(compiler-let ((inhibit-fdefine-warnings :just-warn))
(DEFUN UA-DO-DEFMIC (NAME OPCODE ARGLIST LISP-FUNCTION-P NO-QINTCMP
                  &AUX FUNCTION-NAME INSTRUCTION-NAME MICRO-CODE-ENTRY-INDEX NARGS)
  (COND ((ATOM NAME)
         (SETQ FUNCTION-NAME NAME INSTRUCTION-NAME NAME))
        ((SETQ FUNCTION-NAME (CAR NAME) INSTRUCTION-NAME (CDR NAME))))
  (COND ((NULL OPCODE)
         (SETQ OPCODE (COND ((GET INSTRUCTION-NAME 'QLVAL))
                            (T (UA-ASSIGN-MICRO-ENTRY NAME))))))
  (PUTPROP INSTRUCTION-NAME OPCODE 'QLVAL)
  (SETQ NARGS (SI:ARGS-INFO-FROM-LAMBDA-LIST ARGLIST))
  (COND ((OR (BIT-TEST NARGS %ARG-DESC-QUOTED-REST)
             (BIT-TEST NARGS %ARG-DESC-EVALED-REST)
             (BIT-TEST NARGS %ARG-DESC-INTERPRETED)
             (BIT-TEST NARGS %ARG-DESC-FEF-QUOTE-HAIR)
             (AND (NOT NO-QINTCMP)
                  (NOT (= (LDB %%ARG-DESC-MAX-ARGS NARGS)
                          (LDB %%ARG-DESC-MIN-ARGS NARGS)))))
         (FERROR NIL "~%The arglist of the function ~s, ~s, is too hairy to microcompile.
ARGS-INFO = ~O~%"
                 NAME ARGLIST NARGS)))
  (COND (LISP-FUNCTION-P
         (SETQ MICRO-CODE-ENTRY-INDEX (compiler:ALLOCATE-MICRO-CODE-ENTRY-SLOT FUNCTION-NAME))
         (STORE (SYSTEM:MICRO-CODE-ENTRY-ARGLIST-AREA MICRO-CODE-ENTRY-INDEX) ARGLIST)
         (STORE (SYSTEM:MICRO-CODE-ENTRY-ARGS-INFO-AREA MICRO-CODE-ENTRY-INDEX) NARGS)
         ))
  (COND ((NOT NO-QINTCMP)
         (PUTPROP INSTRUCTION-NAME (LDB %%ARG-DESC-MAX-ARGS NARGS) 'QINTCMP)
         (OR (EQ FUNCTION-NAME INSTRUCTION-NAME)
             (PUTPROP FUNCTION-NAME (LDB %%ARG-DESC-MAX-ARGS NARGS) 'QINTCMP))))
)
)

(DEFUN UA-ASSIGN-MICRO-ENTRY (NAME) NAME
   (COND ((= CURRENT-ASSEMBLY-HIGHEST-MISC-ENTRY 0)
          (FERROR NIL "lossage assigning micro-entries")))
   (SETQ CURRENT-ASSEMBLY-HIGHEST-MISC-ENTRY (1+ CURRENT-ASSEMBLY-HIGHEST-MISC-ENTRY)))

;Do this when module containing DEFMIC is actually loaded
(DEFUN UA-LOAD-DEFMIC (NAME OPCODE ARGLIST LISP-FUNCTION-P NO-QINTCMP
                  &AUX FUNCTION-NAME INSTRUCTION-NAME MICRO-CODE-ENTRY-INDEX
                       MICRO-CODE-SYMBOL-INDEX)  NO-QINTCMP ARGLIST
  (COND ((ATOM NAME)
         (SETQ FUNCTION-NAME NAME INSTRUCTION-NAME NAME))
        ((SETQ FUNCTION-NAME (CAR NAME) INSTRUCTION-NAME (CDR NAME))))
  (COND ((NULL (SETQ OPCODE (GET INSTRUCTION-NAME 'QLVAL)))
         (FERROR NIL "OPCODE not assigned ~s" NAME)))
  (SETQ MICRO-CODE-SYMBOL-INDEX (- OPCODE 200))
  (COND (LISP-FUNCTION-P
         (LET ((FS (FSYMEVAL FUNCTION-NAME)))
           (COND ((NOT (= (%DATA-TYPE FS) DTP-U-ENTRY))
                  (FERROR NIL "Function cell of ~s not DTP-U-ENTRY" FUNCTION-NAME))
                 (T (SETQ MICRO-CODE-ENTRY-INDEX (%POINTER FS)))))))
  (LET ((PREV (AR-1 (FUNCTION SYSTEM:MICRO-CODE-ENTRY-AREA) MICRO-CODE-ENTRY-INDEX)))
    (COND ((AND PREV (NOT (FIXP PREV)))
           (PUTPROP FUNCTION-NAME PREV 'DEFINITION-BEFORE-MICROCODED))))
  (AS-1 MICRO-CODE-SYMBOL-INDEX
        (FUNCTION SYSTEM:MICRO-CODE-ENTRY-AREA)
        MICRO-CODE-ENTRY-INDEX)
)

;Call this to repair the damage if a reboot (either warm or cold) is done.
(DEFUN UA-REBOOT (&OPTIONAL (IMAGE CURRENT-UCODE-IMAGE))
  (DO () ((NULL (CDR (UCODE-IMAGE-MODULE-LOADED IMAGE))))
    (UNLOAD-MODULE (CAR (UCODE-IMAGE-MODULE-LOADED IMAGE))))
  (LOAD-MODULE NIL IMAGE))

;this loses unfortunately since the compiler: frob is not defined unless the microcompiler
; is loaded.  In the mean time, various things (ie apropos, arglist) bomb out if a symbol
; is fbound to an undefined symbol.
;(DEFF ALLOCATE-MICRO-CODE-ENTRY-SLOT 'COMPILER:ALLOCATE-MICRO-CODE-ENTRY-SLOT)

;NIL as module means load all
(DEFUN LOAD-MODULE (&OPTIONAL MODULE (IMAGE CURRENT-UCODE-IMAGE))
  (PROG (TEM AS)
        (COND ((NULL MODULE)
               (DOLIST (M (REVERSE (LDIFF (UCODE-IMAGE-MODULE-POINTS IMAGE)
                                          (UCODE-IMAGE-MODULE-LOADED IMAGE))))
                 (LOAD-MODULE M IMAGE))
               (RETURN T)))
        (COND ((NOT (EQ %MICROCODE-VERSION-NUMBER
                        (UCODE-IMAGE-VERSION IMAGE)))
               (FERROR NIL "WRONG UCODE VERSION, MACHINE ~S, IMAGE ~S"
                       %MICROCODE-VERSION-NUMBER (UCODE-IMAGE-VERSION IMAGE))))
        (SETQ AS (UCODE-MODULE-ASSEMBLER-STATE MODULE))
        (LET ((ARRAY (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE))
              (RANGE-LIST (GET-FROM-ALTERNATING-LIST AS 'I-MEMORY-RANGE-LIST)))
          (DOLIST (R RANGE-LIST)
            (DO ((ADR (CAR R) (1+ ADR))
                 (CNT (CADR R) (1- CNT)))
                ((<= CNT 0))
              (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
                     (SI:%WRITE-INTERNAL-PROCESSOR-MEMORIES
                       1 ADR
                       (%LOGDPB (LDB 4020 TEM) 1020 (LDB 3010 TEM))     ;ASSURE NO BIGNUMS, AND
                       (%LOGDPB (LDB 1020 TEM) 1020 (LDB 0010 TEM))))))))       ;SIGN BIT LOSSAGE
        (LET ((ARRAY (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY IMAGE))
              (RANGE-LIST (GET-FROM-ALTERNATING-LIST AS 'D-MEMORY-RANGE-LIST)))
          (DOLIST (R RANGE-LIST)
            (DO ((ADR (CAR R) (1+ ADR))
                 (CNT (CADR R) (1- CNT)))
                ((<= CNT 0))
              (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
                     ;; Must write correct parity
                     (SI:%WRITE-INTERNAL-PROCESSOR-MEMORIES
                       2 ADR                    ;D
                       0                        ;No high bits
                       (DPB (DO ((COUNT 17. (1- COUNT))
                                 (X TEM (LOGXOR TEM (LSH X -1))))
                                ((= COUNT 0)
                                 (LOGXOR 1 X))) ;ODD PARITY
                            2101
                            TEM)))))))
        (LET ((ARRAY (UCODE-IMAGE-A-MEMORY-ARRAY IMAGE))
              (RANGE-LIST (GET-FROM-ALTERNATING-LIST AS 'A-MEMORY-RANGE-LIST)))
          (DOLIST (R RANGE-LIST)
            (DO ((ADR (CAR R) (1+ ADR))
                 (CNT (CADR R) (1- CNT))
                 (IN-IMAGE (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE IMAGE)))
                ((<= CNT 0))
              (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
                     (AS-1 1 IN-IMAGE ADR)
                     (SI:%WRITE-INTERNAL-PROCESSOR-MEMORIES
                       4 ADR                    ;A/M
                       (%LOGDPB (LDB 4020 TEM) 1020 (LDB 3010 TEM))
                       (%LOGDPB (LDB 1020 TEM) 1020 (LDB 0010 TEM))))))))
        (DOLIST (E (GET-FROM-ALTERNATING-LIST AS 'MICRO-ENTRIES))
          (LET ((IDX (COND ((EQ (CAR E) 'MISC-INST-ENTRY)
                            (- (GET (CADR E) 'QLVAL)
                               200))
                           (T (FERROR NIL "Unknown micro-entry ~s" E)))))
            (AS-1 (CADDR E) (FUNCTION SYSTEM:MICRO-CODE-SYMBOL-AREA) IDX)
            ;; Don't mark any of micro-code-symbol-area as used!
            ;; It is "free" as far as saving a LOD band is concerned;
            ;; the data comes from the MCR band.
;      (SI:MARK-NOT-FREE (AP-1 #'SYS:MICRO-CODE-SYMBOL-AREA IDX))
            (AS-1 (CADDR E) (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) IDX)))
        (COND (NUMBER-MICRO-ENTRIES             ;in case machine has been warm booted.
               (SETQ SYSTEM:%NUMBER-OF-MICRO-ENTRIES NUMBER-MICRO-ENTRIES)))
        (DOLIST (X (UCODE-MODULE-DEFMICS MODULE))
          (APPLY (FUNCTION UA-LOAD-DEFMIC) X))
        (DO ((L (UCODE-IMAGE-MODULE-POINTS IMAGE) (CDR L))
             (C (UCODE-IMAGE-MODULE-LOADED IMAGE)))
            ((OR (NULL L) (EQ (CDR L) C))
             (COND ((AND L (EQ (CAR L) MODULE))
                    (SETF (UCODE-IMAGE-MODULE-LOADED IMAGE) L)))))
        ))

;Load into the other machine with LAM.
(DEFUN LAM-LOAD-MODULE (&OPTIONAL MODULE (IMAGE LAM-UCODE-IMAGE))
 (PROG (TEM AS)
       (COND ((NULL MODULE)
              (DOLIST (M (REVERSE (LDIFF (UCODE-IMAGE-MODULE-POINTS IMAGE)
                                         (UCODE-IMAGE-MODULE-LOADED IMAGE))))
                (LAM-LOAD-MODULE M IMAGE))
              (RETURN T)))
       (COND ((NOT (EQ %MICROCODE-VERSION-NUMBER
                       (UCODE-IMAGE-VERSION IMAGE)))
              (FERROR NIL "WRONG UCODE VERSION, MACHINE ~S, IMAGE ~S"
                      %MICROCODE-VERSION-NUMBER (UCODE-IMAGE-VERSION IMAGE))))
       (SETQ AS (UCODE-MODULE-ASSEMBLER-STATE MODULE))
  (LET ((ARRAY (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE))
        (RANGE-LIST (GET-FROM-ALTERNATING-LIST AS 'I-MEMORY-RANGE-LIST)))
    (DOLIST (R RANGE-LIST)
      (DO ((ADR (CAR R) (1+ ADR))
           (CNT (CADR R) (1- CNT)))
          ((<= CNT 0))
        (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
               (LAM-R-D (+ ADR RACMO) TEM)))))) ;SIGN BIT LOSSAGE
  (LET ((ARRAY (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY IMAGE))
        (RANGE-LIST (GET-FROM-ALTERNATING-LIST AS 'D-MEMORY-RANGE-LIST)))
    (DOLIST (R RANGE-LIST)
      (DO ((ADR (CAR R) (1+ ADR))
           (CNT (CADR R) (1- CNT)))
          ((<= CNT 0))
        (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
               (LAM-R-D (+ ADR RADMO) TEM))))))
   (LET ((ARRAY (UCODE-IMAGE-A-MEMORY-ARRAY IMAGE))
         (RANGE-LIST (GET-FROM-ALTERNATING-LIST AS 'A-MEMORY-RANGE-LIST)))
    (DOLIST (R RANGE-LIST)
      (DO ((ADR (CAR R) (1+ ADR))
           (CNT (CADR R) (1- CNT))
           (IN-IMAGE (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE IMAGE)))
          ((<= CNT 0))
        (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
               (AS-1 1 IN-IMAGE ADR)
               (LAM-R-D (+ ADR RAAMO) TEM))))))
   (DOLIST (E (GET-FROM-ALTERNATING-LIST AS 'MICRO-ENTRIES))
     (LET ((IDX (COND ((EQ (CAR E) 'MISC-INST-ENTRY)
                       (- (GET (CADR E) 'QLVAL)
                          200))
                      (T (FERROR NIL "Unknown micro-entry ~s" E)))))
;      (AS-1 (CADDR E) (FUNCTION SYSTEM:MICRO-CODE-SYMBOL-AREA) IDX)
       (AS-1 (CADDR E) (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) IDX)))
;  (DOLIST (X (UCODE-MODULE-DEFMICS MODULE))
;    (APPLY (FUNCTION UA-LOAD-DEFMIC) X))
))

(DEFUN BLAST-WITH-IMAGE (&OPTIONAL (IMAGE CURRENT-UCODE-IMAGE) &AUX TEM)
  (COND ((NOT (EQ %MICROCODE-VERSION-NUMBER
                  (UCODE-IMAGE-VERSION IMAGE)))
         (FERROR NIL "WRONG UCODE VERSION, MACHINE ~S, IMAGE ~S"
                 %MICROCODE-VERSION-NUMBER (UCODE-IMAGE-VERSION IMAGE))))
  (LET ((ARRAY (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE)))
    (DO ((ADR 0 (1+ ADR))
         (LIM (ARRAY-LENGTH ARRAY)))
        ((>= ADR LIM))
      (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
             (SI:%WRITE-INTERNAL-PROCESSOR-MEMORIES 1 ADR
                    (%LOGDPB (LDB 4020 TEM) 1020 (LDB 3010 TEM))  ;ASSURE NO BIGNUMS, AND
                    (%LOGDPB (LDB 1020 TEM) 1020 (LDB 0010 TEM))))))) ;SIGN BIT LOSSAGE
  ;doesnt load RPN bits properly
  '(LET ((ARRAY (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY IMAGE)))
    (DO ((ADR 0 (1+ ADR))
         (LIM (ARRAY-LENGTH ARRAY)))
        ((>= ADR LIM))
      (COND ((NOT (NULL (SETQ TEM (AR-1 ARRAY ADR))))
             (SI:%WRITE-INTERNAL-PROCESSOR-MEMORIES 2 ADR   ;D
                    (%LOGDPB (LDB 4020 TEM) 1020 (LDB 3010 TEM))
                    (%LOGDPB (LDB 1020 TEM) 1020 (LDB 0010 TEM)))))))
;  (LET ((ARRAY (UCODE-IMAGE-A-MEMORY-ARRAY IMAGE)))
;    (DO ((ADR 0 (1+ ADR))
;        (LIM (ARRAY-LENGTH ARRAY))
;        (IN-IMAGE (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE IMAGE)))  ;HMM REALLY LOSES.
;       ((>= ADR LIM))
;      (COND ((AND (NOT (ZEROP (AR-1 IN-IMAGE ADR)))
;                 (NOT (NULL (SETQ TEM (AR-1 ARRAY ADR)))))
;            (SI:%WRITE-INTERNAL-PROCESSOR-MEMORIES 4 ADR    ;A/M
;                   (%LOGDPB (LDB 4020 TEM) 1020 (LDB 3010 TEM))
;                   (%LOGDPB (LDB 1020 TEM) 1020 (LDB 0010 TEM)))))))
  )

(DEFUN MERGE-MEM-ALIST (ALIST RA-ORG IMAGE)
  "Store the contents of ALIST into registers in IMAGE starting at address RA-ORG.
Each element of ALIST looks like (OFFSET . VALUE), and VALUE
is stored in the register at address (+ RA-ORG OFFSET)."
  (DOLIST (ELT ALIST)
    (WHEN (CDR ELT)
      (LAM-IMAGE-REGISTER-DEPOSIT IMAGE NIL (+ RA-ORG (CAR ELT)) (CDR ELT) T))))

(DEFUN MERGE-MEM-ARRAY (ARRAY RA-ORG IMAGE)
  "Store the contents of ARRAY into registers in IMAGE starting at address RA-ORG.
One element of ARRAY goes into each register."
  (PROG (IDX LIM TEM)
        (SETQ IDX 0)
        (SETQ LIM (LENGTH ARRAY))
     L  (COND ((NOT (< IDX LIM))
               (RETURN T))
              ((SETQ TEM (AREF ARRAY IDX))
               (LAM-IMAGE-REGISTER-DEPOSIT IMAGE NIL (+ RA-ORG IDX) TEM T)))
        (SETQ IDX (1+ IDX))
        (GO L)))

(DEFUN EXTRACT-MEM-ARRAY (RA-ORG LENGTH IMAGE)
  "Return an array holding the contents of LENGTH registers of IMAGE starting at addr RA-ORG."
  (DO ((ARRAY (MAKE-ARRAY LENGTH))
       (I 0 (1+ I)))
      ((= I LENGTH)
       ARRAY)
    (SETF (AREF ARRAY I)
          (LAM-IMAGE-REGISTER-EXAMINE IMAGE NIL (+ RA-ORG I)))))

;; Like READ-UCODE-VERSION, but works based on information
;passed as args (presumably stored in a QFASL file with a user module).
(DEFUN RELOAD-UCODE-VERSION (&OPTIONAL (VERSION %MICROCODE-VERSION-NUMBER)
                             (IMAGE CURRENT-UCODE-IMAGE)
                             ASSEMBLER-STATE)
  (PKG-BIND "LAMBDA"
;   (READ-SYM-FILE VERSION IMAGE)
    (SETF (UCODE-IMAGE-ASSEMBLER-STATE IMAGE)
          ASSEMBLER-STATE)
;    (READ-MCR-FILE VERSION IMAGE)
;    (READ-TABLE-FILE VERSION IMAGE)
    (SETF (UCODE-IMAGE-VERSION IMAGE) VERSION)
    (LET ((MODULE (MAKE-UCODE-MODULE)))
      (SETF (UCODE-MODULE-IMAGE MODULE) IMAGE)
      (SETF (UCODE-MODULE-SOURCE MODULE)
            ;; Fake what directory this came from
            (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR LISP >") ':NEW-VERSION VERSION))
      (SETF (UCODE-MODULE-ASSEMBLER-STATE MODULE)
            (UCODE-IMAGE-ASSEMBLER-STATE IMAGE))
      (SETF (UCODE-MODULE-ENTRY-POINTS-INDEX MODULE)
            (ARRAY-LEADER (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) 0))
      (SETF (UCODE-MODULE-TABLE MODULE)
            (UCODE-IMAGE-TABLE-LOADED IMAGE))
      (SETF (UCODE-MODULE-SYM-ADR MODULE)
            (ARRAY-LEADER (UCODE-IMAGE-SYMBOL-ARRAY IMAGE) 0))
      (SETF (UCODE-IMAGE-MODULE-LOADED IMAGE)
            (SETF (UCODE-IMAGE-MODULE-POINTS IMAGE) (LIST MODULE))))
    ))

(DEFUN READ-UCODE-VERSION (&OPTIONAL (VERSION %MICROCODE-VERSION-NUMBER)
                           (IMAGE CURRENT-UCODE-IMAGE))
  (PKG-BIND "LAMBDA"
    (COND ((NULL (BOUNDP 'RACMO))
           (READFILE "SYS: LAMBDA-DIAG; LAMREG LISP >")))
;   (READ-SYM-FILE VERSION IMAGE)
    (UCODE-IMAGE-STORE-ASSEMBLER-STATE (GET-UCADR-STATE-LIST VERSION) IMAGE)
;    (READ-MCR-FILE VERSION IMAGE)
;    (READ-TABLE-FILE VERSION IMAGE)
    (SETF (UCODE-IMAGE-VERSION IMAGE) VERSION)
    (LET ((MODULE (MAKE-UCODE-MODULE)))
      (SETF (UCODE-MODULE-IMAGE MODULE) IMAGE)
      (SETF (UCODE-MODULE-SOURCE MODULE)
            ;; Fake what directory this came from
            (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR LISP >") ':NEW-VERSION VERSION))
      (SETF (UCODE-MODULE-ASSEMBLER-STATE MODULE)
            (UCODE-IMAGE-ASSEMBLER-STATE IMAGE))
      (SETF (UCODE-MODULE-ENTRY-POINTS-INDEX MODULE)
            (ARRAY-LEADER (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE) 0))
      (SETF (UCODE-MODULE-TABLE MODULE)
            (UCODE-IMAGE-TABLE-LOADED IMAGE))
      (SETF (UCODE-MODULE-SYM-ADR MODULE)
            (ARRAY-LEADER (UCODE-IMAGE-SYMBOL-ARRAY IMAGE) 0))
      (SETF (UCODE-IMAGE-MODULE-LOADED IMAGE)
            (SETF (UCODE-IMAGE-MODULE-POINTS IMAGE) (LIST MODULE))))
    ))

(DEFUN READ-TABLE-FILE (VERSION &OPTIONAL (IMAGE CURRENT-UCODE-IMAGE))
  (WITH-OPEN-FILE (STREAM (IF (NUMBERP VERSION)
                              (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR")
                                       ':NEW-TYPE-AND-VERSION "TBL" VERSION)
                              VERSION)
                          '(:READ))
    (READ STREAM)                       ;Flush (SETQ MICROCODE-ERROR-TABLE-VERSION-NUMBER ..)
    (LET ((TABLE (READ STREAM)))        ;Gobble (SETQ MICROCODE-ERROR-TABLE '(...))
      (SETF (UCODE-IMAGE-TABLE-LOADED IMAGE)
            (CADR (CADDR TABLE))))))    ;Flush SETQ, QUOTE, etc.

(DEFUN GET-UCADR-STATE-LIST (&OPTIONAL (VERSION %MICROCODE-VERSION-NUMBER))
  (WITH-OPEN-FILE (STREAM (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR")
                                   ':NEW-TYPE-AND-VERSION "SYM" VERSION)
                          '(:READ))
    (DO ((ITEM)) (NIL)
      (SETQ ITEM (READ STREAM))
      (AND (< ITEM 0)
           (SELECTQ ITEM
             ((-1 -2) (RETURN NIL))
             (-4 (RETURN (READ STREAM)))
             (OTHERWISE (FERROR NIL "~O is not a valid block header" ITEM)))))))

;Dont do this by default any more
(DEFUN READ-SYM-FILE (VERSION &OPTIONAL (IMAGE CURRENT-UCODE-IMAGE))
  (PROG (STREAM ITEM SYM TYPE VAL SYM-ARRAY FILENAME)
        (SETQ FILENAME (COND ((NUMBERP VERSION)
                              (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR")
                                       ':NEW-TYPE-AND-VERSION "SYM" VERSION))
                             (T VERSION)))
        (SETQ STREAM (OPEN FILENAME '(:READ)))
  COM0  (COND ((NOT (< (SETQ ITEM (READ-SIGNED-OCTAL-FIXNUM STREAM)) 0))
               (GO COM0)))
  COM   (COND ((= ITEM -1) (GO FIN))
              ((= ITEM -2) (GO SYMLOD))
              ((= ITEM -4)
               (UCODE-IMAGE-STORE-ASSEMBLER-STATE (READ STREAM) IMAGE)
               (GO COM0))
              (T (FERROR NIL "~O is not a valid block header" ITEM)))
  FIN   (CLOSE STREAM)
        (RETURN IMAGE)
 SYMLOD (SETQ SYM-ARRAY (UCODE-IMAGE-SYMBOL-ARRAY IMAGE))
        (STORE-ARRAY-LEADER 0 SYM-ARRAY 0)
 SYML1  (SETQ SYM (READ STREAM))
        (COND ((AND (NUMBERP SYM)
                    (< SYM 0))
               (SETQ ITEM SYM)
               (GO COM)))
        (SETQ TYPE (READ STREAM) VAL (READ STREAM))
        (ARRAY-PUSH-EXTEND SYM-ARRAY SYM 1000)
        (ARRAY-PUSH-EXTEND SYM-ARRAY TYPE 1000)
        (ARRAY-PUSH-EXTEND SYM-ARRAY VAL 1000)
        (GO SYML1)
))

(DEFUN UA-DEFINE-SYMS (&OPTIONAL (IMAGE CURRENT-UCODE-IMAGE))
;CAUSE SYMBOLS TO EXIST. TEMPORARILY CONS-LAP-SYM.
  (LET ((SYM-ARRAY (UCODE-IMAGE-SYMBOL-ARRAY IMAGE)))
    (COND (T
         ; (NULL (GET (AR-1 SYM-ARRAY 0) 'CONS-LAP-SYM)) ;SAVE TIME IF IT LOOKS LIKE ITS THERE
           (DO ((ADR 0 (+ ADR 3))
                (LIM (ARRAY-ACTIVE-LENGTH SYM-ARRAY)))
               ((>= ADR LIM))
             (LET ((SYM (AR-1 SYM-ARRAY ADR))
                   (TYPE (AR-1 SYM-ARRAY (1+ ADR)))
                   (VAL (AR-1 SYM-ARRAY (+ 2 ADR))))
               (PUTPROP SYM
                        (COND ((EQ TYPE 'NUMBER)
                               VAL)
                              (T
                               (LIST TYPE
                                (CONS 'FIELD
                                  (COND ((EQ TYPE 'I-MEM)
                                         (LIST 'JUMP-ADDRESS-MULTIPLIER VAL))
                                        ((EQ TYPE 'A-MEM)
                                         (LIST 'A-SOURCE-MULTIPLIER VAL))
                                        ((EQ TYPE 'M-MEM)
                                         (LIST 'M-SOURCE-MULTIPLIER VAL))
                                        ((EQ TYPE 'D-MEM)
                                         (LIST 'DISPATCH-ADDRESS-MULTIPLIER VAL))
                                        (T (FERROR NIL
"~%The symbol ~S has bad type ~S. Its value is ~S" SYM TYPE VAL)) )))))
                        'CONS-LAP-SYM)))))))

(DEFUN READ-MCR-FILE (VERSION &OPTIONAL (IMAGE CURRENT-UCODE-IMAGE))
  (PROG (STREAM HCODE LCODE HADR LADR HCOUNT LCOUNT HD LD FILENAME
                UDSP-NBLKS UDSP-RELBLK VERSION-NUMBER)
        (COND ((NOT (NUMBERP VERSION))
               (FORMAT T "~& Please type microcode version number (decimal): ")
               (SETQ VERSION (LET ((IBASE 10.)) (READ)))))
        (SETQ VERSION-NUMBER VERSION
              FILENAME (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR")
                                ':NEW-TYPE-AND-VERSION "MCR" VERSION))
        (SETF (UCODE-IMAGE-VERSION IMAGE) VERSION-NUMBER)
        (SETQ STREAM (OPEN FILENAME '(:IN :BLOCK :FIXNUM :BYTE-SIZE 16. )))
    L0  (SETQ HCODE (FUNCALL STREAM ':TYI) LCODE (FUNCALL STREAM ':TYI))
        (COND ((OR (NOT (ZEROP HCODE)) (< LCODE 0) (> LCODE 5))
               (FERROR NIL "BAD CODE HCODE=~O LCODE=~O" HCODE LCODE)))
        (SETQ HADR (FUNCALL STREAM ':TYI) LADR (FUNCALL STREAM ':TYI))
        (SETQ HCOUNT (FUNCALL STREAM ':TYI) LCOUNT (FUNCALL STREAM ':TYI))
        (COND ((OR (NOT (ZEROP HADR))
                   (NOT (ZEROP HCOUNT)))
               (FERROR NIL "BAD HEADER SA ~O,~O COUNT ~O,~O"
                       HADR LADR HCOUNT LCOUNT)))
        (COND ((ZEROP LCODE)
               (COND (UDSP-NBLKS
                      (FUNCALL STREAM ':SET-POINTER (* 2 UDSP-RELBLK SI:PAGE-SIZE))
                      (DO ((UE-ARRAY (UCODE-IMAGE-ENTRY-POINTS-ARRAY IMAGE))
                           (ADR 0 (1+ ADR))
                           (FIN (* UDSP-NBLKS SI:PAGE-SIZE)))
                          ((= ADR FIN))
                        (AS-1 (DPB (FUNCALL STREAM ':TYI)
                                   2020
                                   (DPB (FUNCALL STREAM ':TYI)
                                        0020
                                        0))
                              UE-ARRAY
                              ADR))))
               (CLOSE STREAM)
               (RETURN IMAGE))
              ((= LCODE 1) (GO LI))     ;I-MEM
              ((= LCODE 2) (GO LD))     ;D-MEM
              ((= LCODE 3) ;IGNORE MAIN MEMORY LOAD
               (SETQ UDSP-NBLKS LADR)
               (SETQ UDSP-RELBLK LCOUNT)
               (SETQ HD (FUNCALL STREAM ':TYI) LD (FUNCALL STREAM ':TYI)) ;PHYS MEM ADR
               (GO L0))
              ((= LCODE 4) (GO LA)))    ;A-MEM
   LD   (COND ((< (SETQ LCOUNT (1- LCOUNT)) 0)
               (GO L0)))
        (AS-1 (DPB (FUNCALL STREAM ':TYI) 1020
                   (DPB (FUNCALL STREAM ':TYI) 0020 0))
              (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY IMAGE)
              LADR)
        (SETQ LADR (1+ LADR))
        (GO LD)
  LA    (COND ((< (SETQ LCOUNT (1- LCOUNT)) 0)
               (GO L0)))
        (AS-1 (DPB (FUNCALL STREAM ':TYI) 2020
                   (DPB (FUNCALL STREAM ':TYI) 0020 0))
              (UCODE-IMAGE-A-MEMORY-ARRAY IMAGE)
              LADR)
        (AS-1 1 (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE IMAGE) LADR)
        (SETQ LADR (1+ LADR))
        (GO LA)
  LI    (COND ((< (SETQ LCOUNT (1- LCOUNT)) 0)
               (GO L0)))
        (AS-1 (DPB (FUNCALL STREAM ':TYI) 6020
                   (DPB (FUNCALL STREAM ':TYI) 4020
                        (DPB (FUNCALL STREAM ':TYI) 2020
                             (DPB (FUNCALL STREAM ':TYI) 0020 0))))
              (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE)
              LADR)
        (SETQ LADR (1+ LADR))
        (GO LI)
))

;---
; FOLLOWING CODE ADOPTED FROM LAM.  EVENTUALLY, IT WOULD BE NICE FOR LAM
;TO BE ABLE TO OPERATE INTERCHANGABLY ON EITHER A UCODE-IMAGE, UCODE-STATE
;IN THE HOME MACHINE, OR ON A REMOTE MACHINE VIA THE DEBUGGING INTERFACE.
;DUE TO LACK OF BIGNUMS AND LOTS OF REASONS, WE RE NOT REALLY TRYING TO
;ACCOMPLISH THIS NOW.  HOWEVER, WE ARE TRYING TO KEEP THE STRUCTURE OF THINGS
;AS MUCH LAM LIKE AS POSSIBLE TO SIMPLIFY DOING THIS IN THE FUTURE.

(DEFUN LAM-IMAGE-PRINT-REG-ADR-CONTENTS (IMAGE STATE ADR)
 (PROG (DATA)
;       (SETQ RANGE (LAM-IMAGE-FIND-REG-ADR-RANGE ADR))
        (SETQ DATA (LAM-IMAGE-REGISTER-EXAMINE IMAGE STATE ADR))
;       (COND ((MEMQ RANGE '(C CIB))
;               (LAM-TYPE-OUT DATA LAM-UINST-DESC T))
;             ((MEMQ RANGE '(U OPC))
;               (LAM-IMAGE-PRINT-ADDRESS (+ DATA RACMO))
;               (PRINC '/ ))
;             ((EQ RANGE 'RAIDR)
;               (LAM-IMAGE-PRINT-ADDRESS DATA) (PRINC '/ ))
;             (T (PRIN1-THEN-SPACE DATA)))
        (PRIN1-THEN-SPACE DATA)
        (PRINC '/ / )))

(DEFUN LAM-IMAGE-REGISTER-EXAMINE (IMAGE STATE ADR)
  (MULTIPLE-VALUE-BIND (RANGE IDX) (LAM-IMAGE-FIND-REG-ADR-RANGE ADR)
    (COND ((EQ RANGE 'C)
           (AR-1 (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE)
                 IDX))
          ((EQ RANGE 'D)
           (AR-1 (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY IMAGE)
                 IDX))
          ((EQ RANGE 'P)
           (AR-1 (UCODE-STATE-PDL-BUFFER-ARRAY STATE)
                 IDX))
          ((EQ RANGE '/1)
           (AR-1 (UCODE-STATE-LEVEL-1-MAP STATE)
                 IDX))
          ((EQ RANGE '/2)
           (AR-1 (UCODE-STATE-LEVEL-2-MAP STATE)
                 IDX))
          ((EQ RANGE 'A)
           (COND ((ZEROP (AR-1 (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE
                                 IMAGE)
                               IDX))
                  (AREF (UCODE-IMAGE-A-MEMORY-ARRAY IMAGE) IDX))
                 (STATE (AREF (UCODE-STATE-A-MEMORY-ARRAY STATE) IDX))))
          ((EQ RANGE 'U)
           (AR-1 (UCODE-STATE-MICRO-STACK-ARRAY STATE)
                 IDX))
          (T (FERROR NIL "~S is not a valid range for ~O" RANGE ADR))) ))

(DEFUN LAM-IMAGE-REGISTER-DEPOSIT (IMAGE STATE ADR DATA &OPTIONAL IMAGE-FLAG)
  (MULTIPLE-VALUE-BIND (RANGE IDX) (LAM-IMAGE-FIND-REG-ADR-RANGE ADR)
    (COND ((EQ RANGE 'C)
           (AS-1 DATA (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE) IDX))
          ((EQ RANGE 'D)
           (AS-1 DATA (UCODE-IMAGE-DISPATCH-MEMORY-ARRAY IMAGE) IDX))
          ((EQ RANGE 'P)
           (AS-1 DATA (UCODE-STATE-PDL-BUFFER-ARRAY STATE) IDX))
          ((EQ RANGE '/1)
           (AS-1 DATA (UCODE-STATE-LEVEL-1-MAP STATE) IDX))
          ((EQ RANGE '/2)
           (AS-1 DATA (UCODE-STATE-LEVEL-2-MAP STATE) IDX))
          ((EQ RANGE 'A)
           (AS-1 (COND (IMAGE-FLAG 0)
                       (T 1))
                 (UCODE-IMAGE-A-MEMORY-LOCATION-IN-IMAGE IMAGE)
                 IDX)
           (AS-1 DATA (COND (IMAGE-FLAG (UCODE-IMAGE-A-MEMORY-ARRAY IMAGE))
                            (T (UCODE-STATE-A-MEMORY-ARRAY STATE)))
                 IDX))
          ((EQ RANGE 'U)
           (AS-1 DATA (UCODE-STATE-MICRO-STACK-ARRAY STATE) IDX))
          (T (FERROR NIL "~S is not a valid range for ~O" RANGE ADR))) ))

;RETURNS SYMBOL TYPE AND VALUE OR NIL, NOT ASSQ LIST ELEMENT AS IN LAM.
(DEFUN LAM-IMAGE-EVAL-SYM (IMAGE SYM)
  (PROG (SYMTAB IDX LIM)
        (SETQ SYMTAB (UCODE-IMAGE-SYMBOL-ARRAY IMAGE))
        (SETQ IDX 0 LIM (ARRAY-LEADER SYMTAB 0))
   L    (COND ((NOT (< IDX LIM)) (RETURN NIL))
              ((EQ SYM (AR-1 SYMTAB IDX))
               (RETURN (AR-1 SYMTAB (1+ IDX)) (AR-1 SYMTAB (+ IDX 2)))))
        (SETQ IDX (+ IDX 3))
        (GO L)))

;RETURNS:  NIL IF NONE FOUND CLOSER THAN 20 TO DESIRED REG ADR
;          SYMBOL  IF EXACT MATCH FOUND
;          (LIST SYMBOL DIFFERENCE)  IF ONE FOUND CLOSER THAN 20

;****
(DEFUN LAM-IMAGE-FIND-CLOSEST-SYM (IMAGE REG-ADR)
  (PROG (BSF BSF-VAL VAL SYMTAB IDX LIM)
        (SETQ BSF-VAL 0)
        (SETQ SYMTAB (UCODE-IMAGE-SYMBOL-ARRAY IMAGE))
        (SETQ IDX 0 LIM (ARRAY-LEADER SYMTAB 0))
   L    (COND ((NOT (< IDX LIM)) (GO X))
              ((= REG-ADR (SETQ VAL (AR-1 SYMTAB (1+ IDX))))
                (RETURN (AR-1 SYMTAB IDX)))
              ((AND (> VAL BSF-VAL)
                    (< VAL REG-ADR))
                (SETQ BSF (AR-1 SYMTAB IDX))
                (SETQ BSF-VAL VAL)))
        (SETQ IDX (+ IDX 3))
        (GO L)
  X     (COND ((OR (NULL BSF)
                   (> (- REG-ADR BSF-VAL) 20))
                 (RETURN NIL))
              (T (RETURN (LIST BSF (- REG-ADR BSF-VAL)))))
))

(DEFUN LAM-IMAGE-FIND-REG-ADR-RANGE (REG-ADR)
  (PROG NIL
        (COND ((< REG-ADR RACMO) (RETURN 'TOO-LOW 0))
              ((< REG-ADR RACME) (RETURN 'C (- REG-ADR RACMO)))
              ((< REG-ADR RADME) (RETURN 'D (- REG-ADR RACME)))
              ((< REG-ADR RAPBE) (RETURN 'P (- REG-ADR RADME)))
              ((< REG-ADR RAM1E) (RETURN '/1 (- REG-ADR RAPBE)))
              ((< REG-ADR RAM2E) (RETURN '/2 (- REG-ADR RAM1E)))
              ((< REG-ADR RAAME) (RETURN 'A (- REG-ADR RAM2E)))
              ((< REG-ADR RAUSE) (RETURN 'U (- REG-ADR RAAME)))
              ((< REG-ADR RAMME) (RETURN 'A (- REG-ADR RAUSE))) ;M-MEM
              (T (RETURN 'TOO-HIGH 0)))
;             ((< REG-ADR RAFSE) 'FS)
;             ((< REG-ADR RAFDE) 'FD)
;             ((< REG-ADR RARGE) 'LAM)
;             ((< REG-ADR RACSWE) 'CSW)
;             ((< REG-ADR RARDRE) 'RAIDR)
;             ((< REG-ADR RACIBE) 'CIB)
;             ((< REG-ADR RAOPCE) 'OPC)
;             ((< REG-ADR LAM-REG-ADR-PHYS-MEM-OFFSET) 'TOO-HIGH)
;             ((< REG-ADR LAM-REG-ADR-VIRT-MEM-OFFSET) 'PHYSICAL)
;             (T 'VIRTUAL)
))

(DEFPROP C RACMO LAM-LOWEST-ADR)
(DEFPROP D RADMO LAM-LOWEST-ADR)
(DEFPROP P RAPBO LAM-LOWEST-ADR)
(DEFPROP /1 RAM1O LAM-LOWEST-ADR)
(DEFPROP /2 RAM2O LAM-LOWEST-ADR)
(DEFPROP A RAAMO LAM-LOWEST-ADR)
(DEFPROP U RAUSO LAM-LOWEST-ADR)
(DEFPROP M RAMMO LAM-LOWEST-ADR)
;(DEFPROP FS RAFSO LAM-LOWEST-ADR)
;(DEFPROP FD RAFDO LAM-LOWEST-ADR)
;(DEFPROP LAM RARGO LAM-LOWEST-ADR)
;(DEFPROP CSW RACSWO LAM-LOWEST-ADR)
;(DEFPROP RAIDR RARDRO LAM-LOWEST-ADR)
;(DEFPROP CIB RACIBO LAM-LOWEST-ADR)
;(DEFPROP OPC RAOPCO LAM-LOWEST-ADR)

(DEFPROP C C LAM-@-NAME)
(DEFPROP D D LAM-@-NAME)
(DEFPROP P P LAM-@-NAME)
(DEFPROP /1 1 LAM-@-NAME)
(DEFPROP /2 2 LAM-@-NAME)
(DEFPROP A A LAM-@-NAME)
(DEFPROP U U LAM-@-NAME)

(DEFUN LAM-IMAGE-PRINT-ADDRESS (IMAGE REG-ADR)
  (PROG (RANGE-NAME RANGE-BASE @-NAME TEM)
        (SETQ RANGE-NAME (LAM-IMAGE-FIND-REG-ADR-RANGE REG-ADR))
        (COND ((AND (SETQ TEM (LAM-IMAGE-FIND-CLOSEST-SYM IMAGE REG-ADR))
                    (OR (ATOM TEM)
                        (EQ RANGE-NAME 'C)
                        (EQ RANGE-NAME 'D)))
                (PRIN1 TEM))
              ((SETQ RANGE-BASE (GET RANGE-NAME 'LAM-LOWEST-ADR))
                (COND ((SETQ @-NAME (GET RANGE-NAME 'LAM-@-NAME))
                        (PRIN1 (- REG-ADR (SYMEVAL RANGE-BASE)))
                        (PRINC '@)
                        (PRIN1 @-NAME))
                      (T (PRIN1 RANGE-NAME)
                         (PRINC '/ )
                         (PRIN1 (- REG-ADR (SYMEVAL RANGE-BASE))))))
              (T (PRIN1 REG-ADR)))
     X  (RETURN T)
))

(DEFUN PREPARE-FOR-UINST-COUNTING NIL
  (READ-MCR-FILE %MICROCODE-VERSION-NUMBER)
  (READ-SYM-FILE %MICROCODE-VERSION-NUMBER))

;Set statistics bit for uinsts in given ranges.  A range is a list (<start> <end>).
;  Each of these can be
;    a number which is a C-MEM address,
;    a symbol which is defined in UCADR,
;    a list of a symbol and a number, which in N instructions after SYMBOL.
;  Also, in <end> the special symbol * has the value of <start>.

(DEFUN MARK-UINST-RANGES (RANGES &OPTIONAL (IMAGE CURRENT-UCODE-IMAGE))
  (LET* ((ARRAY (UCODE-IMAGE-CONTROL-MEMORY-ARRAY IMAGE))
         (LIM (ARRAY-LENGTH ARRAY)))
    (DO ADR 0 (1+ ADR) (>= ADR LIM)
        (LET ((VAL (AREF ARRAY ADR)))
          (IF VAL (SETF (AREF ARRAY ADR) (BOOLE 2 1_46. VAL)))))        ;clear bits
    (DOLIST (RANGE RANGES)
      (LET* ((START (MARK-UINST-EVAL IMAGE (CAR RANGE)))
             (END (MARK-UINST-EVAL IMAGE (CADR RANGE) START)))
        (DO ADR START (1+ ADR) (>= ADR END)
            (LET ((VAL (AREF ARRAY ADR)))
              (IF VAL (SETF (AREF ARRAY ADR) (LOGIOR 1_46. VAL)))))))
    (BLAST-WITH-IMAGE)
    NIL))

(DEFCONST PAGE-FAULT-RANGES '( (PGF-R XCPGS)))

  ; 21% (process-sleep 60.)
  ; 7.7% (who-uses 'foobarbletch "si")
  ; 2.9% (apropos "foobarbletch" "si")
  ; 36.2 (worst-case-test)
(DEFCONST FIRST-LEVEL-MAP-RELOAD-RANGES
          '( (LEVEL-1-MAP-MISS ADVANCE-SECOND-LEVEL-MAP-REUSE-POINTER)))

  ; 42% (process-sleep 60.)
  ; 17.2% (who-uses 'foobarbletch "si")
  ; 7.9% (apropos "foobarbletch" "si")
  ; 57.5 (worst-case-test)
  ; 17.2 (compile 'add-assembly)
(DEFCONST ALL-MAP-FAULT-EXCEPT-DISK-WAIT-RANGES '(
  ;attempts to measure map reloads for stuff in core
  (PGF-R-SB SBSER)
  (PGF-R-I PGF-R-PDL)                   ;do not include PDL-BUFFER-FAULTS
  (PGF-SAVE LEVEL-1-MAP-MISS)
  (LEVEL-1-MAP-MISS PGF-MAP-MISS)
  (PGF-MAP-MISS PGF-MAR)                ;not MAR, A-MEM faults, MPV, WR-RDONLY, PGF-RWF
  (PGF-RL SEARCH-PAGE-HASH-TABLE)
  (SEARCH-PAGE-HASH-TABLE XCPH)         ;not %COMPUTE-PAGE-HASH
  (COMPUTE-PAGE-HASH SWAPIN)))



  ; 4.3% (process-sleep 60.)
  ; 2.1% (who-uses 'foobarbletch" "si")
  ; 1.4% (apropos "foobarbletch" "si")
  ; 7.7% (worst-case-test)
  ; 2.4% (compile 'add-assembly)
(DEFCONST SEARCH-PAGE-HASH-RANGE '( (SEARCH-PAGE-HASH-TABLE XCPH)
                                   (COMPUTE-PAGE-HASH SWAPIN)))

(DEFCONST ALL-MICROCODE-RANGE `( (0 ,SI:SIZE-OF-HARDWARE-CONTROL-MEMORY)))


(DEFUN MARK-UINST-EVAL (IMAGE SPEC &OPTIONAL START-VALUE)
  (COND ((NUMBERP SPEC) SPEC)
        ((SYMBOLP SPEC)
         (IF (EQ SPEC '*)
             START-VALUE
             (MULTIPLE-VALUE-BIND (TYPE VAL)
                 (LAM-IMAGE-EVAL-SYM IMAGE SPEC)
               (IF (NOT (EQ TYPE 'I-MEM))
                   (FERROR NIL "wrong type")
                   VAL))))
        (T (+ (MARK-UINST-EVAL (CAR SPEC) START-VALUE) (CADR SPEC)))))

;(DEFUN READ-STATISTICS-COUNTER ()
;  (DPB (%UNIBUS-READ 766036) 2020 (%UNIBUS-READ 766034)))

(DEFUN USTAT (SECS)
  (LET ((TEM (READ-STATISTICS-COUNTER)))
    (PROCESS-SLEEP SECS)
    (FORMAT T "~%~D" (- (READ-STATISTICS-COUNTER) TEM))))

(DEFMACRO USTAT-MACRO (&body BODY)
  `(PROGN
     (PRINT ',BODY)
     (WRITE-METER 'SYS:%DISK-WAIT-TIME 0)
     (WRITE-METER 'SYS:%COUNT-SECOND-LEVEL-MAP-RELOADS 0)
     (WRITE-METER 'SYS:%COUNT-FIRST-LEVEL-MAP-RELOADS 0)
     (LET ((TEMP2 (READ-STATISTICS-COUNTER))
           (TEMP1 (TIME:MICROSECOND-TIME))
           (TIME-DIFF 0)
           (STAT-DIFF 0)
           (DISK-DIFF 0))
       ,@BODY
       (SETQ STAT-DIFF (- (READ-STATISTICS-COUNTER) TEMP2))
       (SETQ TIME-DIFF (- (TIME:MICROSECOND-TIME) TEMP1))
       (SETQ DISK-DIFF (READ-METER 'SYS:%DISK-WAIT-TIME))
       (FORMAT T "~%Map faults, first ~D, second ~D"
               (READ-METER 'SYS:%COUNT-FIRST-LEVEL-MAP-RELOADS)
               (READ-METER 'SYS:%COUNT-SECOND-LEVEL-MAP-RELOADS))
       (FORMAT T "~% elapsed time: ~D-~D microseconds~%ticks: ~D~%guesstimate (4MuIPS): ~F%~%"
               TIME-DIFF
               DISK-DIFF
               STAT-DIFF
               (* 100.0 (//$ (FLOAT STAT-DIFF)
                             (*$ 4.0 (- (FLOAT TIME-DIFF) (FLOAT DISK-DIFF))))))
       )))



(DEFUN WORST-CASE-TEST (LIM)
  (declare (SPECIAL WC-SECOND-LEVEL))
  (IF (NOT (BOUNDP 'WC-SECOND-LEVEL))
      (PROGN (SETQ WC-SECOND-LEVEL (make-array 32.))
             (DO ((J 0 (1+ J))) ((>= J 32.))
               (SETF (AREF WC-SECOND-LEVEL J) (*ARRAY NIL 'FIXNUM 8192.)))))
  (USTAT-MACRO
    (SETQ LIM (TRUNCATE LIM 32.))
    (DO ((I 0 (1+ I)))
        ((> I LIM))
      (DO ((J 0 (1+ J)))
          ((>= J 32.))
        ;; cause a second level map fault
        (AREF (AREF WC-SECOND-LEVEL J) 0)
        ))))

(DEFUN UINST-TESTS NIL
  (USTAT-MACRO (PROCESS-SLEEP 60.))
  (USTAT-MACRO (WHO-USES 'FOOBARBLETCH "SI"))
  (USTAT-MACRO (APROPOS "foobarbletch" "SI"))
  (WORST-CASE-TEST 100000.))

(DEFUN UINST-OTHER-TEST NIL
  (USTAT-MACRO (COMPILE 'ADD-ASSEMBLY)))
