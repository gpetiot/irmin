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

(** Store structured values: contents, node and commits. *)

module type STORE = sig

  type step
  type contents
  type node
  type commit
  type head

  module Step: Ir_step.S
    with type t = step

  module StepMap: Map.S
    with type key = step

  module Contents: Ir_contents.STORE
    with type value = contents

  module Node: Ir_node.STORE
    with type step = step
     and type value = node
     and module Contents = Contents
     and module Step = Step
     and module StepMap = StepMap

  module Commit: Ir_commit.STORE
    with type key = head
     and type value = commit
     and module Node = Node

end

module Make
    (C: Ir_contents.RAW_STORE)
    (N: Ir_node.RAW_STORE with type Val.contents = C.key)
    (S: Ir_commit.RAW_STORE with type Val.node = N.key):
  STORE with type step = N.Step.t
         and type contents = C.value
         and type node = N.value
         and type commit = S.value
         and type head = S.key
         and module Step = N.Step
         and module StepMap = Ir_commit.Make(C)(N)(S).Node.StepMap
         and module Contents = Ir_commit.Make(C)(N)(S).Node.Contents
         and module Node = Ir_commit.Make(C)(N)(S).Node
         and module Commit = Ir_commit.Make(C)(N)(S)
