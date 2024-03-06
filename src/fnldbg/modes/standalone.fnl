(local debugger (require :fnldbg.debugger))
(local repl (require :fnldbg.repl))

(local repl-thread (repl.make-repl))

(λ break [kind]
  ;; TODO: print execution state

  (var continue? true)
  (var last-value nil)

  (while continue?
    (local (_ request) (coroutine.resume repl-thread last-value))
    (set continue? (not= nil request))
    (when continue?
      (local ?response (debugger.handle-request request break))
      (set continue? (not= nil ?response))
      (when continue?
        (set last-value (repl.handle-response ?response))))))

(fn [{: file : ?meta-file}]
  (debugger.debug-file file ?meta-file break repl.handle-response))
