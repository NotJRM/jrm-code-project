;;; -*- Mode:LISP; Package:USER; Base:10 -*-

;;; PUT SOURCE FILE PROPERTIES ON UCODE TAGS.



(SI:DEFINE-HOST "WILD"
                :HOST-NAMES '("WILD")
                :MACHINE-TYPE :LISPM
                :SYSTEM-TYPE :LISPM
                :WILD T)

(DEFUN FIND-PATHNAMES (P)
  (LET ((PATHNAME (FS:PARSE-PATHNAME P)))
    (LET ((HOST (SEND PATHNAME :HOST))
          (DIRECTORY (SEND PATHNAME :DIRECTORY))
          (NAME (SEND PATHNAME :NAME))
          (TYPE (SEND PATHNAME :TYPE))
          (WH (FS:GET-PATHNAME-HOST "WILD")))
      (LET ((L))
        (MAPHASH #'(LAMBDA (KEY PATHNAME)
                           (WHEN (AND (OR (EQ HOST WH) (EQUAL (NTH 0 KEY) HOST))
                                      (OR (EQ DIRECTORY :WILD) (EQUALP (NTH 2 KEY) DIRECTORY))
                                      (OR (EQ NAME :WILD) (STRING-EQUAL (NTH 3 KEY) NAME))
                                      (OR (EQ TYPE :WILD) (STRING-EQUAL (NTH 4 KEY) TYPE)))
                             (PUSH PATHNAME L)))
                 FS:*PATHNAME-HASH-TABLE*)
        L))))


(DEFCONST *UCODE-TAGS* NIL)

(DEFUN SET-UCODE-TAGS ()
  (SETQ *UCODE-TAGS* NIL)
  ;; THIS IS RUN AFTER "SYS:ULAMBDA;LAMBDA-MICROCODE.QFASL" IS LOADED. OR AN ASSEMBLY HAS BEEN RUN.
  (LET ((L (FIND-PATHNAMES "LAM3:RELEASE-3.ULAMBDA;*.LISP")))
    (DOLIST (P L)
      (LET ((GENERIC (SEND (SEND (FS:PARSE-PATHNAME "SYS:ULAMBDA;") :BACK-TRANSLATED-PATHNAME P)
                             :GENERIC-PATHNAME)))
        (WHEN (NOT (ASSQ GENERIC *UCODE-TAGS*))
          (LET ((S (GET P 'LAMBDA:UA-LAMBDA-SEXP)))
            (WHEN S
              (PUSH (NCONS GENERIC) *UCODE-TAGS*)
              (DOLIST (A S)
                (WHEN (SYMBOLP A)
                  (PUSH A (CDAR *UCODE-TAGS*)))))))))))


(DEFUN DUMP-UCODE-TAGS (FILENAME)
  (WITH-OPEN-FILE (STREAM FILENAME :DIRECTION :OUTPUT)
    (FORMAT STREAM ";;;-*-MODE:LISP;PACKAGE:LAMBDA;BASE:10;READTABLE:CL-*-~%")
    (LET ((*PACKAGE* (FIND-PACKAGE "LAMBDA"))
          (*READTABLE* (SI:FIND-READTABLE-NAMED "CL")))
      (PRINT `(SPECIAL *UCODE-TAGS*) STREAM)
      (PRINT `(SETQ *UCODE-TAGS* ',*UCODE-TAGS*) STREAM)
      (PRINT `(DEFUN ENABLE-UCODE-TAGS ()
                (DOLIST (TAG *UCODE-TAGS*)
                (LET ((FS:FDEFINE-FILE-PATHNAME (CAR TAG)))
                  (DOLIST (SYM (CDR TAG))
                    (SI:RECORD-SOURCE-FILE-NAME SYM 'UCODE)))))
             STREAM)
      (PRINT '(ENABLE-UCODE-TAGS) STREAM)
      (TERPRI STREAM))))
