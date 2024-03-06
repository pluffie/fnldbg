(local socket (require :socket))
(local utils (require :fnldbg.utils))
(local repl (require :fnldbg.repl))

(fn []
  (local client (socket.connect "127.0.0.1" 23772))
  (when (= nil client) (utils.fail "Couldn't connect to socket."))

  (local repl-thread (repl.make-repl))

  (var continue? true)
  (var last-value nil)

  (while continue?
    (local (?response ?err) (client:receive "*l"))
    (set continue? (= nil ?err))

    (when continue?
      (local response (utils.deserialize ?response))

      (case response
        {: bunch}
        (each [_ response (ipairs bunch)]
          (when (= :closed response) (set continue? false))
          (set last-value (repl.handle-response response)))

        _regular_response
        (set last-value (repl.handle-response response)))

      (when continue?
        (local (_ request) (coroutine.resume repl-thread last-value))
        (local (_ err) (client:send (utils.serialize-line request)))
        (set continue? (= nil err)))))

  (repl.pretty-print-message :socket :info "Connection closed."))
