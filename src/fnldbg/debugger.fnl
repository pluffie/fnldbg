(local utils (require :fnldbg.utils))
(local fennel (require :fennel))
(local {: sourcemap} (require :fennel.compiler))

;; Utils
(var ?metadata nil)
(var file-source nil)
(var self-source nil)

(λ get-info [level what]
  (let [info (debug.getinfo (+ level 1) what)]
    (if (= file-source (?. info :source))
      ;; Info from metafennel
      (do (set info.source (or (?. ?metadata :source) info.source))
          (when (and info.currentline
                     (?. ?metadata :sourcemap info.currentline :line))
            (set info.currentline (?. ?metadata :sourcemap info.currentline :line))
            (when info.short_src
              (set info.short_src (. ?metadata :sourcemap info.currentline :file))))
          (when info.linedefined
            (set info.linedefined (or (?. ?metadata :sourcemap info.linedefined :line)
                                      info.linedefined))))
       ;; Fennel compiler metadata
       (do (when (?. info :currentline)
             (set info.currentline (or (?. sourcemap info.source info.currentline 2)
                                       info.currentline)))
           (when (?. info :linedefined)
             (set info.linedefined (or (?. sourcemap info.source info.linedefined 2)
                                       info.linedefined)))))
    info))


;; WARNING: DARK MAGIC
(λ get-initial-level []
  "Get stackframe id that should be used as initial-level in functions which use
  get-info."
  (var initial-level 3)
  (while (= (. (get-info initial-level "S") :source) self-source)
    (set initial-level (+ initial-level 1)))
  (- initial-level 1))

(macro eat [& body]
  `(do ,body nil))

(λ countdown [count break]
  (var count count)
  (fn [...]
     (set count (- count 1))
     (when (= 0 count)
       (break ...))))

(λ get-trace []
  (local initial-level (get-initial-level))
  (var level initial-level)
  (var continue? true)
  (local trace [])
  (while continue?
    (local info (get-info level "Sln"))
    (set continue? (not= nil (get-info (+ level 3) ""))) ;; WARNING: DARK MAGIC
    (when continue?
      (set level (+ level 1))
      (tset trace (- level initial-level) info)))
  {:trace trace})

(λ find-local-values [name]
  (local initial-level (get-initial-level))
  (var level initial-level)
  (local vals [])
  (while (not= nil (get-info (+ level 3) ""))
    (var index 1)
    (var continue? true)
    (while continue? 
      (local (local-name value) (debug.getlocal level index))
      (if (= name local-name)
          (table.insert vals [(- level initial-level -1) value])
          (= nil local-name)
          (set continue? false))
      (set index (+ index 1)))
    (set level (+ level 1)))
  vals)

(λ get-nearest-local-value [name]
  (local initial-level (get-initial-level))
  (var level initial-level)
  (var value nil)
  (var found? false)
  (while (and (not found?) (not= nil (debug.getinfo (+ level 3) "")))
    (var index 1)
    (var continue? true)
    (while (and (not found?) continue?)
      (local (local-name local-value) (debug.getlocal level index))
      (if (= name local-name)
          (do (set found? true)
              (set value local-value))
          (= nil local-name)
          (set continue? false))
      (set index (+ index 1)))
    (set level (+ level 1)))
  value)

(λ set-nearest-local-value [name value]
  (local initial-level (get-initial-level))
  (var level initial-level)
  (var found? false)
  (while (and (not found?) (not= nil (debug.getinfo (+ level 3) "")))
    (var index 1)
    (var continue? true)
    (while (and (not found?) continue?)
      (local (local-name _) (debug.getlocal level index))
      (if (= name local-name)
          (do (set found? true)
              (debug.setlocal level index value))
          (= nil local-name)
          (set continue? false))
      (set index (+ index 1)))
    (set level (+ level 1))))


(λ get-all-locals []
  (local initial-level (get-initial-level))
  (var level initial-level)
  (local locals {})
  (while (not= nil (debug.getinfo (+ level 3) ""))
    (var index 1)
    (var continue? true)
    (while continue? 
      (local (name value) (debug.getlocal level index))
      (if (= nil name)
          (set continue? false)
          (when (= nil (. locals name))
           (tset locals name value)))
      (set index (+ index 1)))
    (set level (+ level 1)))
  locals)

;; State
(var execution-finished? false)
(var continue-debugging? true)

;; Public API
(λ message [source kind fmt ...]
  {: source
   : kind
   :message (string.format fmt ...)})

(λ handle-request [request break]
  (case request
    {:step-line lines}
    (if execution-finished?
      (message :debugger :info "Program execution is finished; nowhere to step")
      (eat (debug.sethook (countdown lines break) "l")))

    {:step count}
    (if execution-finished?
      (message :debugger :info "Program execution is finished; nowhere to step")
      (eat (debug.sethook break "" count)))

    :trace
    (get-trace)

    {:step-in funcs}
    (eat (debug.sethook #(let [{:name ?funcname} (get-info 2 "n")]
                           (when (and ?funcname (utils.elem ?funcname funcs))
                             (break $1)))
                        "c"))

    {:step-out funcs}
    (eat (debug.sethook #(let [{:name ?funcname} (get-info 2 "n")]
                           (when (and ?funcname
                                      (= :return $1)
                                      (utils.elem ?funcname funcs))
                             (break $1)))
                        "r"))

    {:get-local name}
    {:local-values (find-local-values name) : name}
    
    {:get-nearest-value name}
    {:nearest-value (get-nearest-local-value name)}

    {:set-nearest-value name : value}
    (do (set-nearest-local-value name value)
        :nop)

    :locals
    {:locals (get-all-locals)}

    :run
    (eat (debug.sethook))

    :finish-debugging
    (eat (set continue-debugging? false))))

(λ debug-file [path ?meta-path break on-message ?finalize]
  (local loader
    (case (utils.path->extension path)
      :lua
      loadfile

      :fnl
      (do (on-message
            (message :debugger :error
                     "Direct Fennel loading is not supported yet; please compile your code first"))
          #nil)

      ?extension
      (do (on-message
            (message :debugger :info
                     "Unknown file extension: %s. Trying to load as Lua..."
                      (or ?extension "#<no extension>")))
          loadfile)))

  (when (not= nil ?meta-path)
    (case (pcall fennel.dofile ?meta-path)
      (false _)
      (on-message
        (message :debugger :warning
                 "Failed to load metadata file: %s" ?meta-path))

      (true metadata)
      (set ?metadata metadata)))

  ;; TODO: Implement arguments passing
  ;; Generate arguments
  ;(local args (collect [k v (pairs arg)]
  ;              (- k (length arg)) v))
  ;(when (not= nil ?args)
  ;  (each [i v (ipairs ?args)]
  ;    (tset args i v)))

  ;(local ENTRY_POINT (loadfile path "bt" {:arg args}))

  ;; Get debugger's source for the further dark magic
  (set self-source (. (get-info 1 "S") :source))

  (λ finalize []
    (when (= :function (type ?finalize)) (?finalize))
    (os.exit 0))

  (λ break-wrapper [...]
    (when (not file-source)
      (local info (debug.getinfo 2 "S"))
      (set file-source info.source))

    (if continue-debugging?
      (break ...)
      (finalize)))

  (local ENTRY_POINT (loader path "bt"))
  (if (= nil ENTRY_POINT)
   (on-message (message :debugger :error "Couldn't load file"))
   (do (xpcall #(do (debug.sethook break-wrapper "c")
                    (ENTRY_POINT))
               #(do (debug.sethook)
                    (set execution-finished? true)
                    (when continue-debugging?
                      (on-message (message :program :error $1))
                      (break :finished))))
       (set execution-finished? true)
       (while continue-debugging? (break :finished))))

  (finalize))

{: message
 : handle-request
 : debug-file}
