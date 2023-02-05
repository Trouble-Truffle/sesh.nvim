(var opts {:autosave {:enable false :autocmds []}
           :autoload false
           :autoswitch {:enable true :exclude_ft []}
           :sessions_info (.. (vim.fn.stdpath :data) :/sessions-info.json)
           :session_path (.. (vim.fn.stdpath :data) :/sessions)})

(var sessions-info (vim.fn.json_decode (vim.fn.readfile opts.sessions_info)))

(fn read_sessions_info []
  sessions-info)

(var cur-session nil)
(fn opened_session []
  cur-session)

(fn read_opts []
  opts)

(fn update_sessions_info []
  (var session-info* [])
  (each [k _ (vim.fs.dir opts.session_path)]
    (var curdir nil)
    (var buffers [])
    (var focused "")
    (each [line (io.lines (.. opts.session_path k))]
      (match (string.match line "^cd%s+(.*)$")
        x (set curdir x))
      (match (string.match line "^edit%s+(.*)$")
        x (set focused x))
      (match (string.match line "^badd%s+%+%d+%s+(.*)$")
        x (table.insert buffers x)))
    (tset session-info* k {: curdir : buffers : focused}))
  (set sessions-info session-info*)
  (with-open [file (io.open opts.sessions_info :w+)]
    (file:write (vim.fn.json_encode session-info*))))

(fn setup [user-opts]
  (set opts (vim.tbl_deep_extend :force opts (or user-opts [])))
  (when (= nil (string.find (. opts :session_path) "/$"))
    (tset opts :session_path (.. (. opts :session_path) "/")))
  (when (= "" (vim.fn.finddir (. opts :session_path)))
    (vim.notify (.. "Session path: '" (. opts :session_path) "' not found")
                :error))
  (update_sessions_info)
  (when opts.autosave.enable
    (vim.api.nvim_create_autocmd (vim.tbl_flatten [:VimLeave
                                                   opts.autosave.autocmds])
                                 {:group (vim.api.nvim_create_augroup :SessionAutosave
                                                                      [])
                                  :desc "Save session on exit and through specified autocmds in setup"
                                  :callback #(when cur-session
                                               (vim.cmd.mksession {:args [cur-session]
                                                                   :bang true})
                                               (update_sessions_info))}))
  (when (and opts.autoload.enable (= 0 (vim.fn.argc)))
    (local to-load (icollect [k v (pairs sessions-info)]
                     (if (= (vim.fn.getcwd) (vim.fn.expand v.curdir))
                         (.. opts.session_path k)
                         nil)))
    (match to-load
      [s] (do
            (set cur-session s)
            (vim.cmd.source s)))))

(fn list []
  (icollect [k _ (vim.fs.dir opts.session_path)]
    k))

(fn create []
  (when (= "" (vim.fn.finddir (. opts :session_path)))
    (error (.. "Session path: '" (. opts :session_path) "' not found")))
  (vim.ui.input {:prompt "Session Name:"
                 :default (vim.fs.basename (vim.fn.getcwd))}
                #(let [session (.. opts.session_path $1)]
                   (if (= nil (next (vim.fs.find $1 {:path opts.session_path})))
                       (do
                         (vim.cmd.mksession {:args [session]})
                         (vim.notify (.. "Made session: " session))
                         (set cur-session session))
                       (vim.notify (.. "Session '" $1 "' already exists") :warn)))))

(fn save []
  (if (= nil cur-session)
      (create)
      (vim.ui.select [:Yes :No]
                     {:prompt (.. "Overwrite session '"
                                  (vim.fs.basename cur-session) "'?")}
                     #(match $1
                        :Yes (do
                               (vim.cmd.mksession {:args [cur-session]
                                                   :bang true})
                               (vim.notify (.. "Saved session: " cur-session))))))
  (update_sessions_info))

(lambda switch [selection]
  (when (and opts.autosave (not= nil cur-session))
    (vim.cmd.mksession {:args [cur-session] :bang true})
    (update_sessions_info))
  (local buffers (icollect [_ buf (ipairs (vim.api.nvim_list_bufs))]
                   (if (and (vim.api.nvim_buf_is_valid buf)
                            (vim.api.nvim_buf_get_option buf :buflisted)
                            (vim.api.nvim_buf_get_option buf :modifiable)
                            (not (vim.tbl_contains opts.autoswitch.exclude_ft
                                                   (vim.api.nvim_buf_get_option buf
                                                                                :filetype))))
                       buf)))
  (var has-modified false)
  (each [_ v (ipairs buffers)]
    (when (vim.api.nvim_buf_get_option v :modified)
      (set has-modified true)))
  (if has-modified
      (vim.ui.select ["Yes (save buffers and switch)"
                      "Yes (continue without saving)"
                      :No]
                     {:prompt "Modified buffers found, continue?"}
                     (fn [x]
                       (var go-on true)
                       (match x
                         "Yes (save buffers and switch)" (vim.cmd :wall!)
                         "Yes (continue without saving)" nil
                         _ (set go-on false))
                       (when go-on
                         (each [_ v (ipairs buffers)]
                           (vim.api.nvim_buf_delete v {:force true}))
                         (vim.cmd.source (.. opts.session_path selection))
                         (set cur-session (.. opts.session_path selection)))))
      (do
        (each [_ v (ipairs buffers)]
          (vim.api.nvim_buf_delete v {:force true}))
        (vim.cmd.source (.. opts.session_path selection))
        (set cur-session (.. opts.session_path selection)))))

(fn load [selection]
  (if (= nil selection)
      (vim.ui.select (list) {:prompt "Load session: "} #(if $1 (load $1) nil))
      (= (.. opts.session_path selection) cur-session)
      (vim.notify "Already in the loaded session" :warn)
      (let [session (.. opts.session_path selection)]
        (if opts.autoswitch
            (switch selection)
            (vim.cmd.source session))
        (set cur-session session))))

(fn delete [selection]
  (if (= nil selection)
      (vim.ui.select (list) {:prompt "Delete session: "}
                     #(if $1 (delete $1) nil))
      (= nil (next (vim.fs.find selection opts.session_path)))
      (error (.. "Session '" selection "' does not exist"))
      (let [session (.. opts.session_path selection)]
        (vim.ui.select ["Yes (this cannot be undone)" :No]
                       {:prompt (.. "Delete session '" session "'?")}
                       #(match $1
                          :No nil
                          _ (do
                              (os.remove session)
                              (vim.notify (.. "Deleted session: " session))
                              (set cur-session nil)))))))

{: save
 : setup
 : load
 : list
 : delete
 : opened_session
 : switch
 : read_opts
 : read_sessions_info
 : update_sessions_info}