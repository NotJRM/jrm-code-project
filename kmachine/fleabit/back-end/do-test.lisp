
(defun foo (a)
  (do ((n 0 (1+ n)))
      ((> n 10))
    (print n)))

(SYNTAX/DEFINE-VARIABLE-VALUE FOO
     (SYNTAX/LAMBDA P (NIL #{Variable K -13995709} #{Variable A -13995693})
       ((SYNTAX/LABELS (#{Variable DO3624 -13995643})
                       ((SYNTAX/LAMBDA DO3624 (NIL #{Variable K -13995610} #{Variable N -13995594})
                           ((SYNTAX/IF (> #{Variable N -13995594} 10)
                                       (SYNTAX/BLOCK NIL)
                                       (SYNTAX/BLOCK ((PRINT #{Variable N -13995594})
                                                      (#{Variable DO3624 -13995643} (1+ #{Variable N -13995594}))))))))
           ((#{Variable DO3624 -13995643} 0))))))

-13994864    ((T_7 NIL C_6) ($*DEFINE 1 ^B_32 FOO ^P_8))   NIL
-13992689     ((B_32 IGNORE_31) (C_6 0 (QUOTE T)))   NIL
-13994732     ((P_8 NIL K_0 A_1) ($Y 1 ^Y_11))   NIL
-13994617      ((Y_11 NIL C_9 DO3624_2) (C_9 0 ^C_10 ^T_13))   NIL
-13994657       ((C_10 NIL NIL) ($OPEN 1 ^C_30 (QUOTE #{CALL-NODE (DO3624_2 1 K_0 (QUOTE 0)) -13992975})))   NIL
-13992865        ((C_30)  (DO3624_2 1 K_0 (QUOTE 0)))   NIL
-13994535       ((T_13 NIL C_12) (C_12 0 ^DO3624_14))   NIL
-13994496        ((DO3624_14 NIL K_3 N_4) (^P_16 1 K_3))   NIL
-13994441         ((P_16 NIL J_15) ($OPEN 1 ^C_27 (QUOTE #{CALL-NODE (> 1 ^C_29 N_4 (QUOTE 10)) -13993407})))   NIL
-13993262          ((C_27)  (> 1 ^C_29 N_4 (QUOTE 10)))   NIL
-13993159           ((C_29 NIL V_28) ($CONDITIONAL 2 ^C_17 ^C_18 $TEST $TRUE? V_28))   NIL
-13994384            ((C_17 NIL) (J_15 0 $UNDEFINED))   NIL
-13994289            ((C_18 NIL) ($OPEN 1 ^C_20 (QUOTE #{CALL-NODE (PRINT 1 ^B_26 N_4) -13994252})))   NIL
-13994123             ((C_20)  (PRINT 1 ^B_26 N_4))   NIL
-13993614              ((B_26 IGNORE_25) ($OPEN 1 ^C_24 (QUOTE #{CALL-NODE (DO3624_2 1 J_15 V_22) -13994053})))   NIL
-13993702               ((C_24)  ($OPEN 1 ^C_21 (QUOTE #{CALL-NODE (1+ 1 ^C_23 N_4) -13993995})))   NIL
-13993882                ((C_21)  (1+ 1 ^C_23 N_4))   NIL
-13993779                 ((C_23 NIL V_22) (DO3624_2 1 J_15 V_22))   NIL

-13994864    ((T_7 NIL C_6) ($*DEFINE 1 ^B_32 FOO ^P_8))   STRATEGY/HEAP
-13992689     ((B_32 IGNORE_31) (C_6 0 (QUOTE T)))   STRATEGY/OPEN
-13994732     ((P_8 NIL K_0 A_1) ($Y 1 ^Y_11))   STRATEGY/HEAP
-13994617      ((Y_11 NIL C_9 DO3624_2) (C_9 0 ^C_10 ^DO3624_14))   STRATEGY/EZCLOSE
-13994657       ((C_10 NIL NIL) ($OPEN 1 ^C_30 (QUOTE #{CALL-NODE (DO3624_2 1 K_0 (QUOTE 0)) -13992975})))   STRATEGY/OPEN
-13992865        ((C_30)  (DO3624_2 1 K_0 (QUOTE 0)))   STRATEGY/OPEN
-13994496       ((DO3624_14 NIL K_3 N_4) ($CONDITIONAL 2 ^C_17 ^C_18 $> N_4 (QUOTE 10)))   STRATEGY/EZCLOSE
-13994384        ((C_17 NIL) (K_3 0 $UNDEFINED))   STRATEGY/OPEN
-13994289        ((C_18 NIL) ($OPEN 1 ^C_20 (QUOTE #{CALL-NODE (PRINT 1 ^B_26 N_4) -13994252})))   STRATEGY/OPEN
-13994123         ((C_20)  (PRINT 1 ^B_26 N_4))   STRATEGY/OPEN
-13993614          ((B_26 IGNORE_25) ($OPEN 1 ^C_24 (QUOTE #{CALL-NODE (DO3624_2 1 K_3 V_22) -13994053})))   STRATEGY/STACK
-13993702           ((C_24)  ($1+ 1 ^C_23 N_4))   STRATEGY/OPEN
-13993779            ((C_23 NIL V_22) (DO3624_2 1 K_3 V_22))   STRATEGY/OPEN


Template for #{LAMBDA-NODE ^T_7 -13994864}
;Procedure "^T_7" (lambda ("C_6") ...)
;($*DEFINE 1 "^B_32" FOO "^P_8")
;Return from procedure ("C_6" 0 (QUOTE T))
  (MOVE RETURN (T . REP/POINTER))                 ;A=("P_8" PRINT NIL) O=(NIL NIL NIL)
  (RETURN)                                        ;A=("P_8" PRINT NIL) O=(NIL NIL NIL)
Generating:
-13994732    ((P_8 NIL K_0 A_1) ($Y 1 ^Y_11))   STRATEGY/HEAP
-13994617     ((Y_11 NIL C_9 DO3624_2) (C_9 0 ^C_10 ^DO3624_14))   STRATEGY/EZCLOSE
-13994657      ((C_10 NIL NIL) ($OPEN 1 ^C_30 (QUOTE #{CALL-NODE (DO3624_2 1 K_0 (QUOTE 0)) -13992975})))   STRATEGY/OPEN
-13992865       ((C_30)  (DO3624_2 1 K_0 (QUOTE 0)))   STRATEGY/OPEN
-13994496      ((DO3624_14 NIL K_3 N_4) ($CONDITIONAL 2 ^C_17 ^C_18 $> N_4 (QUOTE 10)))   STRATEGY/EZCLOSE
-13994384       ((C_17 NIL) (K_3 0 $UNDEFINED))   STRATEGY/OPEN
-13994289       ((C_18 NIL) ($OPEN 1 ^C_20 (QUOTE #{CALL-NODE (PRINT 1 ^B_26 N_4) -13994252})))   STRATEGY/OPEN
-13994123        ((C_20)  (PRINT 1 ^B_26 N_4))   STRATEGY/OPEN
-13993614         ((B_26 IGNORE_25) ($OPEN 1 ^C_24 (QUOTE #{CALL-NODE (DO3624_2 1 K_3 V_22) -13994053})))   STRATEGY/STACK
-13993702          ((C_24)  ($1+ 1 ^C_23 N_4))   STRATEGY/OPEN
-13993779           ((C_23 NIL V_22) (DO3624_2 1 K_3 V_22))   STRATEGY/OPEN

-13994732 "^P_8"

Template for #{LAMBDA-NODE ^P_8 -13994732}
;Procedure "^P_8" (lambda ("K_0" "A_1") ...)
;($Y 1 "^Y_11")
  (PUSH P)                                        ;A=("P_8" PRINT NIL) O=(NIL NIL NIL)
  (PUSH (TEMPLATE . #{LAMBDA-NODE ^Y_11 -13994617})) ;A=("P_8" PRINT NIL) O=(NIL NIL NIL)
;($OPEN 1 "^C_30" (QUOTE #{CALL-NODE (DO3624_2 1 K_0 (QUOTE 0)) -13992975}))
;Call known procedure ("^DO3624_14" 1 "K_0" (QUOTE 0))
  (MOVE A0 (0 . REP/POINTER))                     ;A=("P_8" PRINT NIL) O=(NIL NIL NIL)
  (JUMP ALWAYS #{LAMBDA-NODE ^DO3624_14 -13994496}) ;A=(NIL NIL NIL) O=(NIL NIL NIL)
Template for #{LAMBDA-NODE ^Y_11 -13994617}
  (ADD (GLOBAL *STACK-POINTER*) (GLOBAL *STACK-POINTER*) (CONSTANT 2)) ;A=(NIL NIL NIL) O=(NIL NIL NIL)
  (RETURN)                                        ;A=(NIL NIL NIL) O=(NIL NIL NIL)
Generating:
-13994496    ((DO3624_14 NIL K_3 N_4) ($CONDITIONAL 2 ^C_17 ^C_18 $> N_4 (QUOTE 10)))   STRATEGY/EZCLOSE
-13994384     ((C_17 NIL) (K_3 0 $UNDEFINED))   STRATEGY/OPEN
-13994289     ((C_18 NIL) ($OPEN 1 ^C_20 (QUOTE #{CALL-NODE (PRINT 1 ^B_26 N_4) -13994252})))   STRATEGY/OPEN
-13994123      ((C_20)  (PRINT 1 ^B_26 N_4))   STRATEGY/OPEN
-13993614       ((B_26 IGNORE_25) ($OPEN 1 ^C_24 (QUOTE #{CALL-NODE (DO3624_2 1 K_3 V_22) -13994053})))   STRATEGY/STACK
-13993702        ((C_24)  ($1+ 1 ^C_23 N_4))   STRATEGY/OPEN
-13993779         ((C_23 NIL V_22) (DO3624_2 1 K_3 V_22))   STRATEGY/OPEN

-13994496 "^DO3624_14"
Tag for #{LAMBDA-NODE ^DO3624_14 -13994496}
;Procedure "^DO3624_14" (lambda ("K_3" "N_4") ...)
;($CONDITIONAL 2 "^C_17" "^C_18" $> "N_4" (QUOTE 10))
  (SUB GARBAGE A10 A0)                            ;A=("!N_4" NIL NIL) O=(NIL NIL NIL)
  (JUMP GREATER-THAN #{LAMBDA-NODE ^C_18 -13994289}) ;A=("!N_4" NIL NIL) O=(NIL NIL NIL)
Tag for #{LAMBDA-NODE ^C_17 -13994384}
;Return from procedure ("K_3" 0 $UNDEFINED)
  (MOVE RETURN (CONSTANT 0))                      ;A=("N_4" NIL NIL) O=(NIL NIL NIL)
  (ADD (GLOBAL *STACK-POINTER*) (GLOBAL *STACK-POINTER*) (CONSTANT 2)) ;A=("N_4" NIL NIL) O=(NIL NIL NIL)
  (RETURN)                                        ;A=("N_4" NIL NIL) O=(NIL NIL NIL)
Tag for #{LAMBDA-NODE ^C_18 -13994289}
;($OPEN 1 "^C_20" (QUOTE #{CALL-NODE (PRINT 1 ^B_26 N_4) -13994252}))
  (OPEN *)                                        ;A=("N_4" NIL NIL) O=(NIL NIL NIL)
;Call unknown procedure (PRINT 1 "^B_26" "N_4")
  (MOVE O0 A0)                                    ;A=("N_4" NIL NIL) O=("!" NIL NIL)
  (CALL #{REFERENCE #{Variable PRINT -13994228} -13994212} (CONSTANT 1)) ;A=("N_4" NIL NIL) O=("!" NIL NIL)
Generating:
-13993614    ((B_26 IGNORE_25) ($OPEN 1 ^C_24 (QUOTE #{CALL-NODE (DO3624_2 1 K_3 V_22) -13994053})))   STRATEGY/STACK
-13993702     ((C_24)  ($1+ 1 ^C_23 N_4))   STRATEGY/OPEN
-13993779      ((C_23 NIL V_22) (DO3624_2 1 K_3 V_22))   STRATEGY/OPEN

-13993614 "^B_26"

Template for #{LAMBDA-NODE ^B_26 -13993614}
;Continuation "^B_26" (lambda "IGNORE_25" ...)
;($OPEN 1 "^C_24" (QUOTE #{CALL-NODE (DO3624_2 1 K_3 V_22) -13994053}))
;($1+ 1 "^C_23" "N_4")
  (L-R+1 A1 A0 (CONSTANT (QUOTE 0)))              ;A=("N_4" NIL NIL) O=(NIL NIL NIL)
;Call known procedure ("^DO3624_14" 1 "K_3" "V_22")
  (MOVE A0 A1)                                    ;A=("!" "V_22" NIL) O=(NIL NIL NIL)
  (JUMP ALWAYS #{LAMBDA-NODE ^DO3624_14 -13994496}) ;A=(NIL NIL NIL) O=(NIL NIL NIL)




P_8
  (PUSH P)
  (PUSH (TEMPLATE . #{LAMBDA-NODE ^Y_11 -13994617}))
  (MOVE A0 (0 . REP/POINTER))
  (JUMP ALWAYS DO3624_14)
Y_11
  (ADD (GLOBAL *STACK-POINTER*) (GLOBAL *STACK-POINTER*) (CONSTANT 2))
  (RETURN)

DO3624_14
  (SUB GARBAGE (constant 10) A0)
  (JUMP GREATER-THAN C_18)
C_17
  (MOVE RETURN (CONSTANT 0))
  (ADD (GLOBAL *STACK-POINTER*) (GLOBAL *STACK-POINTER*) (CONSTANT 2))
  (RETURN)

C_18
  (OPEN *)
  (MOVE O0 A0)
  (CALL PRINT (CONSTANT 1))

B_26
  (L-R+1 A1 A0 (CONSTANT (QUOTE 0)))
  (MOVE A0 A1)
  (JUMP ALWAYS DO3624_14)
