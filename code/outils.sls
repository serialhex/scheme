
(library (outils)
  (export lookup
          lookup-spine
          
          ;; read/write utilities
          read-all
          write-expression-to-file
          write-r6rs-expression-to-file
          save-fasl
          fasl-load

          ;; config utilities
          processed-config
          persist-config
          load-config

          ;; configlet utilities
          configlet-uuid)
  (import (chezscheme))

  ;;; Assoc lists

  (define lookup
    (case-lambda
      ((symbol)
       (lambda (thing)
         (lookup symbol thing)))
      ((symbol thing)
       (cond ((assoc symbol thing) => cdr)
             (error 'lookup "key not in alist" symbol thing)))
      ((default symbol thing)
       (cond ((assoc symbol thing)
              => cdr)
             (else default)))))

  (define (lookup-spine keys alist)
    (fold-left (lambda (alist key)
                 (lookup key alist))
               alist
               keys))

  ;;; i/o
  
  (define (read-all)
    (let loop ((sexp (read)) (config '()))
      (if (eof-object? sexp)
          (reverse config)
          (loop (read) (cons sexp config)))))

  (define (write-expression-to-file code file)
    (when (file-exists? file)
      (delete-file file))
    (with-output-to-file file
      (lambda ()
        (for-each (lambda (line)
                    (pretty-print line) (newline))
                  code))))

  (define (write-r6rs-expression-to-file code file)
    (when (file-exists? file)
      (delete-file file))
    (with-output-to-file file
      (lambda ()
        (format #t "#!r6rs~%~%")
        (for-each (lambda (line)
                    (pretty-print line) (newline))
                  code))))

  (define (save-fasl obj file)
    (when (file-exists? file)
      (delete-file file))
    (let ((out (open-file-output-port file)))
      (fasl-write obj out)
      (close-output-port out)))

  (define (fasl-load file)
    (let ((in (open-file-input-port file)))
      (let ((obj (fasl-read in)))
        (close-input-port in)
        obj)))

  ;;; Config
  
  (define config-file "config/track.ss")
  (define config-fasl "data/config.fasl")

  (define (persist-config)
    (save-fasl (with-input-from-file config-file read-all) config-fasl))

  (define (load-config)
    (fasl-load config-fasl))

  (define (processed-config)
    (map (lambda (x)
           (if (not (eq? (car x) 'exercises))
               x
               `(exercises . ,(map (lambda (ex)
                                     (map format-for-configlet ex))
                                   (remp (lambda (exercise)
                                           (memq 'wip (map car exercise)))
                                         (cdr x))))))
         (load-config)))


  ;;; UUID
  ;; wrapper to read uuid generated by configlet from scheme
  (define (configlet-uuid)
    (let ((from-to-pid (process "./bin/configlet uuid")))
      (let ((fresh-uuid (read (car from-to-pid))))
        (close-port (car from-to-pid))
        (close-port (cadr from-to-pid))
        (symbol->string fresh-uuid))))

  
  ;;; Configlet formatting
  (define (kebab->snake str)
    (let ((k->s (lambda (c) (if (char=? c #\-) #\_ c))))
      (apply string (map k->s (string->list str)))))

  (define (symbol->snake-case-string symbol)
    (kebab->snake (symbol->string symbol)))

  ;; to make exercism/configlet happy
  (define (format-for-configlet pair)
    (let ((snake-key (symbol->snake-case-string (car pair))))
      (if (null? (cdr pair))
          `(,snake-key)
          ;; sort the topics list
          (if (eq? 'topics (car pair))
              (cons snake-key
                    (sort string<?
                          (map symbol->snake-case-string (cdr pair))))
              ;; regular pair for everything else
              `(,snake-key . ,(cdr pair))))))
  ;; End Preprocessing/Helpers for make-config
  )