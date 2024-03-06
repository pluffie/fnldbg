(local socket (require :socket))
(local utils (require :fnldbg.utils))
(local debugger (require :fnldbg.debugger))

(var server nil)
(var client nil)
(var message-queue [])

(λ setup-connection []
  (when (= nil server)
    (set server (assert (socket.bind "127.0.0.1" 23772)))
    (server:setoption :reuseaddr true))

  (when (= nil client)
    (set client (server:accept))
    (table.insert message-queue
                  (debugger.message :socket :info "Connection established."))))

(λ break [kind]
  (setup-connection)

  (var continue? true)

  ;; TODO: send actual execution state
  (case kind
    :finished nil)

  (client:send (utils.serialize-line {:bunch message-queue}))
  (set message-queue [])

  (λ end-loop []
    (client:close)
    (set client nil)
    (set continue? false))

  (while continue?
    (setup-connection)

    (local (request err) (client:receive "*l"))

    (when (= nil err)
      (case err
        nil
        (let [data (utils.deserialize request)
              ?response (when (not= nil data)
                          (debugger.handle-request data break))
              response (utils.serialize-line ?response)]
          ;; debugger.handle-request returns nil when code execution should
          ;; be resumed
          (set continue? (not= nil ?response))
          (when continue?
            (local (_ err) (client:send response))
            (case err
              :closed (end-loop)
              err     (error err))))

        :closed
        (end-loop)

        err
        (error err)))))

(λ send-message [msg]
  (table.insert message-queue msg))

(λ finalize []
  (table.insert message-queue :closed)

  ;; Send all pending messages
  (setup-connection)
  (client:send (utils.serialize-line {:bunch message-queue}))

  ;; Close all remote stuff
  (client:close)
  (server:close))

(fn [{: file : ?meta-file}]
  (debugger.debug-file file ?meta-file break send-message finalize))
