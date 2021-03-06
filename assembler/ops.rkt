#lang racket
(require lens)
(require data/collection)
(require json fancy-app)
(require "utility.rkt")
(require "instruction.rkt")
(require "context.rkt")
(provide instructions instruction-length)
(define hex-string->number (compose (string->number _ 16)
                                    (substring _ 1)))

(define (one-byte-proc hex)
  (λ (context)
     (match-let ([(Context pc parse-tree labels output) context])
       (Context (+ pc 1)
                (rest parse-tree)
                labels
                (set-nth output
                         pc hex)))))

(define (two-byte-proc hex)
  (λ (context)
     (match-let* ([(Context pc parse-tree labels output) context]
                  [(Instruction _ operand) (first parse-tree)]
                  [(Operand value _) operand])
       (Context (+ pc 2)
                (rest parse-tree)
                labels
                (set-nth* output
                          pc hex
                          (+ pc 1) (addr-lobyte value))))))

(define (three-byte-proc hex)
  (λ (context)
     (match-let* ([(Context pc parse-tree labels output) context]
                  [(Instruction _ operand) (first parse-tree)]
                  [(Operand value _) operand])
       (Context (+ pc 3)
                (rest parse-tree)
                labels
                (set-nth* output
                          pc hex
                          (+ pc 1) (addr-lobyte value)
                          (+ pc 2) (addr-hibyte value))))))

(define (mode-string->symbol str)
  (case str
    [("Accumulator") '(ACC . #f)]
    [("Implied") '(IMP . #f)]
    [("Immediate") '(IMM . #f)]
    [("Absolute") '(ABS . #f)]
    [("Absolute,X") '(ABS . X)]
    [("Absolute,Y") '(ABS . Y)]
    [("ZeroPage") '(ZP . #f)]
    [("ZeroPage,X") '(ZP . X)]
    [("ZeroPage,Y") '(ZP . Y)]
    [("Indirect ") '(IND . #f)]
    [("(Indirect,X)") '(IND . X)]
    [("(Indirect),Y") '(IND . Y)]
    [("Relative") '(REL . #f)]))

(define instructions
  (for/fold ([result (hash)])
    ([op (read-json (open-input-file "6502_instructions.json"))])
    (match-define (hash-table ('opcode hex) ('name name) ('mode mode) ('bytes len)) op)
    (hash-update result
                 (string->symbol name)
                 (hash-set _ (mode-string->symbol mode) (case (string->number len)
                                                          [(1) (one-byte-proc (string->number (string-cdr hex) 16))]
                                                          [(2) (two-byte-proc (string->number (string-cdr hex) 16))]
                                                          [(3) (three-byte-proc (string->number (string-cdr hex) 16))]))
                 hash)))

(define (instruction-length name mode)
  (case name
    [(JMP) 3]
    [else
      (case (car mode)
        [(IMM) 2]
        [(ZP) 2]
        [(ZP) 2]
        [(ABS) 3]
        [(IND) 2]
        [(IMP) 1]
        [(REL) 2])]))
