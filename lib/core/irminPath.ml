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
open Sexplib.Std
open Bin_prot.Std

module T = I0(struct
  type t = string list with bin_io, compare, sexp
  end)

include T

let to_string t =
  "/" ^ (String.concat ~sep:"/" t)

let of_string str =
  List.filter
    ~f:(fun s -> not (String.is_empty s))
    (String.split str ~on:'/')

let pretty = to_string
let of_raw = of_string
let to_raw = to_string
let compute_from_string t = of_string t
let compute_from_bigstring s = of_string (Bigstring.to_string s)
