

(defun foo ()
  (do ((n 0 (1+ n)))
      (())
    (if (= n 20)
        (return)
      (print n))))


(defun foo ()
  (do ((n 0 (1+ n)))
      ((> n 10))
    (print n)))

P_7
   (MOVE A0 (QUOTE 0))
DO3795_13
   (ALU L-R GARBAGE A0 (QUOTE 10))
   (TEST BR-NOT-GREATER-THAN)
   (BRANCH C_17)
C_16
   (MOVE RETURN (QUOTE NIL) CH-RETURN)
C_17
   (OPEN-CALL PRINT (QUOTE 1) IGNORE (O0 A0))
B_25
   (ALU L+R+1 A1 A0 (QUOTE 0))
   (MOVE A0 A1)           ;*** ????
   (JUMP DO3795_13)

this is broken somehow??


(DEFUN TREE-EQUAL-EQ (X Y)
  (DO ((XTAIL X (CDR XTAIL))
       (YTAIL Y (CDR YTAIL)))
      (())
    (IF (ATOM XTAIL)
        (RETURN (AND (ATOM YTAIL) (EQ XTAIL YTAIL))))
    (IF (ATOM YTAIL) (RETURN NIL))
    (IF (AND (NOT (EQ (CAR XTAIL) (CAR YTAIL)))
             (NOT (TREE-EQUAL-EQ (CAR XTAIL) (CAR YTAIL))))
        (RETURN NIL))))


Simplified tree:
11239165    ((T_10 NIL C_9) ($*DEFINE 1 ^B_109 TREE-EQUAL-EQ ^P_11))   NIL
11247475     ((B_109 IGNORE_108) (C_9 0 (QUOTE T)))   NIL
11239299     ((P_11 NIL K_0 X_1 Y_2) ($Y 1 ^Y_15))   NIL
11239456      ((Y_15 NIL C_13 DO3794_3) (C_13 0 ^C_14 ^T_17))   NIL
11239415       ((C_14 NIL NIL) ($OPEN 1 ^C_107 (QUOTE #{CALL-NODE (DO3794_3 1 K_0 X_1 Y_2) 11247109})))   NIL
11247257        ((C_107)  (DO3794_3 1 K_0 X_1 Y_2))   NIL
11239540       ((T_17 NIL C_16) (C_16 0 ^DO3794_18))   NIL
11239581        ((DO3794_18 NIL K_4 XTAIL_5 YTAIL_6) ($OPEN 1 ^C_40 (QUOTE #{CALL-NODE (ATOM 1 ^C_42 XTAIL_5) 11241296})))   NIL
11241409         ((C_40)   (ATOM 1 ^C_42 XTAIL_5))   NIL
11241514          ((C_42 NIL V_41) ($CONDITIONAL 2 ^C_25 ^C_39 $TEST $TRUE? V_41))   NIL
11239908           ((C_25 NIL) ($OPEN 1 ^C_32 (QUOTE #{CALL-NODE (ATOM 1 ^C_34 YTAIL_6) 11240587})))   NIL
11240717            ((C_32)   (ATOM 1 ^C_34 YTAIL_6))   NIL
11240822             ((C_34 NIL V_33) ($CONDITIONAL 2 ^C_28 ^C_30 $TEST $TRUE? V_33))   NIL
11240080              ((C_28 NIL) ($CONDITIONAL 2 ^C_145 ^C_146 $EQ XTAIL_5 YTAIL_6))   NIL
11250473               ((C_145)  (K_0 0 (QUOTE T)))   NIL
11250510               ((C_146)  (K_0 0 (QUOTE NIL)))   NIL
11240358              ((C_30 NIL) (K_0 0 (QUOTE NIL)))   NIL
11241067           ((C_39 NIL) ($OPEN 1 ^C_49 (QUOTE #{CALL-NODE (ATOM 1 ^C_51 YTAIL_6) 11242100})))   NIL
11242213            ((C_49)   (ATOM 1 ^C_51 YTAIL_6))   NIL
11242318             ((C_51 NIL V_50) ($CONDITIONAL 2 ^C_45 ^C_48 $TEST $TRUE? V_50))   NIL
11241649              ((C_45 NIL) (K_0 0 (QUOTE NIL)))   NIL
11241871              ((C_48 NIL) (^L_136 0 ^C_59))   NIL
11249539               ((L_136 NIL C_135) ($OPEN 1 ^C_82 (QUOTE #{CALL-NODE (CAR 1 ^C_87 XTAIL_5) 11245034})))   NIL
11245147                ((C_82)   (CAR 1 ^C_87 XTAIL_5))   NIL
11245527                 ((C_87 NIL V_86) ($OPEN 1 ^C_83 (QUOTE #{CALL-NODE (CAR 1 ^C_85 YTAIL_6) 11245232})))   NIL
11245345                  ((C_83)   (CAR 1 ^C_85 YTAIL_6))   NIL
11245450                   ((C_85 NIL V_84) ($CONDITIONAL 2 C_135 ^C_62 $EQ V_86 V_84))   NIL
11243038                    ((C_62 NIL) ($OPEN 1 ^C_74 (QUOTE #{CALL-NODE (TREE-EQUAL-EQ 1 ^C_76 V_72 V_70) 11243496})))   NIL
11244143                     ((C_74)   ($OPEN 1 ^C_68 (QUOTE #{CALL-NODE (CAR 1 ^C_73 XTAIL_5) 11243555})))   NIL
11243685                      ((C_68)   (CAR 1 ^C_73 XTAIL_5))   NIL
11244065                       ((C_73 NIL V_72) ($OPEN 1 ^C_69 (QUOTE #{CALL-NODE (CAR 1 ^C_71 YTAIL_6) 11243770})))   NIL
11243883                        ((C_69)   (CAR 1 ^C_71 YTAIL_6))   NIL
11243988                         ((C_71 NIL V_70) (TREE-EQUAL-EQ 1 ^C_76 V_72 V_70))   NIL
11244248                          ((C_76 NIL V_75) ($CONDITIONAL 2 C_135 ^C_56 $TEST $TRUE? V_75))   NIL
11242509                           ((C_56 NIL) (K_0 0 (QUOTE NIL)))   NIL
11242731               ((C_59 NIL) ($OPEN 1 ^C_104 (QUOTE #{CALL-NODE (DO3794_3 1 K_4 V_102 V_100) 11246005})))   NIL
11246652                ((C_104)  ($OPEN 1 ^C_98 (QUOTE #{CALL-NODE (CDR 1 ^C_103 XTAIL_5) 11246064})))   NIL
11246194                 ((C_98)   (CDR 1 ^C_103 XTAIL_5))   NIL
11246574                  ((C_103 NIL V_102) ($OPEN 1 ^C_99 (QUOTE #{CALL-NODE (CDR 1 ^C_101 YTAIL_6) 11246279})))   NIL
11246392                   ((C_99)   (CDR 1 ^C_101 YTAIL_6))   NIL
11246497                    ((C_101 NIL V_100) (DO3794_3 1 K_4 V_102 V_100))   NIL


T_10
   (MOVE RETURN (QUOTE T) CH-RETURN)
P_11
   (MOVE A2 A0)
   (MOVE A3 A1)
DO3794_18
   (OPEN-CALL ATOM (QUOTE 1) A4 (O0 A2))
C_42
   (ALU L-R GARBAGE A4 (QUOTE NIL))
   (TEST EQUAL)
   (BRANCH C_39)
C_25
   (OPEN-CALL ATOM (QUOTE 1) A5 (O0 A3))
C_34
   (ALU L-R GARBAGE A5 (QUOTE NIL))
   (TEST EQUAL)
   (BRANCH C_30)
C_28
   (ALU L-R GARBAGE A2 A3)
   (TEST BR-NOT-EQUAL)
   (BRANCH C_146)
C_145
   (MOVE RETURN (QUOTE T) CH-RETURN)
C_146
   (MOVE RETURN (QUOTE NIL) CH-RETURN)
C_30
   (MOVE RETURN (QUOTE NIL) CH-RETURN)
C_39
   (OPEN-CALL ATOM (QUOTE 1) A5 (O0 A3))
C_51
   (ALU L-R GARBAGE A5 (QUOTE NIL))
   (TEST EQUAL)
   (BRANCH C_48)
C_45
   (MOVE RETURN (QUOTE NIL) CH-RETURN)
C_48
   (OPEN-CALL CAR (QUOTE 1) A7 (O0 A2))
C_87
   (OPEN-CALL CAR (QUOTE 1) A8 (O0 A3))
C_85
   (ALU L-R GARBAGE A7 A8)
   (TEST BR-NOT-EQUAL)
   (BRANCH C_62)
   (JUMP C_59)
C_62
   (KOPEN)
   (OPEN-CALL CAR (QUOTE 1) O0 (O0 A2))
C_73
   (OPEN-CALL CAR (QUOTE 1) O1 (O0 A3))
C_71
   (KCALL NIL TREE-EQUAL-EQ (QUOTE 2) A9)
C_76
   (ALU L-R GARBAGE A9 (QUOTE NIL))
   (TEST EQUAL)
   (BRANCH C_56)
   (JUMP C_59)
C_56
   (MOVE RETURN (QUOTE NIL) CH-RETURN)
C_59
   (OPEN-CALL CDR (QUOTE 1) A1 (O0 A2))
C_103
   (OPEN-CALL CDR (QUOTE 1) A2 (O0 A3))
C_101
   (MOVE A2 A1)
   (MOVE A3 A2)
   (JUMP DO3794_18)
