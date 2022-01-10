From coqutil Require Import Map.Interface.
(*
TODO: implement map with tries?
Require Import Tries.Canonical.

TODO: implement map Int63 with ArrayList?

TODO: should union be here?
*)

Module Sets.

  Class set (A : Type) :=
    {
      set_as_map :> map.map A unit;
      intersection : set_as_map -> set_as_map -> set_as_map;
      union : set_as_map -> set_as_map -> set_as_map;
    }.
  Arguments set : clear implicits.
  Local Coercion set_as_map : set >-> map.map.
  
  Class ok {A} (iset : set A) :=
    {
      set_as_map_ok :> map.ok iset;
      get_intersect_same : forall (m1 m2 : iset) k,
        map.get m1 k = map.get m2 k ->
        map.get (intersection m1 m2) k = map.get m1 k;
      get_intersect_diff : forall (m1 m2 : iset) k,
        ~ (map.get m1 k = map.get m2 k) ->
        map.get (intersection m1 m2) k = None;
      get_union_left : forall (m1 m2 : iset) k,
        map.get m2 k = None ->
        map.get (union m1 m2) k = map.get m1 k;
      get_union_right : forall (m1 m2 : iset) k,
        map.get m1 k = None ->
        map.get (union m1 m2) k = map.get m2 k;
      (*TODO: rephrase proerties to be better suited to unit*)
    }.

  
  Section __.
    Context {A:Type}.
    Context {set_instance : set A}.
    Local Hint Mode map.map - - : typeclass_instances. 
    
    Definition member s (a : A) :=
      if map.get s a then true else false.

    Definition add_elt s (a : A) :=
      map.put s a tt.
    
  End __.

  (* Implements union and intersection as folds. *)
  Local Instance set_from_map {A} (m : map.map A unit) : set A :=
    {
      set_as_map := m;
      intersection m1 := map.fold (fun acc k _ => if map.get m1 k then map.put acc k tt else acc) map.empty;
      union := map.fold map.put;
    }.

End Sets.
Global Coercion Sets.set_as_map : Sets.set >-> map.map.

Require Import Utils.Monad.
(*TODO: is this the right place for this?*)
Section __.

  
  Context {A B value : Type}.
  Context {B_map : map.map B value}.
  Context {A_map : map.map A B_map}.

  
  
  Local Instance pair_map : map.map (A * B) value :=
    {
      map.rep := A_map;
      map.empty := map.empty;
      map.get m '(ka, kb) :=
      Mbind (fun mb => map.get mb kb) (map.get m ka);
      map.put m '(ka, kb) v :=
      match map.get m ka with
      | None => map.put m ka (map.singleton kb v)
      | Some mb => map.put m ka (map.put mb kb v)
      end;
      map.remove m '(ka,kb) :=
      match map.get m ka with
      | None => m
      | Some mb => map.put m ka (map.remove mb kb)
      end;
      map.fold _ f :=
        map.fold (fun acc ka mb =>
                    map.fold (fun acc kb v => f acc (ka,kb) v) acc mb)
    }.

End __.