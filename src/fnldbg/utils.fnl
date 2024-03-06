(local json (require :json))

(λ path->extension [path]
  "Returns extension of file"
  (string.match path "^.+%.(.+)$"))

;; TODO: rewrite without using json
(λ serialize [?data]
  (json.encode ?data))

(λ serialize-line [?data]
  (.. (serialize ?data) "\n"))

;; TODO: rewrite without using json
(λ deserialize [str]
  (json.decode str))

(λ fail [msg]
  (print (.. "\x1b[1;31merror:\x1b[0m " msg))
  (os.exit 1))

(λ elem [needle haystack]
  (accumulate [r false _ v (pairs haystack)]
    (or r (= v needle))))

(λ concat-tables [tbl1 tbl2]
  (local tbl {})
  (each [k v (pairs tbl1)]
    (tset tbl k v))
  (each [k v (pairs tbl2)]
    (tset tbl k v))
  tbl)

{: path->extension
 : serialize
 : serialize-line
 : deserialize
 : fail
 : elem
 : concat-tables}
