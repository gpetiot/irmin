(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open IrminCore

open Lwt
open IrminMerge.OP
open Sexplib.Std
open Bin_prot.Std

module Log = Log.Make(struct let section = "CONTENTS" end)

exception Invalid of string

module type S = sig
  include I0
  val merge: t IrminMerge.t
end

module String  = struct

  module S = String

  include S

  let merge =
    IrminMerge.default (module S)

end

module JSON = struct

  let rec encode t: Ezjsonm.t =
    match t with
    | `Null
    | `Bool _
    | `Float _  -> t
    | `String s -> JSON.encode_string s
    | `A l      -> `A (List.rev_map ~f:encode l)
    | `O l      -> `O (List.rev_map ~f:(fun (k,v) -> k, encode v) l)

  let rec decode t: Ezjsonm.t =
    match t with
    | `Null
    | `Bool _
    | `Float _
    | `String _ -> t
    | `A l      -> `A (List.rev_map ~f:decode l)
    | `O l      ->
      match JSON.decode_string t with
      | Some s -> `String s
      | None   -> `O (List.rev_map ~f:(fun (k,v) -> k, encode v) l)

  module S = I0(struct
      type t =
        [ `Null
        | `Bool of bool
        | `Float of float
        | `String of string
        | `A of t list
        | `O of (string * t) list ]
      with compare, sexp, bin_io
    end)

  include S

  let to_json = encode

  let of_json = decode

  let to_string t =
    Ezjsonm.to_string (to_json t)

  let of_string s =
    of_json (Ezjsonm.from_string s)

  (* XXX: replace by a clever merge function *)
  let merge =
    IrminMerge.(biject (module S) string of_string to_string)

end

module type STORE = sig
  include IrminStore.AO
  val merge: t -> key IrminMerge.t
  module Key: IrminKey.S with type t = key
  module Value: S with type t = value
end

module Make
    (K: IrminKey.S)
    (C: S)
    (Contents: IrminStore.AO with type key = K.t and type value = C.t)
= struct

  include Contents
  module Key  = K
  module Value = C

  let merge t =
    IrminMerge.biject' (module K) C.merge (add t) (read_exn t)

end

module Rec (S: STORE) = struct
  include S.Key
  let merge =
    let merge ~origin ~old k1 k2 =
      S.create ()  >>= fun t  ->
      IrminMerge.merge (S.merge t) ~origin ~old k1 k2
    in
    IrminMerge.create' (module S.Key) merge
end
