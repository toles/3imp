#!/usr/local/bin/gosh

(load "./util.scm")

(define compile
  (lambda (x next)
    (cond
     ((symbol? x)
      (list 'refer x next))
     ((pair? x)
      (record-case x
                   (quote (obj)
                          (list 'constant obj next))
                   (lambda (vars body)
                     (list 'close vars (compile body '(return)) next))
                   (if (test then else)
                       (let ((thenc (compile then next))
                             (elsec (compile else next)))
                         (compile test (list 'test thenc elsec))))
                   (set! (var x)
                         (compile x (list 'assign var next)))
                   (call/cc (x)
                            (let ((c (list 'conti
                                           (list 'argument
                                                 (compile x '(apply))))))
                              (if (tail? next)
                                  c
                                (list 'frame next c))))
                   (else
                    (recur loop ((args (cdr x))
                                 (c (compile (car x) '(apply))))
                           (if (null? args)
                               (if (tail? next)
                                   c
                                 (list 'frame next c))
                             (loop (cdr args)
                                   (compile (car args)
                                            (list 'argument c))))))))
     (else
      (list 'constant x next)))))

(define tail?
  (lambda (next)
    (eq? (car next) 'return)))

;;;;

(define extend
  (lambda (e vars vals)
    (cons (cons vars vals) e)))

(define VM
  (lambda (a x e r s)
    (record-case x
                 (halt () a)
                 (refer (var x)
                        (VM (car (lookup var e)) x e r s))
                 (constant (obj x)
                           (VM obj x e r s))
                 (close (vars body x)
                        (VM (closure body e vars) x e r s))
                 (test (then else)
                       (VM a (if a then else) e r s))
                 (assign (var x)
                         (set-car! (lookup var e) a)
                         (VM a x e r s))
                 (conti (x)
                        (VM (continuation s) x e r s))
                 (nuate (s var)
                        (VM (car (lookup var e)) '(return) e r s))
                 (frame (ret x)
                        (VM a x e '() (call-frame ret e r s)))
                 (argument (x)
                           (VM a x e (cons a r) s))
                 (apply ()
                        (record a (body e vars)
                                (VM a body (extend e vars r) '() s)))
                 (return ()
                         (record s (x e r s)
                                 (VM a x e r s)))
                 (else
                  (error "illegal opcode")))))

(define lookup
  (lambda (var e)
    (recur nxtrib ((e e))
           (recur nxtelt ((vars (caar e)) (vals (cdar e)))
                  (cond
                   ((null? vars) (nxtrib (cdr e)))
                   ((eq? (car vars) var) vals)
                   (else (nxtelt (cdr vars) (cdr vals))))))))

(define closure
  (lambda (body e vars)
    (list body e vars)))

(define continuation
  (lambda (s)
    (closure (list 'nuate s 'v) '() '(v))))

(define call-frame
  (lambda (x e r s)
    (list x e r s)))

(define evaluate
  (lambda (x)
    (VM '() (compile x '(halt)) '() '() '())))
