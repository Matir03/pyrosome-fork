(*
  Implementation based on Egg: https://dl.acm.org/doi/pdf/10.1145/3434304
*)
Set Implicit Arguments.
Set Bullet Behavior "Strict Subproofs".

Require Import Bool String List Orders ZArith.
Import ListNotations.
Open Scope string.
Open Scope list.
(*TODO: link coqutil
From coqutil Require Import Map.Interface.
From coqutil Require Map.SortedList.*)
From Utils Require Import Utils PersistentArrayList UnionFind Natlike.
From Named Require Import Term.
(*Import Core.Notations.*)

Require MSets.

(*TODO: eqb from natlike *)
#[refine]
 Instance eqb_natlike A `{Ops.NatlikeOps A} : Eqb A :=
  {|
    eqb := Ops.eqb
  |}.
Proof.
Admitted.
    


(*TODO: parameterize by ArrayList impl;
  depends on UnionFind coq bug
 *)
Import Int63.
Import OrdersEx.

(*TODO: move anything not touching terms or nodes to utils, nodes to sep. file*)

(*TODO: is this defined anywhere?*)
Module ListDecidableType(D :DecidableType) <: DecidableType.

  Definition t := list D.t.

  Definition eq := Forall2 D.eq.

  #[global]
   Instance eq_equiv : Equivalence eq.
  Proof.
    unfold eq.
    repeat constructor.
    {
      intro l; induction l;
        constructor; eauto.
      apply D.eq_equiv.
    }
    {
      intro l; induction l;
      inversion 1;
      constructor; eauto;
      subst.
      apply D.eq_equiv; auto.
    }
    {
      intro l; induction l;
      inversion 1;
      inversion 1;
      subst;
      constructor; eauto.
      destruct D.eq_equiv as [_ _ Dtrans];
        eapply Dtrans; eauto.
    }
  Qed.  

 Definition eq_dec : forall x y, { eq x y }+{ ~eq x y }.
 Proof.
   unfold eq.
   induction x; destruct y; eauto.
   1,2: right; inversion 1.
   destruct (D.eq_dec a t0);
     destruct (IHx y).
   {
     intuition.
   }
   all: right; inversion 1; subst; auto.
 Defined.
 
End ListDecidableType.

Module ListOrderedType(O:OrderedType) <: OrderedType.
  Include ListDecidableType O.

  Definition lt : t -> t -> Prop. Admitted.

  #[global]
   Instance lt_strorder : StrictOrder lt.
  Proof.
  Admitted.

  #[global]
   Instance lt_compat : Proper (eq==>eq==>iff) lt.
  Proof.
  Admitted.

  Fixpoint compare x y :=
    match x, y with
    | [], [] => Eq
    | [], _ => Lt
    | _, [] => Gt
    | (a::x), (b::y) =>
      match O.compare a b with
      | Eq => compare x y
      | Lt => Lt
      | Gt => Gt
      end
    end.

 Lemma compare_spec : forall x y, CompSpec eq lt x y (compare x y).
 Proof.
 Admitted.

End ListOrderedType.

Fixpoint list_ltb {A} (ltb : A -> A -> bool) (a b : list A) : bool :=
    match a,b with
    | [], [] => false
    | [], _ => true
    | _, [] => false
    | (a::x), (b::y) =>
      (ltb a b) && (list_ltb ltb x y)
    end.

Module IntListOT := ListOrderedType Int63Natlike.

(*Define aliases for int so that at least the type annotations are more descriptive*)
Definition var_idx := int.
Definition constr_idx := int.
Definition srt_idx := int.
Definition ctx_idx := int.
Definition tm_idx := int.

(*TODO: use string -> int mapping to convert lang, ctx so that the egraph
  does not store strings
*)
Variant enode :=
(*TODO: look into efficient ways to optimize empty if looking for a little performance(null?)*)
| ctx_empty_node : enode
| ctx_cons_node : (*context length*) N -> var_idx -> srt_idx -> ctx_idx -> enode
| con_node : constr_idx ->  list tm_idx -> enode
| scon_node : constr_idx -> list tm_idx -> enode
| var_node : var_idx -> enode.


Axiom TODO: forall {A}, A.
Module ENode <: OrderedType.
  (*TODO: have separate scon node or optional type?*)

  Definition t := enode.

  (*TODO
  Definition eq n1 n2 :=
    match n1, n2 with
    | ctx_empty_node, ctx_empty_node => true
    | ctx_cons_node var1 srt1 tl1, ctx_cons_node var2 srt2 tl2 => 
    | con_node : string -> (*ctx *) int -> (*sort*) int -> list int -> enode
    | acon_node : string -> (*ctx *) int -> list int -> enode
    | var_node : string -> (*ctx *) int -> (*sort*) int -> enode.
      

  Definition ltb '(n1, args1) '(n2,args2) :=
    (String.ltb n1 n2) && (list_ltb Int63.ltb args1 args2).
   *)

  Definition eq := @eq t.
  Definition eq_equiv : Equivalence eq := TODO.
  Definition lt : t -> t -> Prop := TODO.

  #[global]
   Instance lt_strorder : StrictOrder lt.
  Proof.
  Admitted.

  #[global]
   Instance lt_compat : Proper (eq==>eq==>iff) lt.
  Proof.
  Admitted.

  Definition compare : t -> t -> comparison := TODO.

  Lemma compare_spec : forall x y, CompSpec eq lt x y (compare x y).
  Proof.
  Admitted.
  
  Definition eq_dec : forall x y, { eq x y }+{ ~eq x y }.
  Proof.
  Admitted.

  Definition ltb : t -> t -> bool.
  Admitted.
    
End ENode.


Module NodeSets := MSets.MSetAVL.Make ENode.

(*
Module Parents := PairOrderedType ENode Int63Natlike.
Module ParentSets := MSets.MSetAVL.Make Parents.
*)


Module Int63Map.
  (* Make this an instance so we can use single-curly-braces so we don't need to qualify field-names with [SortedList.parameters.] *)
  Import Int63Natlike.
  Local Instance int63_strict_order: @SortedList.parameters.strict_order _ ltb.
  {
    constructor.
    {
      intros.
      rewrite <- not_true_iff_false.
      rewrite ltb_lt.
      int_lia.
    }
    {
      intros.
      rewrite ltb_lt in *.
      int_lia.
    }
    {
      intros.
      rewrite <- not_true_iff_false in *.
      rewrite ltb_lt in *.
      int_lia.
    }
  }
  Qed.
  
  Definition Build_parameters T :=
    SortedList.parameters.Build_parameters _ T ltb.
  
  Definition map T := SortedList.map (Build_parameters T) int63_strict_order.

  Definition ok T : @Interface.map.ok _ T (map T).
    pose proof @SortedList.map_ok (Build_parameters T) as H; eapply H.
  Qed.
  
End Int63Map.


  (*TODO: representation choice: each eclass should only need a single sort, ctx
    currently, each enode has them.
    Fix?
    Related: Do I want one eclass per context for closed terms like 'true'?
    or one eclass for all things equal to 'true'?
    The latter doesn't seem sound, but the former might be a bit expensive
    Related: how to work w/ meta-level substitutions in egraphs?

    Optimal solution prob. involves special treatment/eqns for metavar substs
   *)

Module ENodeMap.
  (* Make this an instance so we can use single-curly-braces so we don't need to qualify field-names with [SortedList.parameters.] *)
  Import ENode.
  Local Instance enode_strict_order: @SortedList.parameters.strict_order _ ENode.ltb.
  Admitted (*TODO: use existing strorder?*).
  
  Definition Build_parameters T :=
    SortedList.parameters.Build_parameters _ T ltb.
  
  Definition map T := SortedList.map (Build_parameters T) enode_strict_order.

  Definition ok T : @Interface.map.ok _ T (map T).
    pose proof @SortedList.map_ok (Build_parameters T) as H; eapply H.
  Qed.
  
End ENodeMap.

Instance hashcons_ty : Interface.map.map ENode.t Int63Natlike.t := ENodeMap.map _.

(* TODO : could split off ctx classes here or even further (a separate pool)
   since they behave differently (no direct eqns, only unified as parents of subterms).
   Think about efficiency
*)
Record eclass : Type :=
  MkEClass {
      nodes : NodeSets.t;
      parents : ENodeMap.map Int63Natlike.t;
      (* value is unused if the class represents a ctx
         TODO: is this the best way?
       *)
      ectx : int;
      (* value is unused if the class represents a ctx or sort
         TODO: is this the best way?
       *)
      esrt : int;
    }.

Module EClass.

  (* Include a parent map in each eclass *)
  Definition t : Type := eclass.

  (*Definition union '(ns1,ps1) '(ns2,ps2) : t :=
    (NodeSets.union ns1 ns2, (*TODO: need map union?*)map.union ps1 ps2).*)

  Definition empty ctx srt : t :=
    MkEClass NodeSets.empty map.empty ctx srt.

  (* Assumes no parents *)
  Definition singleton n ctx srt : t := 
    MkEClass (NodeSets.singleton n) map.empty ctx srt.

  Definition add_parent '(MkEClass ns ps ntx nsrt) '(pn,pi) : t :=
    MkEClass ns (map.put ps pn pi) ntx nsrt.
  
End EClass.


Instance eclass_map_ty : Interface.map.map Int63Natlike.t EClass.t := Int63Map.map _.

Module UF := CBVUnionFind.

Record egraph :=
  MkEGraph {
      id_equiv : UF.M.union_find;
      eclass_map : Int63Map.map EClass.t;
      hashcons : ENodeMap.map Int63Natlike.t;
      worklist : list Int63Natlike.t
  }.

Require Import Utils.Monad.

Definition ST S A := S -> (S * A).

Instance state_monad {S} : Monad (ST S) :=
  {
  Mret _ a := fun s => (s,a);
  Mbind _ _ f ma :=
    fun s =>
      let (s,a) := ma s in
      f a s
  }.

Section MonadListMap.
  Context {M A B} `{Monad M}
          (f : A -> M B).

  Fixpoint list_Mmap (l : list A) : M (list B) :=
    match l with
    | [] => do ret []
             | a::al' =>
               do let b <- f a in
                  let bl' <- list_Mmap al' in
                  ret (b::bl')
                  end.
End MonadListMap.
       
Fixpoint list_Miter {M A} `{Monad M} (f : A -> M unit) (l : list A) : M unit :=
  match l with
  | [] => do ret tt
  | a::al' =>
    do let b <- f a in
       let tt <- list_Miter f al' in
       ret tt
       end.

Definition unwrap_with_default {A} (default : A) ma :=
  match ma with None => default | Some a => a end.


Definition map_Mfold {S K V A}
           {MP : map.map K V}
           (f : K -> V -> A -> ST S A)
           (p : @map.rep _ _ MP) a : ST S A :=
  fun g =>
    map.fold
      (fun '(g, a) k v => f k v a g)
      (g, a) p.

Definition map_Miter {S K V}
           {MP : map.map K V}
           (f : K -> V -> ST S unit)
           (p : @map.rep _ _ MP) : ST S unit :=
  map_Mfold (fun k v _ => f k v) p tt.

(*TODO: double check this is the right name*)
(* backtracks the state if ma returns None *)       
Definition try_with_backtrack {S A B}
           (ma : ST S (Option A)) : ST S (Option A) :=
  fun g =>
    match ma g with
    | (g', Some a) => (g', Some a)
    | (_, None) => (g, None)
    end.

  
       
Section EGraphOps.

  Local Notation "'ST'" := (ST egraph).


  Definition find a : ST int :=
    fun '(MkEGraph U M H W) =>
      let (U, i) := UF.find U a in
      (MkEGraph U M H W,i).

  Definition alloc : ST int :=
    fun '(MkEGraph U M H W) =>
      let (U, i) := UF.M.alloc U in
      (MkEGraph U M H W,i).

  Definition hashcons_lookup (n : ENode.t) : ST (option int) :=
    fun g =>
      let mi := map.get g.(hashcons) n in
      (g, mi).

  Definition set_hashcons n i : ST unit :=
    fun '(MkEGraph U M H W) =>
      let H := map.put H n i in
      (MkEGraph U M H W,tt).
  
  Definition remove_hashcons n : ST unit :=
    fun '(MkEGraph U M H W) =>
      let H := map.remove H n in
      (MkEGraph U M H W,tt).
  
  Definition set_eclass (i: int) (c : EClass.t) : ST unit :=
    fun '(MkEGraph U M H W) =>
      let M := map.put M i c in
      (MkEGraph U M H W,tt).

  Definition union_ids a b : ST int :=
    fun '(MkEGraph U M H W) =>
      let (U, i) := UF.union U a b in
      (MkEGraph U M H W, i).

  (* return a default value rather than none
     for ease-of-use
   *)
  Definition get_eclass (i : int) : ST EClass.t :=
    (*TODO: using a meaningless default here.
      Decide if an option is better.
      If I want empty as the default,
      I need to decide that ctx and srt don't matter if empty,
      which seems wrong
     *)
    fun g => (g, unwrap_with_default (EClass.empty 0 0) (map.get g.(eclass_map) i)).

  Definition add_to_worklist (i : int) : ST unit :=
    fun '(MkEGraph U M H W) =>
      let W := i::W in
      (MkEGraph U M H W, tt).

  (* Returns the worklist for iteration and removes it from the egraph *)
  Definition pull_worklist : ST (list int) :=
    fun '(MkEGraph U M H W) =>
      (MkEGraph U M H [], W).
  
  Definition is_worklist_empty : ST bool :=
    fun g => (g, match g.(worklist) with [] => true | _ => false end).    

  (*adds (n,p) as a parent to i*)
  Definition add_parent n p i : ST unit :=
    do let ci : EClass.t <- get_eclass i in
       (set_eclass i (EClass.add_parent ci (n,p))).
       
  Definition canonicalize n : ST ENode.t :=
    match n with
    | ctx_empty_node => do ret ctx_empty_node
    | ctx_cons_node n x srt tl =>
      do let srt <- find srt in
         let tl <- find tl in
         ret ctx_cons_node n x srt tl      
    | con_node name args =>
      do let args <- list_Mmap find args in       
         ret con_node name args     
    | scon_node name args =>
      do let args <- list_Mmap find args in       
         ret scon_node name args
    | var_node x =>
      do ret var_node x
    end.

         
  Definition eqb_ids a b : ST bool :=
    do let fa <- (find a) in
       let fb <- (find b) in
       ret eqb fa fb.

       
  Definition lookup n : ST (option int) :=
    do let n <- canonicalize n in
       (hashcons_lookup n).

  Definition add_parent_to_children n i : ST unit :=
    match n with
    | ctx_empty_node => do ret tt
    | ctx_cons_node _ x srt tl =>
      do let tt <- add_parent n i srt in
         let tt <- add_parent n i tl in
         ret tt     
    | con_node name args =>
      do let args <- list_Miter (add_parent n i) args in
         ret tt
    | scon_node name args =>
      do let args <- list_Miter (add_parent n i) args in
         ret tt
    | var_node x => do ret tt
    end.

  (* Does not check that the ctx and srt are correct if n already exists
     TODO: generalize this and 2 sim. fns?
   *)
  Definition add_term (n : ENode.t) (ctx srt : int) : ST int :=
    do let mn <- lookup n in
       match mn with
       | Some i => do ret i
       | None => 
         do let i <- alloc in
            let tt <- set_eclass i (EClass.singleton n ctx srt) in
            let tt <- add_parent_to_children n i in
            let tt <- add_parent n i srt in
            let tt <- add_parent n i ctx in
            let tt <- set_hashcons n i in
            ret i
            end.

  
  Definition add_ctx (n : ENode.t) : ST int :=
    do let mn <- lookup n in
       match mn with
       | Some i => do ret i
       | None => 
         do let i <- alloc in
            let tt <- set_eclass i (EClass.singleton n 0 0) in
            let tt <- add_parent_to_children n i in
            let tt <- set_hashcons n i in
            ret i
            end.
            
  Definition add_sort (n : ENode.t) ctx : ST int :=
    do let mn <- lookup n in
       match mn with
       | Some i => do ret i
       | None => 
         do let i <- alloc in
            let tt <- set_eclass i (EClass.singleton n ctx 0) in
            let tt <- add_parent_to_children n i in
            let tt <- add_parent n i ctx in
            let tt <- set_hashcons n i in
            ret i
            end.

  Definition merge (a b : int) : ST int :=
    do let ca <- find a in
       let cb <- find b in
       if eqb ca cb
       then ret ca
       else let i <- union_ids a b in
            let tt <- add_to_worklist i in
            ret i.

       (*TODO: put in  Monad.v*)
       Definition seq {M} `{Monad M} {A B} (mu : M A) (ma : M B) : M B :=
         Mbind (fun _ => ma) mu.

       Notation "e1 ; e2" :=
         (seq e1 e2)
           (in custom monadic_do at level 100, left associativity,
               e1 custom monadic_do,
               e2 custom monadic_do).


       (*TODO: generalize, put in Monad.v*)
       Notation "'for' kp vp 'from' m 'in' b" :=
         (*TODO: remove need for explicit instance*)
         (map_Miter (MP:=hashcons_ty) (fun kp vp => b) m)                       
           (in custom monadic_do at level 200, left associativity,
               kp pattern at level 0,
               vp pattern at level 0,
               m constr, b custom monadic_do).
       
       Notation "'for/fold' kp vp 'from' m [[ acc := a ]] 'in' b" :=
         (*TODO: remove need for explicit instance*)
         (map_Mfold (MP:=hashcons_ty) (fun kp vp acc => b) a m)                       
           (in custom monadic_do at level 200, left associativity,
               kp pattern at level 0,
               vp pattern at level 0,
               acc pattern at level 0,
               m constr, b custom monadic_do).

  (*TODO: use coq-record-update?*)
  Definition set_class_parents '(MkEClass ns _ ntx nsrt) ps :=
    MkEClass ns ps ntx nsrt.

  (*TODO: think about parents wrt srt, ctx
    if c |- e : t, then e is a parent of c, t
    need to set those somewhere
   *)
  Definition repair i : ST unit :=
    do let c <- get_eclass i in
       let tt <- do for pn pi from c.(parents) in
                 let tt <- remove_hashcons pn in
                 let pn <- canonicalize pn in
                 let ci <- find pi in
                 (set_hashcons pn ci) in
       let new_parents <- do for/fold pn pi from c.(parents)
                                [[new_parents := (map.empty : hashcons_ty)]] in
                          let pn <- canonicalize pn in
                          match map.get new_parents pn : option int return ST map.rep with
                          | Some np => seq (merge pi np) (do ret new_parents)
                          | None =>
                            do let ci <- find pi in
                               ret (map.put new_parents pn ci)
                          end in
       (set_eclass i (set_class_parents c new_parents)).

  Definition rebuild_aux : N -> ST unit :=
    N.recursion
      (Mret tt)
      (fun _ rec =>
         do let (is_empty : bool) <- is_worklist_empty in
            if is_empty then ret tt
            else
              let tt <- rec in
              let W <- pull_worklist in
              (*TODO: should worklist and/or cW be a set? Egg has a dedup step.
                For now we are not deduplicating here, but we probably should at some point
               *)
              let cW <- list_Mmap find W in
              (list_Miter repair cW)).
                               
  (* TODO: need to track  I = ~=\=_node to use as fuel
   *)
  Definition rebuild : ST unit :=
    do let incong_bound := 100 in
       (rebuild_aux 100).

  (* TODO: is it worth using a more efficient structure?
     If we assume that the max length is ~10, maybe not
   *)
  Definition esubst := list (int*int).
  Definition match_result := list (esubst * EClass.t).

  

  (*Used as an intermediate form in equality saturation *)
  Unset Elimination Schemes.
  (*TODO: parameterize; replace int with Idx.t*)
  Inductive eterm : Set :=
  (* variable name *)
  | evar : int -> eterm
  (* Rule label, list of subterms*)
  | econ : int -> list eterm -> eterm
  (* reference to an existing node in the egraph *)
  | eref : int -> eterm.
  Set Elimination Schemes.


  (* TODO: zero is a questionable default unless I implement null idea*)
  Fixpoint esubst_lookup (s : esubst) (n : int) : int :=
    match s with
    | [] => 0%int63
    | (s', v)::l' =>
      if eqb n s' then v else esubst_lookup l' n
    end.

  Arguments esubst_lookup !s n/.

  Import Int63Term.
  (*TODO: take in an actual map for constr_map?*)
  Fixpoint to_eterm (e : term) : eterm :=
    match e with
    | var x => evar x
    | con n s => econ n (map to_eterm s)
    end.

  Arguments to_eterm !e /.

  (* TODO: should I work out how to apply substs to refs?
     necessary if e can be an eterm
   *)
  Fixpoint eterm_subst (s : esubst) (e : term) : eterm :=
    match e with
    | var x => eref (esubst_lookup s x)
    | con n s' =>
      econ n (map (eterm_subst s) s')
    end.

  Arguments eterm_subst s !e /.

  
  Definition lookup_sort (tm : int) : ST int :=
    do let c <- get_eclass tm in
       ret c.(esrt).
       
  Definition lookup_ctx (tm : int) : ST int :=
    do let c <- get_eclass tm in
       ret c.(ectx).


  Definition lookup_sort_in_ctx'
            (rec : ctx_idx -> var_idx -> ST (option srt_idx))
            (ctx : ctx_idx)
            (x : var_idx) : ST (option srt_idx) :=
    do let c <- get_eclass ctx in
       match NodeSets.choose c.(nodes) with
       | Some (ctx_cons_node _ x' srt tl) =>
         if eqb x x' then do ret Some srt
         else rec tl x
       | _ => do ret None
       end.

  (*TODO: try to collapse 2 defs*)
  Definition lookup_sort_in_ctx (ctx x : int) : ST (option srt_idx) :=
    do let c <- get_eclass ctx in
       match NodeSets.choose c.(nodes) with
       | Some (ctx_cons_node n x' srt tl) =>
         if eqb x x' then do ret Some srt
         else N.recursion (fun _ _ => do ret None) (fun _ => lookup_sort_in_ctx') n tl x
       | _ => do ret None
       end.       

  (*TODO: want this to be fast.
    Build lang into egraph?
    identify c w/ term c[/id/] and do regular lookup?
    how to know the arity of id though?
    middle option: "lang" is already compiled, just another node type?
    what to do with equivalence rules then? drop? need to remember at least the names
   *)
  Definition get_term_ctx_and_sort (l : lang) (c : constr_idx) : option (ctx*sort) :=
    match named_list_lookup_err l c with
    | Some (term_rule c t

  (* assumes that the context and sort have already been added *)
  (* TODO: think about read/write separation & invariants *)
  (* TODO: needs lang as input to generate the sort *)
  Fixpoint add_eterm_no_check lang (ctx (*srt*): int) (e : eterm) : ST (option int) :=
    match e with
    | evar x =>
      do let srt <- lookup_sort_in_ctx ctx x in
         (add_term (var_node x) ctx srt)
    | econ n s =>
      (*TODO: generalize list_Mmap to composition of ST and option.
        Requires monad transformers to be nice
       *)
      do let margs <- list_Mmap add_eterm s in
         let srt <- 
         match List.option_all margs with
         | Some args =>
           (*TODO: check wfness of top-level constructor here*)
           (*TODO: think about what needs to be canonicalized here *)
           (add_term (con_node n args) ctx srt)
         | None => None
         end
    | eref i => do ret i
   end.

                                                                             
  (* assumes that the context and sort have already been added *)
  (* TODO: think about read/write separation & invariants;
     have it return a list of sort equations to prove and backtrack if they fail?
     hard to do that though since egraph won't be 'good'.
     Generate equations first? traversing the term is cheap
     ^ TODO: do this
   *)
  (*TODO: does this need to take an eterm? *)
  Fixpoint check_and_add_eterm (ctx (*srt*): int) (e : eterm) : ST (option int) :=
    match e with
    | evar x =>
      do let srt <- lookup_sort_in_ctx ctx x in
         (add_term (var_node x) ctx srt)
      (*TODO: need to look up sort
       and check, if srt is provided*)
      add (var_node x ctx srt)
    | econ n s =>
      (*TODO: generalize list_Mmap to composition of ST and option.
        Requires monad transformers to be nice
       *)
      do let margs <- list_Mmap add_eterm s in
         match List.option_all margs with
         | Some args =>
           (*TODO: check wfness of top-level constructor here*)
           (*TODO: think about what needs to be canonicalized here *)
           (add_term (con_node n args) ctx srt)
           (add (con_node n ctx srt)
         | None => None
         end
    | eref i => (*TODO: check? only if srt provided. write sep. helper?*) do ret i
    end.
                       
  Axiom TODO : forall {A}, A.


  (*TODO: how to treat type info on vars? *)
  (*TODO: use sections earlier to make list_Mmap termination check work *)
  (*TODO: a larget effort to implement, move to sep file*)
  Fixpoint ematch (e : term) : ST match_result :=
    match e with
    | var x => TODO
    | con n s =>
      do let ematch_s <- list_Mmap ematch s in
         TODO
         end.


                                    
         (*Queries I want in the end:*)

         (* uses egraph saturate_and_compare_eq to determine equivalences,
            checks wfness of each subterm, and adds if wf

            w/ this API, ctx nodes seem reasonable
          *)
         Parameter add_and_check_wf_term : lang -> ctx -> term -> ST (option int).
         Parameter add_and_check_wf_sort : lang -> ctx -> term -> ST (option int).
         Parameter get_term : int -> ST (option term).
         Parameter get_ctx_of_term : int -> ST (option ctx).
         Parameter get_sort_of_term : int -> ST (option sort).
         Parameter get_sort : int -> ST (option sort).

         (* one of these two *)
         Parameter saturate : lang -> ST unit.
         Parameter saturate_until_eq : lang -> int -> int -> ST bool.

         (* assumes saturation *)
         Definition compare_eq l i1 i2 : ST bool :=
           do let ci1 <- find i1 in
              let ci2 <- find i2 in
              ret (eqb i1 i2).

              
(*critical properties*)

(*TODO: need to carry a subst*)
(* basic idea: parallel to core? *)
Inductive egraph_matches_term
          (g : egraph) (s : named_list V term)
          (ep e : term) t : Prop :=
| egraph_contains_var : 
  In (i,e) s ->
  (*in_egraph g t = true ->*)
  egraph_sort_of g e t ->
  egraph_contains_term g (var i) e t.

(*Prove for empty egraph, each operation preserves*)
Definition egraph_sound_in_lang g l :=
  (forall c t, in_egraph_sort g c t = true ->
               wf_sort l c t)...
  /\(forall c t, eq_egraph_sort g c t1 t2 = true ->
               eq_sort l c t1 t2)...

Definition ematch_term_sound g : Prop :=
  forall c e t c' s,
    In (c',s) (set_map (materialize g) (ematch g c e t)) ->
    in_egraph g c' e[/s/] t[/s/] = true.
(*corollary: 
  egraph_sound_in_lang g l ->
  wf_subst l c' s c *)
