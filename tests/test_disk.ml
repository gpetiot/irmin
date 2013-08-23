open IrminLwt
open OUnit

let cmp_opt fn x y =
  match x, y with
  | Some x, Some y -> fn x y
  | _ -> false

let clean test_db =
  if Sys.file_exists test_db then
    let cmd = Printf.sprintf "rm -rf %s" test_db in
    let _ = Sys.command cmd in
    ()

let with_db test_db fn =
  clean test_db;
  lwt () = Disk.init test_db in
  let t = Disk.create test_db in
  try_lwt fn t
  with e ->
    raise_lwt e

let printer_opt fn = function
  | None   -> "<none>"
  | Some v -> fn v

let assert_key_equal =
  assert_equal ~cmp:Key.equal ~printer:Key.pretty

let assert_key_opt_equal =
  assert_equal ~cmp:(cmp_opt Key.equal) ~printer:(printer_opt Key.pretty)

let assert_keys_equal =
  assert_equal ~cmp:Key.Set.equal ~printer:Key.Set.pretty

let assert_value_opt_equal =
  assert_equal ~cmp:(cmp_opt Value.equal) ~printer:(printer_opt Value.pretty)

let assert_tags_equal =
  let compare_tag t1 t2 =
    String.compare (Tag.to_name t1) (Tag.to_name t2) in
  let cmp t1s t2s =
    compare (List.sort compare_tag t1s) (List.sort compare_tag t2s) = 0 in
  let printer ts =
    String.concat ", " (List.map Tag.pretty ts) in
  assert_equal ~cmp ~printer

let test_values () =
  let v1 = Value.blob "foo" in
  let v2 = Value.blob "" in
  let test_db = "test-db" in
  let module DV = Disk.Value_store in
  let test t =
    lwt k1 = DV.write t v1 in
    lwt k1' = DV.write t v1 in
    lwt k2 = DV.write t v2 in
    lwt k2' = DV.write t v2 in
    lwt v1' = DV.read t k1 in
    lwt v2' = DV.read t k2 in
    assert_key_equal k1 k1';
    assert_key_equal k2 k2';
    assert_value_opt_equal (Some v1) v1';
    assert_value_opt_equal (Some v2) v2';
    Lwt.return ()
  in
  Lwt_unix.run (with_db test_db test)

let test_keys () =
  let k1 = Value.key (Value.blob "foo") in
  let k2 = Value.key (Value.blob "") in
  let k1s = Key.Set.singleton k1 in
  let k2s = Key.Set.singleton k2 in
  let test_db = "test-db" in
  let module KV = Disk.Key_store in
  let test t =
    lwt () = KV.add t k1 k2s in
    lwt k1s' = KV.succ t k2 in
    lwt k2s' = KV.pred t k1 in
    lwt ks = KV.list t in
    assert_keys_equal k1s k1s';
    assert_keys_equal k2s k2s';
    assert_keys_equal (Key.Set.of_list ks) (Key.Set.union k1s k2s);
    Lwt.return ()
  in
  Lwt_unix.run (with_db test_db test)

let test_tags () =
  let k1 = Value.key (Value.blob "foo") in
  let k2 = Value.key (Value.blob "") in
  let t1 = Tag.of_name "foo" in
  let t2 = Tag.of_name "bar" in
  let test_db = "test-db" in
  let module KT = Disk.Tag_store in
  let test t =
    lwt () = KT.update t t1 k1 in
    lwt () = KT.update t t2 k2 in
    lwt k1' = KT.read t t1 in
    lwt k2' = KT.read t t2 in
    assert_key_opt_equal (Some k1) k1';
    assert_key_opt_equal (Some k2) k2';
    lwt () = KT.update t t1 k2 in
    lwt k2'' = KT.read t t1 in
    assert_key_opt_equal (Some k2) k2'';
    lwt l = KT.list t in
    assert_tags_equal l [t1; t2];
    lwt () = KT.remove t t1 in
    lwt none = KT.read t t1 in
    assert_key_opt_equal None none;
    lwt l = KT.list t in
    assert_tags_equal l [t2];
    Lwt.return ()
  in
  Lwt_unix.run (with_db test_db test)


let suite =
  "disk" >:::
    ["Basic disk operations for values" >:: test_values;
     "Basic disk operations for keys"   >:: test_keys;
    ]

let _ =
  run_test_tt_main suite
