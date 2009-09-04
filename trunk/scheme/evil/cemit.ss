#ci(module cemit (lib "swindle.ss" "swindle")

  (require "utils.ss")
  (require "generics.ss")
  (require "cmodel.ss")

  (defgeneric emit-c-code (thing))

  (defmethod (emit-c-code (thing <c-code>))
    (evil-error 'emit-c-code "No emit method for" thing))

  (defmethod :before (emit-c-code (thing <c-code>))
    (for-each (lambda (label)
                (display label)
                (display ": "))
              (c-code/labels thing)))

  (defmethod (emit-c-code (spec <c-type-specifier>))
    (display (car (type-specifier->list spec)))
    (for-each (lambda (id)
                (display " ")
                (display id))
              (cdr (type-specifier->list spec))))

  (defmethod (emit-c-code (decl <direct-declarator>))
    (display (c-identifier->string (declarator/identifier decl))))

  (defmethod (emit-c-code (adecl <array-declarator>))
    (emit-c-code (inner-declarator adecl))
    (display "[]"))

  (defmethod (emit-c-code (fdecl <function-declarator>))
    (emit-c-code (inner-declarator fdecl))
    (display "()"))

  (defmethod (emit-c-code (pdecl <pointer-declarator>))
    (display "* ")
    (emit-c-code (inner-declarator pdecl)))

  (defmethod (emit-c-code (decl <c-declaration>))
    (case (declaration/storage-class decl)
      ((:typedef) (display "typedef "))
      ((:extern) (display "extern "))
      (else #f))
    (emit-c-code (declaration/type decl))
    (display " ")
    (emit-c-code (declaration/declarator decl)))

  (defmethod (emit-c-code (thing <c-translation-unit>))
    (display thing))

  (defmethod (emit-c-code (thing <c-assignment>))
    (emit-operand 15 (assignment/place thing))
    (display " ")
    (display (assignment/operator thing))
    (display " ")
    (emit-operand 15 (assignment/value thing)))

  (defmethod (emit-c-code (thing <c-block>))
    (display "{")
    (for-each (lambda (element)
                (newline)
                (display "  ")
                (emit-c-code element)
                (display ";"))
              (block-contents thing))
    (newline)
    (display "}"))

  (defmethod (emit-c-code (thing <c-break>))
    (display "break"))

  (defmethod (emit-c-code (thing <c-delete>))
    (display "delete ")
    (emit-c-code (delete/place thing)))

  (defmethod (emit-c-code (thing <c-do-while>))
    (display "do-while..."))

  (defmethod (emit-c-code (thing <c-expression-list>))
    (emit-operand 17 (car (expression-list/actions thing)))
    (for-each (lambda (action)
                (display ", ")
                (emit-operand 17 action))
              (cdr (expression-list/actions thing))))

  (defmethod (emit-c-code (thing <c-if>))
    (display "if (")
    (emit-c-code (conditional/predicate thing))
    (display ") ")
    (emit-c-code (conditional/consequent thing))
    (if (conditional/alternative thing)
        (begin (display " else ")
               (emit-c-code (conditional/alternative thing)))))

  (defmethod (emit-c-code (thing <c-for>))
    (display "for (")
    (emit-c-code (for/initialize thing))
    (display "; ")
    (emit-c-code (for/predicate thing))
    (display "; ")
    (emit-c-code (for/step thing))
    (display ") ")
    (emit-c-code (for/body thing)))

  (defmethod (emit-c-code (thing <c-goto>))
    (display "goto ")
    (display (goto/target thing)))

  (defmethod (emit-c-code (thing <c-while>))
    (display "while..."))

  (defmethod (emit-c-code (thing <return>))
    (display "return ")
    (emit-c-code (return/value thing)))

  (defmethod (emit-c-code (thing <c-switch>))
    (display "switch (")
    (emit-c-code (switch/expression thing))
    (display ") {..."))

  (defmethod (emit-c-code (thing <c-this>))
    (display "this"))

  (defmethod (emit-c-code (thing <c-void-expression>))
    '())

  (define (emit-operand prec operand)
    (if (and (or (instance-of? operand <c-unary-expression>)
                 (instance-of? operand <c-binary-expression>)
                 (instance-of? operand <c-trinary-expression>))
             (> (operator/precedence (expression/operator operand)) prec))
        (begin (display "(")
               (emit-c-code operand)
               (display ")"))
        (emit-c-code operand)))

  (defmethod (emit-c-code (code <c-unary-expression>))
    (display (operator/name (expression/operator code)))
    (display " ")
    (emit-operand (operator/precedence (expression/operator code))
                  (expression/operand code)))

  (defmethod (emit-c-code (code <c-binary-expression>))
    (emit-operand (operator/precedence (expression/operator code))
                  (left code))
    (display " ")
    (display (operator/name (expression/operator code)))
    (display " ")
    (emit-operand (operator/precedence (expression/operator code))
                  (right code)))

  (defmethod (emit-c-code (code <c-array-expression>))
    (emit-operand (operator/precedence (expression/operator code))
                  (left code))
    (display "[")
    (emit-c-code (right code))
    (display "]"))

  (defmethod (emit-c-code (code <c-arrow-expression>))
    (emit-operand (operator/precedence (expression/operator code))
                  (left code))
    (display (operator/name (expression/operator code)))
    (display (c-identifier->string (right code))))

  (defmethod (emit-c-code (code <c-dot-expression>))
    (emit-operand (operator/precedence (expression/operator code))
                  (left code))
    (display (operator/name (expression/operator code)))
    (display (c-identifier->string (right code))))

  (defmethod (emit-c-code (code <c-sizeof-expression>))
    (display "sizeof ")
    (display (expression/operand code)))

  (defmethod (emit-c-code (code <c-conditional-expression>))
    (emit-operand (operator/precedence (expression/operator code))
                  (left code))
    (display " ? ")
    (emit-operand (operator/precedence (expression/operator code))
                  (middle code))
    (display " : ")
    (emit-operand (operator/precedence (expression/operator code))
                  (right code)))

  (defmethod (emit-c-code (code <c-cast-expression>))
    (display (c-cast/type code))
    (emit-operand (operator/precedence (expression/operator code)) (expression/operand code)))

  (defmethod (emit-c-code (thing <c-expression-sequence>))
    (emit-operand 17 (car (actions thing)))
    (for-each (lambda (action)
                (display ", ")
                (emit-operand 17 action))
              (cdr (actions thing))))

  (defmethod (emit-c-code (thing <c-new>))
    (display "new ..."))

  (defmethod (emit-c-code (thing <c-new-array>))
    (display "new ... []"))

  (defmethod (emit-c-code (thing <c-literal>))
    (cond ((string? (value thing))
           (display "\"")
           (display thing)
           (display "\""))

          ((number? (value thing)) (display (value thing)))
          (else (evil-error 'emit-c-code "can't emit this literal" thing))))

  (defmethod (emit-c-code (thing <c-funcall>))
    (evil-message "operator is" (expression/operator thing))
    (emit-c-code (expression/operator thing))
    (if (null? (expression/operands thing))
        (display "()")
        (begin (display " (")
               (let loop ((args (expression/operands thing)))
                 (if (null? (cdr args))
                     (begin (emit-c-code (car args))
                            (display ")"))
                     (begin (emit-c-code (car args))
                            (display ", ")
                            (loop (cdr args))))))))

  (defmethod (emit-c-code (thing <c-method-call>))
    (emit-operand 0 (expression/operator thing))
    (if (null? (expression/operands thing))
        (display "()")
        (begin (display " (")
               (let loop ((args (expression/operands thing)))
                 (if (null? (cdr args))
                     (begin (emit-c-code (car args))
                            (display ")"))
                     (begin (emit-c-code (car args))
                            (display ", ")
                            (loop (cdr args))))))))

  (defmethod (emit-c-code (thing <c-variable>))
    (display (c-identifier->string (variable/name thing))))

  (provide emit-c-code)
  )