(*
Module: Ssh
  Parses /etc/ssh/ssh_config

*)

module Ssh =
    autoload xfm

    let eol = del /[ \t]*\n/ "\n"
    let spc = Util.del_ws_spc

    let key_re = /[A-Za-z0-9]+/
               - /SendEnv|Host|ProxyCommand|RemoteForward|LocalForward|MACs|Ciphers/

    let comment = Util.comment
    let empty = Util.empty
    let comma = Util.del_str ","
    let indent = del /[ \t]*/ ""
    let value_to_eol = store /([^ \t\n].*[^ \t\n]|[^ \t\n])/
    let value_to_spc = store /[^ \t\n]+/
    let value_to_comma = store /[^, \t\n]+/

    let array_entry (k:string) =
        [ key k . counter k . [ spc . seq k . value_to_spc]* . eol ]

    let commas_entry (k:string) =
	[ key k . counter k . spc . 
	    [ seq k . value_to_comma] . ([ seq k . comma . value_to_comma])* . eol ]

    let send_env = array_entry "SendEnv"

    let proxy_command = [ indent . key "ProxyCommand" . spc . value_to_eol . eol ]

    let fw_entry (k:string) = [ indent . key k . spc . 
	[ key /[^ \t\n\/]+/ . spc . value_to_eol . eol ]]

    let remote_fw = fw_entry "RemoteForward"
    let local_fw = fw_entry "LocalForward"

    let ciphers = commas_entry "Ciphers"
    let macs	= commas_entry "MACs"

    let other_entry =
	[ indent . key key_re . spc . value_to_spc . eol ]

    let entry = (comment | empty
	| send_env
	| proxy_command
	| remote_fw
	| local_fw
	| macs
	| ciphers
	| other_entry)

    let host = [ key "Host" . spc . value_to_eol . eol . entry* ]

    let lns = (comment | empty) * . host*

    let xfm = transform lns (incl "/etc/ssh/ssh_config")