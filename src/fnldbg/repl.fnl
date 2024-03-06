(local utils (require :fnldbg.utils))
(local fennel (require :fennel))

;; Utils
(λ pretty-print-message [source kind message]
  (local pretty-kind
    (case kind
      :info    "\x1b[36minfo"
      :warning "\x1b[33mwarning"
      :error   "\x1b[31merror"))
  (print (string.format "\x1b[1m%s/%s\x1b[0;1m: \x1b[0m%s"
                        source pretty-kind message)))
;; Actions
(local cheatsheet
  ["Basically, this repl is slightly modified Fennel repl."
   "Fennel api is available via fennel variable."
   ""
   "Stepping:"
   "  ,s or (step) or (step :line) : step one line forward"
   "  (step count)                 : step count instructions forward"
   "  (step :nl)                   : step n lines forward"
   ""
   "  ,in f or (step-in :f)        : step to the point where f is called"
   "    NOTE: step-in can take multiple names: (step-in :f :g :h ...)"
   ""
   "  ,out f or (step-out :f)      : step to the point where f is returned"
   "    NOTE: step-out can take multiple names: (step-out :f :g :h ...)"
   ""
   "Looking at values:"
   "  (locals)       : get list of local variables"
   "  (get-local :x) : get all values of x (x can be defined in multiple stack frames)"
   ""
   "Accessing values:"
   "  ?.x : access nearest value of x"
   "    NOTE: you can even set values"
   ""
   "Misc:"
   "  ,t or (trace) : get stacktrace"
   "  ,r or (run)   : Run code until termination"
   ])

(λ how-to-debug []
  "Cheatsheet on debugging with fnldbg."
  ;; I use __fennelview to remote trailing nil
  (setmetatable {} {:__fennelview #cheatsheet}))

(λ trace []
  "Print stack trace."
  (coroutine.yield :trace))

(λ step [?count]
  "Step. (step :nl) would step n lines; (step :n) would step n instructions;
  (step :line) is the same as (step :1l); calling without arguments is the same
  as (step :line)."
  (local count (if (not= nil ?count)
                 (tostring ?count)
                 :line))
  (local lines (tonumber (string.match count "^([1-9]%d*)l$")))
  (local steps (tonumber (string.match count "^([1-9]%d*)$")))

  (if (or (= :line count) (= :l count))
      (coroutine.yield {:step-line 1})
      (not= nil lines)
      (coroutine.yield {:step-line lines})
      (not= nil steps)
      (coroutine.yield {:step steps})
      (error "Invalid count")))

(λ step-in [& funcs]
  "Step to the call of specified function. Can take multiple functions."
  (coroutine.yield {:step-in funcs}))

(λ step-out [& funcs]
  "Step to the return of specified function. Can take multiple functions."
  (coroutine.yield {:step-out funcs}))

(λ locals []
  (coroutine.yield :locals))

(λ get-local [name]
  (coroutine.yield {:get-local name}))

(local ?
  (setmetatable {} {:__fennelview #["Nothing to see here"
                                    "Try writing (locals) instead"]
                    :__index #(coroutine.yield {:get-nearest-value $2})
                    :__newindex #(coroutine.yield {:set-nearest-value $2
                                                   :value $3})}))

(λ run []
  "Run code until termination."
  (coroutine.yield :run))

;; Commands
(λ trace-command []
  "Print stack trace. Alias for (trace)."
  (trace))

(λ step-command []
  "Step one line. Alias for (step :line)."
  (step :line))

(λ in-command [_env read]
  "Step to the call of specified function."
  (case (pcall read)
    (true true name) (step-in (tostring name))
    _                (pretty-print-message :repl :error "Failed to read name")))

(λ out-command [_env read]
  "Step to the return of specified function."
  (case (pcall read)
    (true true name) (step-out (tostring name))
    _                (pretty-print-message :repl :error "Failed to read name")))

(λ run-command []
  "Run code until termination."
  (run))

;; Public REPL API
(λ make-repl []
  (coroutine.create
    #(let [fnldbg-plugin {:name "fnldbg"
                          :versions ["1.4.2"]
                          :repl-command-t trace-command
                          :repl-command-s step-command
                          :repl-command-in in-command
                          :repl-command-out out-command
                          :repl-command-r run-command}
           global-env (getfenv 0)
           custom-env {: fennel
                       : how-to-debug
                       : trace
                       : step
                       : step-in
                       : step-out
                       : locals
                       : get-local
                       : ?
                       : run}]
      (print "Welcome to the fnldbg repl. Use (how-to-debug) to get more info!")
      (print (string.format "Running via %s" (fennel.runtime-version)))
      (fennel.repl {:env (utils.concat-tables global-env custom-env)
                    :plugins [fnldbg-plugin]})
      (coroutine.yield :finish-debugging))))

(λ handle-response [info]
  (case info
    {:trace trace}
    (each [i info (ipairs trace)]
      (print (string.format "%s %s\x1b[0m at \x1b[1m%s\x1b[0m"
                            (if (= 1 i)
                                "\x1b[1;34m=>"
                                "\x1b[1m  ")
                            (if (= "main" info.what)
                                "#<main chunk>"
                                (or info.name "#<anonymous>"))
                            (if (= "C" info.what)
                                "[C]"
                                (.. info.short_src ":" info.currentline)))))

    {: source : kind : message}
    (pretty-print-message source kind message)

    {:local-values vals : name}
    (each [_ [level value] (ipairs vals)]
      (print (string.format "#%-4d (\x1b[1;34mlocal \x1b[0;1m%s \x1b[0m%s)"
                            level name (fennel.view value))))

    {:nearest-value value}
    value

    {:locals locals}
    (each [name value (pairs locals)]
      (print (string.format "(\x1b[1;34mlocal \x1b[0;1m%s \x1b[0m%s)"
                            name (fennel.view value))))

    :nop
    nil))

{: pretty-print-message
 : make-repl
 : handle-response}
