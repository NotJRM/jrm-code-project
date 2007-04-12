;;; -*- Mode:LISP; Package:FILE-SYSTEM; Patch-File:T; Base:10 -*-


(DEFUN PATHNAME-TRANSLATE-WILD-COMPONENT
       (TARGET-PATTERN DATA SPECS WILD-ANY WILD-ONE &OPTIONAL REVERSIBLE-P)
  (COND ((EQ TARGET-PATTERN :WILD)
         (IF (AND REVERSIBLE-P (CONSP SPECS))
             (CAR SPECS)
           DATA))
        ((OR (NUMBERP TARGET-PATTERN)
             (SYMBOLP TARGET-PATTERN)
             (EQ SPECS T))
         TARGET-PATTERN)
        ((CONSP TARGET-PATTERN)
         (LOOP FOR ELT IN TARGET-PATTERN
               COLLECT
               (IF (EQ ELT :WILD)
                   (POP SPECS)
                 (MULTIPLE-VALUE-BIND (NEW-ELT SPECS-LEFT)
                     (PATHNAME-TRANSLATE-COMPONENT-FROM-SPECS
                       ELT SPECS WILD-ANY WILD-ONE)
                   (SETQ SPECS SPECS-LEFT)
                   NEW-ELT))))
        (T (PATHNAME-TRANSLATE-COMPONENT-FROM-SPECS
             TARGET-PATTERN SPECS WILD-ANY WILD-ONE))))
