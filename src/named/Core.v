Set Implicit Arguments.
Set Bullet Behavior "Strict Subproofs".

Require Import List String.
Import ListNotations.
Open Scope string.
Open Scope list.
From Utils Require Import Utils.
From Named Require Import Exp ARule.

(*TODO: why does this generate warnings?*)
Import Exp.Notations.
Import ARule.Notations.

Module Notations.
  Export Exp.Notations.
  Export ARule.Notations.
End Notations.

Create HintDb lang_core discriminated.

Section TermsAndRules.
  Context (l : lang).

  (*All assume wf_lang.
    All ctxs (other than in wf_ctx) are assumed to satisfy wf_ctx.
    Judgments whose assumptions take ctxs must ensure they are wf.
    Sorts are not assumed to be wf; the term judgments should guarantee
    that their sorts are wf.
   *)
  
  Inductive le_sort : ctx -> sort -> sort -> Prop :=
  | le_sort_by : forall c name t1 t2,
      In (name, sort_le c t1 t2) l ->
      le_sort c t1 t2
  | le_sort_subst : forall c s1 s2 c' t1' t2',
      (* Need to assert wf_ctx c here to satisfy
         assumptions' presuppositions
       *)
      wf_ctx c' ->
      le_subst c c' s1 s2 ->
      le_sort c' t1' t2' ->
      le_sort c t1'[/s1/] t2'[/s2/]
  | le_sort_con : forall c name c' args s1 s2 es1 es2,
      In (name, (sort_rule c' args)) l ->
      le_args c c' s1 s2 args es1 es2 ->
      le_sort c (scon name s1) (scon name s2)
  | le_sort_trans : forall c t1 t12 t2,
      le_sort c t1 t12 ->
      le_sort c t12 t2 ->
      le_sort c t1 t2
  | le_sort_sym : forall c t1 t2, le_sort c t1 t2 -> le_sort c t2 t1
  with le_term : ctx -> sort -> exp -> exp -> Prop :=
  | le_term_subst : forall c s1 s2 c' t e1 e2,
      (* Need to assert wf_ctx c' here to satisfy
         assumptions' presuppositions
       *)
      wf_ctx c' ->
      le_subst c c' s1 s2 ->
      le_term c' t e1 e2 ->
      le_term c t[/s2/] e1[/s1/] e2[/s2/]
  | le_term_by : forall c name t e1 e2,
      In (name,term_le c e1 e2 t) l ->
      le_term c t e1 e2
  | le_term_con : forall c name c' args t s1 s2 es1 es2,
      In (name, (term_rule c' args t)) l ->
      le_args c c' s1 s2 args es1 es2 ->
      le_term c t[/with_names_from c' es2/] (con name s1) (con name s2)
  | le_term_var : forall c x t,
      In (x,t) c ->
      le_term c t (var x) (var x)
  | le_term_trans : forall c t e1 e12 e2,
      le_term c t e1 e12 ->
      le_term c t e12 e2 ->
      le_term c t e1 e2
  | le_term_sym : forall c t e1 e2, le_term c t e1 e2 -> le_term c t e2 e1
  (* Conversion:

c |- e1 = e2 : t 
               ||
c |- e1 = e2 : t'
   *)
  | le_term_conv : forall c t t',
      le_sort c t t' ->
      forall e1 e2,
        le_term c t e1 e2 ->
        le_term c t' e1 e2
  (* TODO: do I want to allow implicit elements in substitutions? *)
  (* TODO: do I want to define this in terms of le_args? *)
  with le_subst : ctx -> ctx -> subst -> subst -> Prop :=
  | le_subst_nil : forall c, le_subst c [] [] []
  | le_subst_cons : forall c c' s1 s2,
      le_subst c c' s1 s2 ->
      forall name t e1 e2,
        (* assumed because the output ctx is wf: fresh name c' ->*)
        le_term c t[/s2/] e1 e2 ->
        le_subst c ((name, t)::c') ((name,e1)::s1) ((name,e2)::s2)
  with le_args : ctx -> ctx -> list exp -> list exp -> list string -> list exp -> list exp -> Prop :=
  | le_args_nil : forall c, le_args c [] [] [] [] [] []
  | le_args_cons_ex : forall c c' s1 s2 args es1 es2,
      le_args c c' s1 s2 args es1 es2 ->
      forall name t e1 e2,
        (* assumed because the output ctx is wf: fresh name c' ->*)
        le_term c t[/with_names_from c' es2/] e1 e2 ->
        le_args c ((name, t)::c') (e1::s1) (e2::s2) (name::args) (e1::es1) (e2::es2)
  | le_args_cons_im : forall c c' s1 s2 args es1 es2,
      le_args c c' s1 s2 args es1 es2 ->
      forall name t e1 e2,
        (* assumed because the output ctx is wf: fresh name c' ->*)
        le_term c t[/with_names_from c' es2/] e1 e2 ->
        le_args c ((name, t)::c') s1 s2 args (e1::es1) (e2::es2)
  with wf_term : ctx -> exp -> sort -> Prop :=
  | wf_term_by : forall c n s args c' t,
      In (n, term_rule c' args t) l ->
      wf_args c s c' ->
      wf_term c (con n s) t[/(with_names_from c' s)/]
  | wf_term_conv : forall c e t t',
      (* We add this condition so that we satisfy the assumptions of le_sort
         TODO: necessary? not based on current judgment scheme.
         wf_term c e t should imply wf_sort c t,
         and le_sort c t t' should imply wf_sort c t


      wf_sort c t -> 
       *)
      wf_term c e t ->
      le_sort c t t' ->
      wf_term c e t'
  | wf_term_var : forall c n t,
      In (n, t) c ->
      wf_term c (var n) t
  with wf_args : ctx -> list exp -> ctx -> Prop :=
  | wf_args_nil : forall c, wf_args c [] []
  | wf_args_cons : forall c s c' name e t,
      wf_term c e t[/with_names_from c' s/] ->
      (* these arguments are last so that proof search unifies existentials
       from the other arguments first*)
      wf_args c s c' ->
      wf_args c (e::s) ((name,t)::c')
  with wf_sort : ctx -> sort -> Prop :=
  | wf_sort_by : forall c n s args c',
      In (n, (sort_rule c' args)) l ->
      wf_args c s c' ->
      wf_sort c (scon n s)
  with wf_ctx : ctx -> Prop :=
  | wf_ctx_nil : wf_ctx []
  | wf_ctx_cons : forall name c v,
      fresh name c ->
      wf_ctx c ->
      wf_sort c v ->
      wf_ctx ((name,v)::c).
  
  Inductive wf_subst c : subst -> ctx -> Prop :=
  | wf_subst_nil : wf_subst c [] []
  | wf_subst_cons : forall s c' name e t,
      (* assumed because the output ctx is wf: fresh name c' ->*)
      wf_subst c s c' ->
      wf_term c e t[/s/] ->
      wf_subst c ((name,e)::s) ((name,t)::c').

  Variant wf_rule : rule -> Prop :=
  | wf_sort_rule : forall c args,
      wf_ctx c ->
      sublist args (map fst c) ->
      wf_rule (sort_rule c args)
  | wf_term_rule : forall c args t,
      wf_ctx c ->
      wf_sort c t ->
      sublist args (map fst c) ->
      wf_rule (term_rule c args t)
  | le_sort_rule : forall c t1 t2,
      wf_ctx c ->
      wf_sort c t1 ->
      wf_sort c t2 ->
      wf_rule (sort_le c t1 t2)
  | le_term_rule : forall c e1 e2 t,
      wf_ctx c ->
      wf_sort c t ->
      wf_term c e1 t ->
      wf_term c e2 t ->
      wf_rule (term_le c e1 e2 t).
  
End TermsAndRules.
  
Hint Constructors le_sort le_term le_subst le_args
     wf_sort wf_term wf_subst wf_args wf_ctx
     wf_rule : lang_core.

Scheme le_sort_ind' := Minimality for le_sort Sort Prop
  with le_term_ind' := Minimality for le_term Sort Prop
  with le_subst_ind' := Minimality for le_subst Sort Prop
  with wf_sort_ind' := Minimality for wf_sort Sort Prop
  with wf_term_ind' := Minimality for wf_term Sort Prop
  with wf_args_ind' := Minimality for wf_args Sort Prop
  with wf_ctx_ind' := Minimality for wf_ctx Sort Prop.
Combined Scheme judge_ind
         from le_sort_ind', le_term_ind', le_subst_ind',
              wf_sort_ind', wf_term_ind', wf_args_ind',
              wf_ctx_ind'.

(*TODO: separate file for properties?*)
