#!/usr/bin/ocamlrun ocaml
(* libguestfs
 * Copyright (C) 2009 Red Hat Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 *
 * This script generates a large amount of code and documentation for
 * all the daemon actions.  To add a new action there are only two
 * files you need to change, this one to describe the interface, and
 * daemon/<somefile>.c to write the implementation.
 *)

#load "unix.cma";;

open Printf

type style = ret * args
and ret =
    (* "Err" as a return value means an int used as a simple error
     * indication, ie. 0 or -1.
     *)
  | Err
and args =
    (* 0 arguments, 1 argument, etc. The guestfs_h param is implicit. *)
  | P0
  | P1 of argt
  | P2 of argt * argt
and argt =
  | String of string	(* const char *name, cannot be NULL *)

let functions = [
  ("mount", (Err, P2 (String "device", String "mountpoint")), 1,
   "mount a guest disk at a position in the filesystem",
   "\
Mount a guest disk at a position in the filesystem.  Block devices
are named C</dev/sda>, C</dev/sdb> and so on, as they were added to
the guest.  If those block devices contain partitions, they will have
the usual names (eg. C</dev/sda1>).  Also LVM C</dev/VG/LV>-style
names can be used.

The rules are the same as for L<mount(2)>:  A filesystem must
first be mounted on C</> before others can be mounted.  Other
filesystems can only be mounted on directories which already
exist.

The mounted filesystem is writable, if we have sufficient permissions
on the underlying device.

The filesystem options C<sync> and C<noatime> are set with this
call, in order to improve reliability.");

  ("sync", (Err, P0), 2,
   "sync disks, writes are flushed through to the disk image",
   "\
This syncs the disk, so that any writes are flushed through to the
underlying disk image.

You should always call this if you have modified a disk image, before
calling C<guestfs_close>.");

  ("touch", (Err, P1 (String "path")), 3,
   "update file timestamps or create a new file",
   "\
Touch acts like the L<touch(1)> command.  It can be used to
update the timestamps on a file, or, if the file does not exist,
to create a new zero-length file.");
]

(* 'pr' prints to the current output file. *)
let chan = ref stdout
let pr fs = ksprintf (output_string !chan) fs

let iter_args f = function
  | P0 -> ()
  | P1 arg1 -> f arg1
  | P2 (arg1, arg2) -> f arg1; f arg2

let map_args f = function
  | P0 -> []
  | P1 arg1 -> [f arg1]
  | P2 (arg1, arg2) -> [f arg1; f arg2]

type comment_style = CStyle | HashStyle | OCamlStyle
type license = GPLv2 | LGPLv2

(* Generate a header block in a number of standard styles. *)
let rec generate_header comment license =
  let c = match comment with
    | CStyle ->     pr "/* "; " *"
    | HashStyle ->  pr "# ";  "#"
    | OCamlStyle -> pr "(* "; " *" in
  pr "libguestfs generated file\n";
  pr "%s WARNING: THIS FILE IS GENERATED BY 'src/generator.ml'.\n" c;
  pr "%s ANY CHANGES YOU MAKE TO THIS FILE WILL BE LOST.\n" c;
  pr "%s\n" c;
  pr "%s Copyright (C) 2009 Red Hat Inc.\n" c;
  pr "%s\n" c;
  (match license with
   | GPLv2 ->
       pr "%s This program is free software; you can redistribute it and/or modify\n" c;
       pr "%s it under the terms of the GNU General Public License as published by\n" c;
       pr "%s the Free Software Foundation; either version 2 of the License, or\n" c;
       pr "%s (at your option) any later version.\n" c;
       pr "%s\n" c;
       pr "%s This program is distributed in the hope that it will be useful,\n" c;
       pr "%s but WITHOUT ANY WARRANTY; without even the implied warranty of\n" c;
       pr "%s MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n" c;
       pr "%s GNU General Public License for more details.\n" c;
       pr "%s\n" c;
       pr "%s You should have received a copy of the GNU General Public License along\n" c;
       pr "%s with this program; if not, write to the Free Software Foundation, Inc.,\n" c;
       pr "%s 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.\n" c;

   | LGPLv2 ->
       pr "%s This library is free software; you can redistribute it and/or\n" c;
       pr "%s modify it under the terms of the GNU Lesser General Public\n" c;
       pr "%s License as published by the Free Software Foundation; either\n" c;
       pr "%s version 2 of the License, or (at your option) any later version.\n" c;
       pr "%s\n" c;
       pr "%s This library is distributed in the hope that it will be useful,\n" c;
       pr "%s but WITHOUT ANY WARRANTY; without even the implied warranty of\n" c;
       pr "%s MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU\n" c;
       pr "%s Lesser General Public License for more details.\n" c;
       pr "%s\n" c;
       pr "%s You should have received a copy of the GNU Lesser General Public\n" c;
       pr "%s License along with this library; if not, write to the Free Software\n" c;
       pr "%s Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA\n" c;
  );
  (match comment with
   | CStyle -> pr " */\n"
   | HashStyle -> ()
   | OCamlStyle -> pr " *)\n"
  );
  pr "\n"

(* Generate the pod documentation for the C API. *)
and generate_pod () =
  List.iter (
    fun (shortname, style, _, _, longdesc) ->
      let name = "guestfs_" ^ shortname in
      pr "=head2 %s\n\n" name;
      pr " ";
      generate_prototype ~extern:false ~handle:"handle" name style;
      pr "\n\n";
      pr "%s\n\n" longdesc;
      (match style with
       | (Err, _) ->
	   pr "This function return 0 on success or -1 on error.\n\n"
      );
  ) functions

(* Generate the protocol (XDR) file. *)
and generate_xdr () =
  generate_header CStyle LGPLv2;

  List.iter (
    fun (shortname, style, _, _, _) ->
      let name = "guestfs_" ^ shortname in
      pr "/* %s */\n\n" name;
      (match style with
       | (_, P0) -> ()
       | (_, args) ->
	   pr "struct %s_args {\n" name;
	   iter_args (
	     function
	     | String name -> pr "  string %s<>;\n" name
	   ) args;
	   pr "};\n\n"
      );
      (match style with
       | (Err, _) -> () 
	   (* | ... -> pr "struct %s_ret ...\n" name; *)
      );
  ) functions;

  (* Table of procedure numbers. *)
  pr "enum guestfs_procedure {\n";
  List.iter (
    fun (shortname, _, proc_nr, _, _) ->
      pr "  GUESTFS_PROC_%s = %d,\n" (String.uppercase shortname) proc_nr
  ) functions;
  pr "  GUESTFS_PROC_dummy\n"; (* so we don't have a "hanging comma" *)
  pr "};\n";
  pr "\n";

  (* Having to choose a maximum message size is annoying for several
   * reasons (it limits what we can do in the API), but it (a) makes
   * the protocol a lot simpler, and (b) provides a bound on the size
   * of the daemon which operates in limited memory space.  For large
   * file transfers you should use FTP.
   *)
  pr "const GUESTFS_MESSAGE_MAX = %d;\n" (4 * 1024 * 1024);
  pr "\n";

  (* Message header, etc. *)
  pr "\
const GUESTFS_PROGRAM = 0x2000F5F5;
const GUESTFS_PROTOCOL_VERSION = 1;

enum guestfs_message_direction {
  GUESTFS_DIRECTION_CALL = 0,        /* client -> daemon */
  GUESTFS_DIRECTION_REPLY = 1        /* daemon -> client */
};

enum guestfs_message_status {
  GUESTFS_STATUS_OK = 0,
  GUESTFS_STATUS_ERROR = 1
};

const GUESTFS_ERROR_LEN = 256;

struct guestfs_message_error {
  string error<GUESTFS_ERROR_LEN>;   /* error message */
};

struct guestfs_message_header {
  unsigned prog;                     /* GUESTFS_PROGRAM */
  unsigned vers;                     /* GUESTFS_PROTOCOL_VERSION */
  guestfs_procedure proc;            /* GUESTFS_PROC_x */
  guestfs_message_direction direction;
  unsigned serial;                   /* message serial number */
  guestfs_message_status status;
};
"

(* Generate the guestfs-actions.h file. *)
and generate_actions_h () =
  generate_header CStyle LGPLv2;
  List.iter (
    fun (shortname, style, _, _, _) ->
      let name = "guestfs_" ^ shortname in
      generate_prototype ~single_line:true ~newline:true ~handle:"handle"
	name style
  ) functions

(* Generate the client-side dispatch stubs. *)
and generate_client_actions () =
  generate_header CStyle LGPLv2;
  List.iter (
    fun (shortname, style, _, _, _) ->
      let name = "guestfs_" ^ shortname in

      (* Generate the return value struct. *)
      pr "struct %s_rv {\n" shortname;
      pr "  int cb_done;  /* flag to indicate callback was called */\n";
      pr "  struct guestfs_message_header hdr;\n";
      pr "  struct guestfs_message_error err;\n";
      (match style with
       | (Err, _) -> ()
    (* | _ -> pr "  struct %s_ret ret;\n" name; *)
      );
      pr "};\n\n";

      (* Generate the callback function. *)
      pr "static void %s_cb (guestfs_h *g, void *data, XDR *xdr)\n" shortname;
      pr "{\n";
      pr "  struct %s_rv *rv = (struct %s_rv *) data;\n" shortname shortname;
      pr "\n";
      pr "  if (!xdr_guestfs_message_header (xdr, &rv->hdr)) {\n";
      pr "    error (g, \"%s: failed to parse reply header\");\n" name;
      pr "    return;\n";
      pr "  }\n";
      pr "  if (rv->hdr.status == GUESTFS_STATUS_ERROR) {\n";
      pr "    if (!xdr_guestfs_message_error (xdr, &rv->err)) {\n";
      pr "      error (g, \"%s: failed to parse reply error\");\n" name;
      pr "      return;\n";
      pr "    }\n";
      pr "    goto done;\n";
      pr "  }\n";

      (match style with
       | (Err, _) -> ()
    (* |  _ -> pr "  if (!xdr_%s_ret (&xdr, &rv->ret)) ..." *)
      );

      pr " done:\n";
      pr "  rv->cb_done = 1;\n";
      pr "  main_loop.main_loop_quit (g);\n";
      pr "}\n\n";

      (* Generate the action stub. *)
      generate_prototype ~extern:false ~semicolon:false ~newline:true
	~handle:"g" name style;

      let error_code =
	match style with
	| (Err, _) -> "-1" in

      pr "{\n";

      (match style with
       | (_, P0) -> ()
       | _ -> pr "  struct %s_args args;\n" name
      );

      pr "  struct %s_rv rv;\n" shortname;
      pr "  int serial;\n";
      pr "\n";
      pr "  if (g->state != READY) {\n";
      pr "    error (g, \"%s called from the wrong state, %%d != READY\",\n"
	name;
      pr "      g->state);\n";
      pr "    return %s;\n" error_code;
      pr "  }\n";
      pr "\n";
      pr "  memset (&rv, 0, sizeof rv);\n";
      pr "\n";

      (match style with
       | (_, P0) ->
	   pr "  serial = dispatch (g, GUESTFS_PROC_%s, NULL, NULL);\n"
	     (String.uppercase shortname)
       | (_, args) ->
	   iter_args (
	     function
	     | String name -> pr "  args.%s = (char *) %s;\n" name name
	   ) args;
	   pr "  serial = dispatch (g, GUESTFS_PROC_%s,\n"
	     (String.uppercase shortname);
	   pr "                     (xdrproc_t) xdr_%s_args, (char *) &args);\n"
	     name;
      );
      pr "  if (serial == -1)\n";
      pr "    return %s;\n" error_code;
      pr "\n";

      pr "  rv.cb_done = 0;\n";
      pr "  g->reply_cb_internal = %s_cb;\n" shortname;
      pr "  g->reply_cb_internal_data = &rv;\n";
      pr "  main_loop.main_loop_run (g);\n";
      pr "  g->reply_cb_internal = NULL;\n";
      pr "  g->reply_cb_internal_data = NULL;\n";
      pr "  if (!rv.cb_done) {\n";
      pr "    error (g, \"%s failed, see earlier error messages\");\n" name;
      pr "    return %s;\n" error_code;
      pr "  }\n";
      pr "\n";

      pr "  if (check_reply_header (g, &rv.hdr, GUESTFS_PROC_%s, serial) == -1)\n"
	(String.uppercase shortname);
      pr "    return %s;\n" error_code;
      pr "\n";

      pr "  if (rv.hdr.status == GUESTFS_STATUS_ERROR) {\n";
      pr "    error (g, \"%%s\", rv.err.error);\n";
      pr "    return %s;\n" error_code;
      pr "  }\n";
      pr "\n";

      (match style with
       | (Err, _) -> pr "  return 0;\n"
      );

      pr "}\n\n"
  ) functions

(* Generate daemon/actions.h. *)
and generate_daemon_actions_h () =
  generate_header CStyle GPLv2;
  List.iter (
    fun (name, style, _, _, _) ->
      generate_prototype ~single_line:true ~newline:true ("do_" ^ name) style;
  ) functions

(* Generate the server-side stubs. *)
and generate_daemon_actions () =
  generate_header CStyle GPLv2;

  pr "#include <rpc/types.h>\n";
  pr "#include <rpc/xdr.h>\n";
  pr "#include \"daemon.h\"\n";
  pr "#include \"../src/guestfs_protocol.h\"\n";
  pr "#include \"actions.h\"\n";
  pr "\n";

  List.iter (
    fun (name, style, _, _, _) ->
      (* Generate server-side stubs. *)
      pr "static void %s_stub (XDR *xdr_in)\n" name;
      pr "{\n";
      let error_code =
	match style with
	| (Err, _) -> pr "  int r;\n"; "-1" in
      (match style with
       | (_, P0) -> ()
       | (_, args) ->
	   pr "  struct guestfs_%s_args args;\n" name;
	   iter_args (
	     function
	     | String name -> pr "  const char *%s;\n" name
	   ) args
      );
      pr "\n";

      (match style with
       | (_, P0) -> ()
       | (_, args) ->
	   pr "  memset (&args, 0, sizeof args);\n";
	   pr "\n";
	   pr "  if (!xdr_guestfs_%s_args (xdr_in, &args)) {\n" name;
	   pr "    reply_with_error (\"%s: daemon failed to decode procedure arguments\");\n" name;
	   pr "    return;\n";
	   pr "  }\n";
	   iter_args (
	     function
	     | String name -> pr "  %s = args.%s;\n" name name
	   ) args;
	   pr "\n"
      );

      pr "  r = do_%s " name;
      generate_call_args style;
      pr ";\n";

      pr "  if (r == %s)\n" error_code;
      pr "    /* do_%s has already called reply_with_error, so just return */\n" name;
      pr "    return;\n";
      pr "\n";

      (match style with
       | (Err, _) -> pr "  reply (NULL, NULL);\n"
      );

      pr "}\n\n";
  ) functions;

  (* Dispatch function. *)
  pr "void dispatch_incoming_message (XDR *xdr_in)\n";
  pr "{\n";
  pr "  switch (proc_nr) {\n";

  List.iter (
    fun (name, style, _, _, _) ->
      pr "    case GUESTFS_PROC_%s:\n" (String.uppercase name);
      pr "      %s_stub (xdr_in);\n" name;
      pr "      break;\n"
  ) functions;

  pr "    default:\n";
  pr "      reply_with_error (\"dispatch_incoming_message: unknown procedure number %%d\", proc_nr);\n";
  pr "  }\n";
  pr "}\n"

and generate_fish_cmds () =
  generate_header CStyle GPLv2;

  pr "#include <stdio.h>\n";
  pr "#include <stdlib.h>\n";
  pr "#include <string.h>\n";
  pr "\n";
  pr "#include \"fish.h\"\n";
  pr "\n";

  (* list_commands function, which implements guestfish -h *)
  pr "void list_commands (void)\n";
  pr "{\n";
  pr "  printf (\"    %%-16s     %%s\\n\", \"Command\", \"Description\");\n";
  pr "  list_builtin_commands ();\n";
  List.iter (
    fun (name, _, _, shortdesc, _) ->
      pr "  printf (\"%%-20s %%s\\n\", \"%s\", \"%s\");\n"
	name shortdesc
  ) functions;
  pr "  printf (\"    Use -h <cmd> / help <cmd> to show detailed help for a command.\\n\");\n";
  pr "}\n";
  pr "\n";

  (* display_command function, which implements guestfish -h cmd *)
  pr "void display_command (const char *cmd)\n";
  pr "{\n";
  List.iter (
    fun (name, style, _, shortdesc, longdesc) ->
      let synopsis =
	match style with
	| (Err, P0) -> name
	| (Err, args) ->
	    sprintf "%s <%s>"
	      name (
		String.concat "> <" (
		  map_args (function
			    | String n -> n) args
		)
	      ) in

      pr "  if (strcasecmp (cmd, \"%s\") == 0)\n" name;
      pr "    pod2text (\"%s - %s\", %S);\n"
	name shortdesc
	(" " ^ synopsis ^ "\n\n" ^ longdesc);
      pr "  else\n"
  ) functions;
  pr "    display_builtin_command (cmd);\n";
  pr "}\n";
  pr "\n";

  (* run_action function *)
  pr "int run_action (const char *cmd, int argc, char *argv[])\n";
  pr "{\n";
  List.iter (
    fun (name, style, _, _, _) ->
      pr "  if (strcasecmp (cmd, \"%s\") == 0)\n" name;
      pr "    printf (\"running %s ...\\n\");\n" name;
      pr "  else\n";
  ) functions;
  pr "    {\n";
  pr "      fprintf (stderr, \"%%s: unknown command\\n\", cmd);\n";
  pr "      return -1;\n";
  pr "    }\n";
  pr "  return 0;\n";
  pr "}\n";
  pr "\n"

(* Generate a C function prototype. *)
and generate_prototype ?(extern = true) ?(static = false) ?(semicolon = true)
    ?(single_line = false) ?(newline = false)
    ?handle name style =
  if extern then pr "extern ";
  if static then pr "static ";
  (match style with
   | (Err, _) -> pr "int "
  );
  pr "%s (" name;
  let comma = ref false in
  (match handle with
   | None -> ()
   | Some handle -> pr "guestfs_h *%s" handle; comma := true
  );
  let next () =
    if !comma then (
      if single_line then pr ", " else pr ",\n\t\t"
    );
    comma := true
  in
  iter_args (
    function
    | String name -> next (); pr "const char *%s" name
  ) (snd style);
  pr ")";
  if semicolon then pr ";";
  if newline then pr "\n"

(* Generate C call arguments, eg "(handle, foo, bar)" *)
and generate_call_args ?handle style =
  pr "(";
  let comma = ref false in
  (match handle with
   | None -> ()
   | Some handle -> pr "%s" handle; comma := true
  );
  iter_args (
    fun arg ->
      if !comma then pr ", ";
      comma := true;
      match arg with
      | String name -> pr "%s" name
  ) (snd style);
  pr ")"

let output_to filename =
  let filename_new = filename ^ ".new" in
  chan := open_out filename_new;
  let close () =
    close_out !chan;
    chan := stdout;
    Unix.rename filename_new filename;
    printf "written %s\n%!" filename;
  in
  close

(* Main program. *)
let () =
  let close = output_to "src/guestfs_protocol.x" in
  generate_xdr ();
  close ();

  let close = output_to "src/guestfs-actions.h" in
  generate_actions_h ();
  close ();

  let close = output_to "src/guestfs-actions.c" in
  generate_client_actions ();
  close ();

  let close = output_to "daemon/actions.h" in
  generate_daemon_actions_h ();
  close ();

  let close = output_to "daemon/stubs.c" in
  generate_daemon_actions ();
  close ();

  let close = output_to "fish/cmds.c" in
  generate_fish_cmds ();
  close ();

  let close = output_to "guestfs-actions.pod" in
  generate_pod ();
  close ()
