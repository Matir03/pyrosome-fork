
Require Import String Lists.List.
Import ListNotations.
Open Scope string.
Open Scope list.
From Utils Require Import Utils SymmetricInduction.
From Pyrosome.Theory Require Import Core.

Module Notations.
  Export Term.Notations.
  Export Rule.Notations.
End Notations.
Import Notations.


(*TODO: move to Utils*)
Lemma fresh_with_names_from [V' A B] v (c' : @NamedList.named_list V' A) (s : list B)
  : Datatypes.length c' = Datatypes.length s -> fresh v (with_names_from c' s) = fresh v c'.
Proof.
  intros.
  unfold fresh.
  basic_utils_crush.
Qed.
Hint Rewrite fresh_with_names_from : utils.


(*TODO: move to Rule.v*)
Local Ltac use_rule_in_ws :=
  match goal with
  | H:ws_lang ?l, Hin:In (_, _) ?l |- _ => pose proof (rule_in_ws _ _ H Hin)
  end.


Section WithVar.
  Context (V : Type)
    {V_Eqb : Eqb V}
    {V_Eqb_ok : Eqb_ok V_Eqb}
    {V_default : WithDefault V}.

  Notation named_list := (@named_list V).
  Notation named_map := (@named_map V).
  Notation term := (@term V).
  Notation var := (@var V).
  Notation con := (@con V).
  Notation ctx := (@ctx V).
  Notation sort := (@sort V).
  Notation subst := (@subst V).
  Notation rule := (@rule V).
  Notation lang := (@lang V).


(*TODO: move to term*)
Lemma ws_subst_from_ws_args args (c' : ctx) (s : list term)
  : length c' = length s ->
    all_fresh c' ->
    well_scoped args s ->
    well_scoped args (with_names_from c' s).
Proof.
  revert c'; induction s;
    destruct c';
    basic_goal_prep;
    basic_term_crush.
  eapply IHs; eauto.
Qed.
Hint Resolve ws_subst_from_ws_args : lang_core.


  (*TODO: move to Term *)
  Lemma term_ws_incl (t:term) args args'
    : well_scoped args t ->incl args args' -> well_scoped args' t.
  Proof.
    induction t;
      basic_goal_prep;
      basic_term_crush.
    revert dependent l;
      induction l;
      basic_goal_prep;
      basic_term_crush.
  Qed.
  
  Lemma sort_ws_incl (t:sort) args args'
    : well_scoped args t ->incl args args' -> well_scoped args' t.
  Proof.
    destruct t.
    revert dependent l;
      induction l;
      basic_goal_prep;
      basic_term_crush.
    eapply term_ws_incl; eauto.
  Qed.

  
  Lemma ws_ctx_in c n t
    : ws_ctx c -> In (n,t) c -> well_scoped (map fst c) t.
  Proof.
    induction c;
      basic_goal_prep;
      basic_term_crush.
    all:eapply sort_ws_incl; eauto.
    all: basic_utils_crush.
  Qed.
  Hint Resolve ws_ctx_in : lang_core.


  Notation PreModel := (@PreModel V term sort).

  
  #[export] Instance syntax_model : PreModel :=
    {|
      term_substable := _;
      sort_substable := _;
    |}.

  
Local Notation mut_mod eq_sort eq_term wf_sort wf_term :=
  {|
    premodel := syntax_model;
      (*TODO: rename the conflict*)
      Model.eq_sort := eq_sort;
      (*TODO: rename the conflict*)
      Model.eq_term := eq_term;
      Model.wf_sort := wf_sort;
      Model.wf_term := wf_term;
    |}.

Section Terms.
  Context (l : lang).

  Section WithCtx.
  Context (c : ctx).

  (*All assume wf_lang.
    All ctxs (other than in wf_ctx) are assumed to satisfy wf_ctx.
    Judgments whose assumptions take ctxs must ensure they are wf.
    Sorts are not assumed to be wf; the term judgments should guarantee
    that their sorts are wf.
   *)

  (* TODO: equations can be independent of wfness in this formulation.
     This means that eq_subst/eq_args don't need the full model.
     Currently have them duplicated, but ideally the ones in Model.v
     could be generalized to be usable here.
   *)
  Inductive eq_sort : sort -> sort -> Prop :=
  | eq_sort_by : forall name c' t1 t2 s1 s2,
      In (name, sort_eq_rule c' t1 t2) l ->
      eq_subst c' s1 s2 ->
      eq_sort t1[/s1/] t2[/s2/]
  | eq_sort_cong : forall name c' args s1 s2,
      In (name,sort_rule c' args) l ->
      eq_args c' s1 s2 ->
      eq_sort (scon name s1) (scon name s2)
  | eq_sort_trans : forall t1 t12 t2,
      eq_sort t1 t12 ->
      eq_sort t12 t2 ->
      eq_sort t1 t2
  | eq_sort_sym : forall t1 t2, eq_sort t1 t2 -> eq_sort t2 t1
  with eq_term : sort -> term -> term -> Prop :=
  | eq_term_by : forall name c' t e1 e2 s1 s2,
      In (name,term_eq_rule c' e1 e2 t) l ->
      eq_subst c' s1 s2 ->
      eq_term t[/s2/] e1[/s1/] e2[/s2/]
  | eq_term_cong : forall name c' args t s1 s2,
      In (name,term_rule c' args t) l ->
      eq_args c' s1 s2 ->
      eq_term t[/(with_names_from c' s2)/] (con name s1) (con name s2)
  | eq_term_var : forall n t,
      In (n, t) c ->
      eq_term t (var n) (var n)
  | eq_term_trans : forall t e1 e12 e2,
      eq_term t e1 e12 ->
      eq_term t e12 e2 ->
      eq_term t e1 e2
  | eq_term_sym : forall t e1 e2, eq_term t e1 e2 -> eq_term t e2 e1
  (* Conversion:

c |- e1 = e2 : t 
               ||
c |- e1 = e2 : t'
   *)
  | eq_term_conv : forall e1 e2 t t',
      eq_term t e1 e2 ->
      eq_sort t t' ->
      eq_term t' e1 e2
  with eq_subst : ctx -> subst -> subst -> Prop :=
  | eq_subst_nil : eq_subst [] [] []
  | eq_subst_cons : forall (c' : ctx) (s1 s2 : subst),
                    eq_subst c' s1 s2 ->
                    forall (name : V) (t : sort) (e1 e2 : term),
                    eq_term t [/s2 /] e1 e2 ->
                    eq_subst ((name, t) :: c') ((name, e1) :: s1)
                      ((name, e2) :: s2)
  with eq_args : ctx -> list term -> list term -> Prop :=
  | eq_args_nil : eq_args [] [] []
  | eq_args_cons : forall (c' : ctx) (es1 es2 : list term),
      eq_args c' es1 es2 ->
      forall (name : V) (t : sort) (e1 e2 : term),
        eq_term t [/with_names_from c' es2 /] e1 e2 ->
        eq_args ((name, t) :: c') (e1 :: es1) (e2 :: es2).                

  
  (* TODO: do I need these? make notations for reflexivity
  Inductive wf_term : ctx -> term -> sort -> Prop :=
  | wf_term_by : forall c n s args c' t,
      In (n, term_rule c' args t) l ->
      wf_args (Model:= mut_mod eq_sort eq_term wf_sort wf_term) c s c' ->
      wf_term c (con n s) t[/(with_names_from c' s)/]
  | wf_term_conv : forall c e t t',
      (* We add this condition so that we satisfy the assumptions of eq_sort
         TODO: necessary? not based on current judgment scheme.
         wf_term c e t should imply wf_sort c t,
         and eq_sort c t t' should imply wf_sort c t


      wf_sort c t -> 
       *)
      wf_term c e t ->
      eq_sort c t t' ->
      wf_term c e t'
  | wf_term_var : forall c n t,
      In (n, t) c ->
      wf_term c (var n) t
  with wf_sort : ctx -> sort -> Prop :=
  | wf_sort_by : forall c n s args c',
      In (n, (sort_rule c' args)) l ->
      wf_args (Model:= mut_mod eq_sort eq_term wf_sort wf_term) c s c' ->
      wf_sort c (scon n s).
   
  #[export] Instance cut_model : Model := mut_mod eq_sort eq_term wf_sort wf_term.
  
  Notation wf_subst := (wf_subst (Model:= cut_model)).
  Notation wf_args := (wf_args (Model:= cut_model)).
  Notation wf_ctx := (wf_ctx (Model:= cut_model)).
   *)

  
  (* TODO: bug? This doesn't work even w/ eq_subst and eq_args defined mutually.
  Combined Scheme eq_ind
    from eq_sort_ind, eq_term_ind, eq_subst_ind, eq_args_ind.
   *)    
  
  Section EqInd.
    Context (P_sort : sort -> sort -> Prop)
      (P_term : sort -> term -> term -> Prop)
      (P_subst : ctx -> subst -> subst -> Prop)
      (P_args : ctx -> list term -> list term -> Prop).

    (* sort hypotheses *)
    Context (Hsort0 : forall (c' : ctx) (name : V) t1 t2 s1 s2,
          In (name, sort_eq_rule c' t1 t2) l ->
          eq_subst c' s1 s2 ->
          P_subst c' s1 s2 ->
          P_sort t1[/s1/] t2[/s2/])
      (Hsort1 : forall (c' : ctx) (name : V) args s1 s2,
          In (name, sort_rule c' args) l ->
          eq_args c' s1 s2 ->
          P_args c' s1 s2 ->
          P_sort (scon name s1) (scon name s2))
      (Hsort2 : forall (t1 t12 t2 : sort),
          eq_sort t1 t12 -> P_sort t1 t12 ->
          eq_sort t12 t2 -> P_sort t12 t2 ->
          P_sort t1 t2)
      (Hsort3 : forall (t1 t2 : sort),
          eq_sort t1 t2 -> P_sort t1 t2 -> P_sort t2 t1).
    
    (* Term hypotheses *)
    Context (f : forall (c' : ctx) (name : V) (t : sort) (e1 e2 : term) s1 s2,
          In (name, term_eq_rule c' e1 e2 t) l ->
          eq_subst c' s1 s2 ->
          P_subst c' s1 s2 ->
          P_term t[/s2/] e1[/s1/] e2[/s2/])
      (f0 : forall (c' : ctx) (name : V) (t : sort) args s1 s2,
          In (name, term_rule c' args t) l ->
          eq_args c' s1 s2 ->
          P_args c' s1 s2 ->
          P_term t[/(with_names_from c' s2)/] (con name s1) (con name s2))
      (f01 : forall (n : V) (t : sort),
          In (n, t) c -> P_term t (var n) (var n))
      (f1 : forall (t : sort) (e1 e12 e2 : term),
          eq_term t e1 e12 -> P_term t e1 e12 ->
          eq_term t e12 e2 -> P_term t e12 e2 ->
          P_term t e1 e2)
      (f2 : forall (t : sort) (e1 e2 : term),
          eq_term t e1 e2 -> P_term t e1 e2 -> P_term t e2 e1)
      (f3 : forall (t t' : sort),
          eq_sort t t' -> P_sort t t' ->
          forall e1 e2 : term,
            eq_term t e1 e2 -> P_term t e1 e2 -> P_term t' e1 e2).

    (* subst hypotheses *)
    Context (f4 : P_subst [] [] [])
      (f5 : forall (c' : ctx) s1 s2,
          eq_subst c' s1 s2 ->
          P_subst c' s1 s2 ->
          forall (name : V) (t : sort) (e1 e2 : term),
            eq_term t [/s2/] e1 e2 ->
            P_term t [/s2/] e1 e2 ->
            P_subst ((name, t) :: c') ((name,e1) :: s1) ((name,e2) :: s2)).
    
    (* args hypotheses *)
    Context (f6 : P_args [] [] [])
      (f7 : forall (c' : ctx) s1 s2,
          eq_args c' s1 s2 ->
          P_args c' s1 s2 ->
          forall (name : V) (t : sort) (e1 e2 : term),
            eq_term t [/with_names_from c' s2/] e1 e2 ->
            P_term t [/with_names_from c' s2/] e1 e2 ->
            P_args ((name, t) :: c') (e1 :: s1) (e2 :: s2)).
    
    Section NestedArgs.
      Context (eq_term_ind' : forall (s : sort) (t t0 : term),
                  eq_term s t t0 -> P_term s t t0).
      Arguments eq_term_ind' {_ _ _} _.

      Arguments eq_args_cons {c'}%ctx_scope {es1 es2}%list_scope _
        {name t e1 e2} _.

      Arguments f7 {c'}%ctx_scope {s1 s2}%list_scope _ _ {name t e1 e2} _ _.
      
      Fixpoint eq_args_ind' {c0 : ctx} {s s0} (e : eq_args c0 s s0)
        : P_args c0 s s0 :=
        match e in (eq_args c2 s1 s2) return (P_args c2 s1 s2) with
        | eq_args_nil => f6
        | eq_args_cons e0 e3 =>
            f7 e0 (eq_args_ind' e0) e3 (eq_term_ind' e3)
        end.
    End NestedArgs.
    
    Section NestedSubst.
      Context (eq_term_ind' : forall (s : sort) (t t0 : term),
                  eq_term s t t0 -> P_term s t t0).
      Arguments eq_term_ind' {_ _ _} _.

      Arguments eq_subst_cons {c'}%ctx_scope {s1 s2}%list_scope _
        {name t e1 e2} _.

      Arguments f5 {c'}%ctx_scope {s1 s2}%list_scope _ _ {name t e1 e2} _ _.
      
      Fixpoint eq_subst_ind' {c0 : ctx} {s s0} (e : eq_subst c0 s s0)
        : P_subst c0 s s0 :=
        match e in (eq_subst c2 s1 s2) return (P_subst c2 s1 s2) with
        | eq_subst_nil => f4
        | eq_subst_cons e0 e3 =>
            f5 e0 (eq_subst_ind' e0) e3 (eq_term_ind' e3)
        end.
    End NestedSubst.

    Fixpoint eq_sort_ind' [t t0]
      (e : eq_sort t t0) : P_sort t t0 :=
           match e in (eq_sort t1 t2) return (P_sort t1 t2) with
           | eq_sort_by name c' e1 e2 s1 s2 i pa =>
               Hsort0 c' name e1 e2 s1 s2 i pa (eq_subst_ind' eq_term_ind' pa)
           | eq_sort_cong name c' args s1 s2 i pa =>
               Hsort1 c' name args s1 s2 i pa (eq_args_ind' eq_term_ind' pa)
           | eq_sort_trans _ _ _ e0 e3 =>
               Hsort2 _ _ _ e0 (eq_sort_ind' e0) e3 (eq_sort_ind' e3)
           | eq_sort_sym _ _ e0 => Hsort3 _ _ e0 (eq_sort_ind' e0)
           end
    with eq_term_ind' [s t t0]
      (e : eq_term s t t0) : P_term s t t0 :=
           match e in (eq_term s0 t1 t2) return (P_term s0 t1 t2) with
           | eq_term_by name c' t1 e1 e2 s1 s2 i pa =>
               f c' name t1 e1 e2 s1 s2 i pa (eq_subst_ind' eq_term_ind' pa)
           | eq_term_cong name c' args t1 s1 s2 i pa =>
               f0 c' name t1 args s1 s2 i pa (eq_args_ind' eq_term_ind' pa)
           | eq_term_var n t0 i => f01 n t0 i
           | eq_term_trans _ _ _ _ e0 e3 =>
               f1 _ _ _ _ e0 (eq_term_ind' e0) e3 (eq_term_ind' e3)
           | eq_term_sym _ _ _ e0 => f2 _ _ _ e0 (eq_term_ind' e0)
           | eq_term_conv _ _ _ _ e3 e0 =>
               f3 _ _ e0 (eq_sort_ind' e0) _ _ e3 (eq_term_ind' e3)
           end.
    
    Definition eq_args_ind'' := @eq_args_ind' eq_term_ind'.
    Definition eq_subst_ind'' := @eq_subst_ind' eq_term_ind'.

    Definition cut_ind :=
      conj eq_sort_ind'
        (conj eq_term_ind'              
           (conj eq_subst_ind''             
              eq_args_ind'')).
  End EqInd.

  
  Local Hint Constructors eq_sort eq_term eq_subst eq_args : lang_core.
  
  Local Lemma eq_refl_right
    : (forall t1 t2,
          eq_sort t1 t2 ->
          eq_sort t2 t2)
      /\ (forall t e1 e2,
             eq_term t e1 e2 ->
             eq_term t e2 e2)
      /\ (forall c' s1 s2,
             eq_subst c' s1 s2 ->
             eq_subst c' s2 s2)
      /\ (forall c' s1 s2,
             eq_args c' s1 s2 ->
             eq_args c' s2 s2).
  Proof using V_Eqb_ok.
    simple eapply cut_ind;
      basic_goal_prep;
      basic_core_crush.
  Qed.
        
  Definition eq_sort_refl_right := proj1 eq_refl_right.
  Local Hint Resolve eq_sort_refl_right : lang_core.
  
  Definition eq_term_refl_right := proj1 (proj2 eq_refl_right).
  Local Hint Resolve eq_term_refl_right : lang_core.

  Definition eq_subst_refl_right := proj1 (proj2 (proj2 eq_refl_right)).
  Local Hint Resolve eq_subst_refl_right : lang_core.
  
  Definition eq_args_refl_right := proj2 (proj2 (proj2 eq_refl_right)).
  Local Hint Resolve eq_args_refl_right : lang_core.

  
  Lemma eq_args_implies_eq_subst:
  forall [c' : NamedList.named_list V sort] [s1 s2 : list term],
    eq_args c' s1 s2 -> eq_subst c' (with_names_from c' s1) (with_names_from c' s2).
  Proof.
    induction 1;
      basic_goal_prep;
      basic_core_crush.
  Qed.
  Hint Resolve eq_args_implies_eq_subst : lang_core.

  
  Lemma eq_subst_map_fst_r c0 s0 s3
    : eq_subst c0 s0 s3 -> map fst s3 = map fst c0.
  Proof.
    induction 1;
      basic_goal_prep;
      basic_core_crush.
  Qed.
  #[local] Hint Rewrite eq_subst_map_fst_r using eassumption : lang_core.

  Lemma eq_subst_map_fst_l c0 s0 s3
    : eq_subst c0 s0 s3 -> map fst s0 = map fst c0.
  Proof.
    induction 1;
      basic_goal_prep;
      basic_core_crush.
  Qed.
  #[local] Hint Rewrite eq_subst_map_fst_l using eassumption : lang_core.


  Lemma eq_subst_fresh_r c0 s0 s3 n
    : eq_subst c0 s0 s3 -> fresh n c0 -> fresh n s3.
  Proof.
    unfold fresh; intros.
    erewrite eq_subst_map_fst_r; eauto.
  Qed.
  #[local] Hint Resolve eq_subst_fresh_r : lang_core.

  Lemma eq_subst_fresh_l c0 s0 s3 n
    : eq_subst c0 s0 s3 -> fresh n c0 -> fresh n s0.
  Proof.
    unfold fresh; intros.
    erewrite eq_subst_map_fst_l; eauto.
  Qed.
  #[local] Hint Resolve eq_subst_fresh_l : lang_core.

  
  
  Lemma eq_args_len_eq_r c' s1 s2
    : eq_args c' s1 s2 ->
      length s2 = length c'.
  Proof.
    induction 1; basic_goal_prep;
      basic_core_crush.
  Qed.
  (*Hint Rewrite eq_args_len_eq_r using eassumption : lang_core.*)
  
  
  Lemma eq_args_len_eq_l c' s1 s2
    : eq_args c' s1 s2 ->
      length s1 = length c'.
  Proof.
    induction 1; basic_goal_prep;
      basic_core_crush.
  Qed.
  (*Hint Rewrite eq_args_len_eq_l using eassumption : lang_core.*)
  
  Section __.
    Context (wsl : ws_lang l)
      (wsc : ws_ctx c).
    
    Lemma eq_implies_ws
      : (forall t1' t2',
            eq_sort t1' t2' ->
            well_scoped (map fst c) t1'
            /\ well_scoped (map fst c) t2')
        /\ (forall (t : Term.sort V) (e1 e2 : Term.term V),
               eq_term t e1 e2 ->
               well_scoped (map fst c) t
               /\ well_scoped (map fst c) e1
               /\ well_scoped (map fst c) e2)
        /\ (forall (c' : Term.ctx V) (s1 s2 : Term.subst V),
              eq_subst c' s1 s2 ->
              ws_ctx c' ->
              well_scoped (map fst c) s1
              /\ well_scoped (map fst c) s2)
        /\ (forall c' (s1 s2 : list term),
               eq_args c' s1 s2 ->
               ws_ctx c' ->
               well_scoped (map fst c) s1
               /\ well_scoped (map fst c) s2).
    Proof using V_Eqb_ok wsl wsc.
      simple eapply cut_ind;
        basic_goal_prep.
      all: try use_rule_in_ws.
      all: basic_goal_prep.
      all: autorewrite with utils model term lang_core in *.
      all: basic_goal_prep.
      all: intuition subst.
      all: try eapply well_scoped_subst; eauto; try typeclasses eauto.
      all: eauto with utils model term lang_core.
      all: try change (ws_subst ?a ?b) with (well_scoped a b).
      all: try change (ws_args ?a ?b) with (well_scoped a b).
      all: try erewrite eq_subst_map_fst_l by eassumption; eauto.
      all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
      all: try eapply ws_subst_from_ws_args.
      all: try eauto using ws_all_fresh_ctx.
      all: try erewrite eq_args_len_eq_r; eauto.
      basic_utils_crush.
      erewrite eq_args_len_eq_r; eauto.
    Qed.

    Definition eq_sort_implies_ws_l t1' t2' (Heq : eq_sort t1' t2') :=
      proj1 ((proj1 eq_implies_ws) _ _ Heq).
    Definition eq_sort_implies_ws_r t1' t2' (Heq : eq_sort t1' t2') :=
      proj2 ((proj1 eq_implies_ws) _ _ Heq).
    Definition eq_term_implies_ws_sort t e1 e2 (Heq : eq_term t e1 e2) :=
      proj1 ((proj1 (proj2 eq_implies_ws)) _ _ _ Heq).
    Definition eq_term_implies_ws_l t e1 e2 (Heq : eq_term t e1 e2) :=
      proj1 (proj2 ((proj1 (proj2 eq_implies_ws)) _ _ _ Heq)).
    Definition eq_term_implies_ws_r t e1 e2 (Heq : eq_term t e1 e2) :=
      proj2 (proj2 ((proj1 (proj2 eq_implies_ws)) _ _ _ Heq)).
    Definition eq_subst_implies_ws_l c' s1 s2 (Heq : eq_subst c' s1 s2) Hws' :=
      proj1 ((proj1 (proj2 (proj2 eq_implies_ws))) _ _ _ Heq Hws').
    Definition eq_subst_implies_ws_r c' s1 s2 (Heq : eq_subst c' s1 s2) Hws' :=
      proj2 ((proj1 (proj2 (proj2 eq_implies_ws))) _ _ _ Heq Hws').
    Definition eq_args_implies_ws_l c' s1 s2 (Heq : eq_args c' s1 s2) Hws' :=
      proj1 ((proj2 (proj2 (proj2 eq_implies_ws))) _ _ _ Heq Hws').
    Definition eq_args_implies_ws_r c' s1 s2 (Heq : eq_args c' s1 s2) Hws' :=
      proj2 ((proj2 (proj2 (proj2 eq_implies_ws))) _ _ _ Heq Hws').
    
    Hint Resolve eq_sort_implies_ws_l : lang_core.
    Hint Resolve eq_sort_implies_ws_r : lang_core.
    Hint Resolve eq_term_implies_ws_sort : lang_core. 
    Hint Resolve eq_term_implies_ws_l : lang_core. 
    Hint Resolve eq_term_implies_ws_r : lang_core.  
    Hint Resolve eq_subst_implies_ws_l : lang_core.
    Hint Resolve eq_subst_implies_ws_r : lang_core.
    Hint Resolve eq_args_implies_ws_l : lang_core.
    Hint Resolve eq_args_implies_ws_r : lang_core.

  End __.
  
  
  End WithCtx.

  Local Hint Constructors eq_sort eq_term eq_subst eq_args : lang_core.
  Local Hint Resolve eq_sort_refl_right : lang_core.
  Local Hint Resolve eq_term_refl_right : lang_core.
  Local Hint Resolve eq_subst_refl_right : lang_core.
  Local Hint Resolve eq_args_refl_right : lang_core.
  Hint Resolve eq_args_implies_eq_subst : lang_core.

  #[local] Hint Rewrite eq_subst_map_fst_r using eassumption : lang_core.
  #[local] Hint Rewrite eq_subst_map_fst_l using eassumption : lang_core.
  #[local] Hint Resolve eq_subst_fresh_r : lang_core.
  #[local] Hint Resolve eq_subst_fresh_l : lang_core.

  
  Hint Resolve eq_sort_implies_ws_l : lang_core.
  Hint Resolve eq_sort_implies_ws_r : lang_core.
  Hint Resolve eq_term_implies_ws_sort : lang_core. 
  Hint Resolve eq_term_implies_ws_l : lang_core. 
  Hint Resolve eq_term_implies_ws_r : lang_core.  
  Hint Resolve eq_subst_implies_ws_l : lang_core.
  Hint Resolve eq_subst_implies_ws_r : lang_core.
  Hint Resolve eq_args_implies_ws_l : lang_core.
  Hint Resolve eq_args_implies_ws_r : lang_core.

  

  Inductive wf_ctx : named_list sort -> Prop :=
    wf_ctx_nil : wf_ctx []
  | wf_ctx_cons : forall name c t,
      fresh name c -> wf_ctx c -> eq_sort c t t -> wf_ctx ((name, t) :: c).
  Hint Constructors wf_ctx : lang_core.

  
  Lemma invert_wf_ctx_nil : wf_ctx [] <-> True.
  Proof. solve_invert_constr_eq_lemma. Qed.
  #[local] Hint Rewrite invert_wf_ctx_nil : lang_core.

  Lemma invert_wf_ctx_cons c n t
    : wf_ctx ((n,t)::c) <-> fresh n c /\ wf_ctx c /\ eq_sort c t t.
  Proof. solve_invert_constr_eq_lemma. Qed.
  #[local] Hint Rewrite invert_wf_ctx_cons : lang_core.

  
  Local Lemma ctx_mono c c'
    : incl c c' ->
      (forall t1 t2,
          eq_sort c t1 t2 ->
          eq_sort c' t1 t2)
      /\ (forall t e1 e2,
             eq_term c t e1 e2 ->
             eq_term c' t e1 e2)
      /\ (forall c'' s1 s2,
             eq_subst c c'' s1 s2 ->
             eq_subst c' c'' s1 s2)
      /\ (forall c'' s1 s2,
             eq_args c c'' s1 s2 ->
             eq_args c' c'' s1 s2).
  Proof using V_Eqb_ok.
    intro Hincl.
    eapply cut_ind;
      basic_goal_prep;
      basic_core_crush.
  Qed.

  Lemma in_ctx_wf n t c
    : wf_ctx c -> In (n, t) c -> eq_sort c t t.
  Proof.
    induction 1;
      basic_goal_prep;
      basic_core_crush.
    all:eapply ctx_mono; eauto; eauto with utils.
  Qed.
  Hint Resolve in_ctx_wf : lang_core.


  Lemma cut_id_subst_refl' c c'
    : incl c c' -> eq_subst c' c (id_subst c) (id_subst c).
  Proof.
    revert c'.
    induction c;
      basic_goal_prep;
      basic_core_crush.
    constructor; eauto.
    eapply eq_term_var.
    replace (s [/with_names_from c (map var (map fst c)) /]) with s; eauto.
    symmetry.
    eapply sort_subst_id.
    eauto.
  Qed.

  Lemma cut_id_subst_refl c
    : eq_subst c c (id_subst c) (id_subst c).
  Proof.
    eapply cut_id_subst_refl'; basic_utils_crush.
  Qed.
  Hint Resolve cut_id_subst_refl : lang_core.

  Variant wf_rule : rule -> Prop :=
  | wf_sort_rule : forall c args,
      wf_ctx c ->
      sublist args (map fst c) ->
      wf_rule (sort_rule c args)
  | wf_term_rule : forall c args t,
      wf_ctx c ->
      eq_sort c t t ->
      sublist args (map fst c) ->
      wf_rule (term_rule c args t)
  | eq_sort_rule : forall c t1 t2,
      wf_ctx c ->
      eq_sort c t1 t1 ->
      eq_sort c t2 t2 ->
      wf_rule (sort_eq_rule c t1 t2)
  | eq_term_rule : forall c e1 e2 t,
      wf_ctx c ->
      eq_sort c t t ->
      eq_term c t e1 e1 ->
      eq_term c t e2 e2 ->
      wf_rule (term_eq_rule c e1 e2 t).

  
  Lemma invert_wf_sort_rule c args
    : wf_rule (sort_rule c args) <-> wf_ctx c /\ sublist args (map fst c).
  Proof. solve_invert_constr_eq_lemma. Qed.
  Hint Rewrite invert_wf_sort_rule : lang_core.

  Lemma invert_wf_term_rule c args t
    : wf_rule (term_rule c args t) <-> wf_ctx c /\ sublist args (map fst c) /\ eq_sort c t t.
  Proof. solve_invert_constr_eq_lemma. Qed.
  Hint Rewrite invert_wf_term_rule : lang_core.

  Lemma invert_wf_sort_eq_rule c t1 t2
    : wf_rule (sort_eq_rule c t1 t2) <-> wf_ctx c /\ eq_sort c t1 t1 /\ eq_sort c t2 t2.
  Proof. solve_invert_constr_eq_lemma. Qed.
  Hint Rewrite invert_wf_sort_eq_rule : lang_core.

  Lemma invert_wf_term_eq_rule c e1 e2 t
    : wf_rule (term_eq_rule c e1 e2 t)
      <-> wf_ctx c /\ eq_term c t e1 e1 /\ eq_term c t e2 e2 /\ eq_sort c t t.
  Proof. solve_invert_constr_eq_lemma. Qed.
  Hint Rewrite invert_wf_term_eq_rule : lang_core.



  Section __.
    Context (wsl : ws_lang l).

    Lemma wf_ctx_implies_ws c
      : wf_ctx c -> ws_ctx c.
    Proof.
      induction 1;
        basic_goal_prep;
        basic_core_crush.
      eapply eq_sort_implies_ws_l; eauto.
    Qed.
    Hint Resolve wf_ctx_implies_ws : lang_core.

    
    Lemma wf_rule_implies_ws r
      : wf_rule r -> ws_rule r.
    Proof.
      destruct 1;
        basic_goal_prep;
        autorewrite with utils term lang_core in *;
        intuition eauto with lang_core.
    Qed.
   
    
    Lemma refl_term_lookup c0 c s1 s2 n t
      : eq_subst c0 c s1 s2 ->
        wf_ctx c ->
        In (n, t) c ->
        eq_term c0 t [/s2 /] (term_subst_lookup s1 n) (term_subst_lookup s2 n).
    Proof.
      induction 1;
        basic_goal_prep;
        autorewrite with utils term lang_core model in *;
        [tauto|].
      intuition subst.
      {
        rewrite strengthen_subst with (Substable0 := _);
          try typeclasses eauto.
        all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
        all:basic_core_crush.        
      }
      {
        cbn.
        case_match; basic_goal_prep; autorewrite with utils term lang_core model in *;
          subst.
        {
          erewrite strengthen_subst;
            try typeclasses eauto;
            eauto;
            basic_core_crush.
        }
        {
          change ((named_list_lookup (var ?n) ?s ?n)) with (subst_lookup s n).
          erewrite strengthen_subst;
            try typeclasses eauto;
            eauto.
          all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
          all: basic_core_crush.
        }
      }
    Qed.
    Hint Resolve refl_term_lookup : lang_core.

  End __.

  (*
  (*Note: proof of this depends on weakening*)
  Context (lang_admissible : all rule_cut_admissible (map snd l)).
   *)

End Terms.

Hint Resolve eq_sort_by eq_term_by eq_sort_cong eq_term_cong : lang_core.
Hint Constructors eq_subst eq_args : lang_core.

Hint Resolve eq_sort_implies_ws_l : lang_core.
Hint Resolve eq_sort_implies_ws_r : lang_core.
Hint Resolve eq_term_implies_ws_sort : lang_core. 
Hint Resolve eq_term_implies_ws_l : lang_core. 
Hint Resolve eq_term_implies_ws_r : lang_core.  
Hint Resolve eq_subst_implies_ws_l : lang_core.
Hint Resolve eq_subst_implies_ws_r : lang_core.
Hint Resolve eq_args_implies_ws_l : lang_core.
Hint Resolve eq_args_implies_ws_r : lang_core.
Hint Resolve wf_ctx_implies_ws : lang_core.
Hint Resolve wf_rule_implies_ws : lang_core.


Hint Resolve refl_term_lookup : lang_core.

Hint Constructors wf_ctx wf_rule : lang_core.

Hint Rewrite invert_wf_ctx_nil : lang_core.
Hint Rewrite invert_wf_ctx_cons : lang_core.

Hint Rewrite invert_wf_sort_rule : lang_core.
Hint Rewrite invert_wf_term_rule : lang_core.
Hint Rewrite invert_wf_sort_eq_rule : lang_core.
Hint Rewrite invert_wf_term_eq_rule : lang_core.

Section LangMono.
  Context (l l': lang).
  Context (Hincl : incl l l').

  Section __.
    Context (c : ctx).
    Local Lemma lang_mono 
      : (forall t1 t2,
            eq_sort l c t1 t2 ->
            eq_sort l' c t1 t2)
        /\ (forall t e1 e2,
               eq_term l c t e1 e2 ->
               eq_term l' c t e1 e2)
        /\ (forall c' s1 s2,
               eq_subst l c c' s1 s2 ->
               eq_subst l' c c' s1 s2)
        /\ (forall c' s1 s2,
               eq_args l c c' s1 s2 ->
               eq_args l' c c' s1 s2).
    Proof using Hincl c.
      eapply cut_ind;
        basic_goal_prep;
        try solve [constructor; eauto].
      { eapply eq_sort_by; eauto. }
      { eapply eq_sort_cong; eauto. }
      { eapply eq_sort_trans; eauto. }
      { eapply eq_term_by; eauto. }
      { eapply eq_term_cong; eauto. }
      { eapply eq_term_trans; eauto. }
      { eapply eq_term_conv; eauto. }
    Qed.

    Definition eq_sort_lang_mono := proj1 lang_mono.
    Definition eq_term_lang_mono := proj1 (proj2 lang_mono).
    Definition eq_subst_lang_mono := proj1 (proj2 (proj2 lang_mono)).
    Definition eq_args_lang_mono := proj2 (proj2 (proj2 lang_mono)).
    
  End __.

  Hint Resolve eq_sort_lang_mono : lang_core.
  Hint Resolve eq_term_lang_mono : lang_core.
  
  Lemma ctx_lang_mono c
    : wf_ctx l c -> wf_ctx l' c.
  Proof.
    induction 1;
      basic_goal_prep;
      basic_core_crush.
  Qed.    
  
  Hint Resolve ctx_lang_mono : lang_core.
  
  Lemma rule_mono r : wf_rule l r -> wf_rule l' r.
  Proof.
    destruct 1;
      basic_goal_prep;
      basic_core_crush.
  Qed.  

End LangMono.



Inductive wf_lang : lang -> Prop :=
| wf_lang_nil : wf_lang []
| wf_lang_cons : forall l n r,
    fresh n (l) ->
    wf_lang l ->
    wf_rule (l) r ->
    wf_lang ((n,r)::l).


Lemma wf_lang_implies_ws l
  : wf_lang l -> ws_lang l.
Proof.
  induction 1;
    basic_goal_prep;
    basic_core_crush.
Qed.
Hint Resolve wf_lang_implies_ws : lang_core.



Section CutDefs.
  Context (l : lang).

  Definition sort_cut_admissible c' t1' t2' :=
    forall c s1 s2,
      eq_subst l c c' s1 s2 ->
      eq_sort l c t1' [/s1 /] t2' [/s2 /].
  Definition term_cut_admissible c' t e1 e2 :=
    forall c s1 s2,
      eq_subst l c c' s1 s2 ->
      wf_ctx l c' -> eq_term l c t [/s2 /] e1 [/s1 /] e2 [/s2 /].

  Definition subst_cut_admissible c c' s1 s2 :=
      forall (c'' : Term.ctx V) (s1' s2' : Term.subst V),
        eq_subst l c'' c s1' s2' ->
        eq_subst l c'' c' s1 [/s1' /] s2 [/s2' /].
  
  Definition args_cut_admissible c c' s1 s2 :=
      forall (c'' : Term.ctx V) s1' s2',
        eq_subst l c'' c s1' s2' ->
        eq_args l c'' c' s1 [/s1' /] s2 [/s2' /].

  (* TODO: this is the easier one to prove, connect via weakening*)
  Fixpoint ctx_cut_admissible c :=
    match c with
    | [] => True
    | (_,t)::c' =>
        sort_cut_admissible c' t t
        /\ ctx_cut_admissible c'
    end.

  Definition rule_cut_admissible r :=
    match r with
    | sort_eq_rule c t1 t2 =>
        ctx_cut_admissible c
        /\ sort_cut_admissible c t1 t1
        /\ sort_cut_admissible c t2 t2
    | term_eq_rule c e1 e2 t =>
        ctx_cut_admissible c
        /\ sort_cut_admissible c t t
        /\ term_cut_admissible c t e1 e1
        /\ term_cut_admissible c t e2 e2
    | sort_rule c args =>
        ctx_cut_admissible c
    | term_rule c args t =>
        ctx_cut_admissible c
        /\ sort_cut_admissible c t t
    end.
  
  Lemma eq_subst_sym' c c' s1 s2
    : wf_lang l ->
      eq_subst l c c' s1 s2 -> wf_ctx l c' -> ctx_cut_admissible c' -> eq_subst l c c' s2 s1.
  Proof using .
    induction 2; intros.
    1:basic_core_crush.
    constructor.
    all:basic_goal_prep.
    1: basic_core_crush.
    
    eapply eq_term_conv; eauto using eq_term_sym.
    break.
    safe_invert H2.
    eapply H3; eauto with utils.
  Qed.

  
    
    Lemma ctx_admissible_in c n t
      : wf_lang l -> wf_ctx l c ->
        ctx_cut_admissible c ->
        In (n, t) c ->
        sort_cut_admissible c t t.
    Proof using V_Eqb_ok.
      intro wsl.
      induction 1;
        basic_goal_prep;
        basic_core_crush.
      {
        clear H3.
        unfold sort_cut_admissible in *;
          intros.
        
        autorewrite with lang_core in *.
        lazymatch goal with
        | H : eq_subst _ _ (_::_) _ _ |- _ =>
            safe_invert H
        end.
        break.
        erewrite !strengthen_subst;
          try typeclasses eauto;
          eauto.
        all: try erewrite eq_subst_map_fst_l by eassumption; eauto.
        all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
        all: try (eapply eq_subst_fresh_l; now eauto).
        all: try (eapply eq_subst_fresh_r; now eauto).
        all: eapply eq_sort_implies_ws_r; eauto with lang_core.
      }
      {
        clear H4.      
        unfold sort_cut_admissible in *;
          intros.
        
        autorewrite with lang_core in *.
        lazymatch goal with
        | H : eq_subst _ _ (_::_) _ _ |- _ =>
            safe_invert H
        end.
        break.
        eapply in_ctx_wf in H2; [| cbn; intuition eauto].
        erewrite !strengthen_subst;
          try typeclasses eauto;
          eauto.
        all: try erewrite eq_subst_map_fst_l by eassumption; eauto.
        all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
        all: eauto with lang_core.
        (*{
          eapply H6; eauto.
          eapply ctx_lang_mono; eauto.
        }*)
        all: try (eapply eq_subst_fresh_l; now eauto).
        all: try (eapply eq_subst_fresh_r; now eauto).        
      }
    Qed.

End CutDefs.


Definition lang_cut_admissible (l : lang) :=
  (*all (fun r => forall l', incl l' l -> rule_cut_admissible l) (map snd l).*)
  forall l', wf_lang l' -> incl l  l' -> all (rule_cut_admissible l') (map snd l).
(*  match l with
  | [] => True
  | (_, r) :: l' => rule_cut_admissible l_orig r /\ lang_cut_admissible' l_orig l'
  end.

Definition lang_cut_admissible l := lang_cut_admissible l
*)
(*
Section Weak1Defs.
  Context (l : lang).

  Definition weak1_sort_cut_admissible c' t1' t2' :=
    forall c s1 s2,
      eq_subst l c c' s1 s2 ->
      wf_ctx l c' ->
      eq_sort l c t1' [/s1 /] t2' [/s2 /].
  Definition weak1_term_cut_admissible c' t e1 e2 :=
    forall c s1 s2,
      eq_subst l c c' s1 s2 ->
      wf_ctx l c' -> eq_term l c t [/s2 /] e1 [/s1 /] e2 [/s2 /].

  Definition weak1_subst_cut_admissible c c' s1 s2 :=
      wf_ctx l c ->
      wf_ctx l c' ->
      forall (c'' : Term.ctx V) (s1' s2' : Term.subst V),
        eq_subst l c'' c s1' s2' ->
        eq_subst l c'' c' s1 [/s1' /] s2 [/s2' /].
  
  Definition weak1_args_cut_admissible c c' s1 s2 :=
      wf_ctx l c ->
      wf_ctx l c' ->
      forall (c'' : Term.ctx V) s1' s2',
        eq_subst l c'' c s1' s2' ->
        eq_args l c'' c' s1 [/s1' /] s2 [/s2' /].

  (* TODO: this is the easier one to prove, connect via weakening*)
  Fixpoint weak1_ctx_cut_admissible c :=
    match c with
    | [] => True
    | (_,t)::c' =>
        weak1_sort_cut_admissible c' t t
        /\ weak1_ctx_cut_admissible c'
    end.

  Definition weak1_rule_cut_admissible r :=
    match r with
    | sort_eq_rule c t1 t2 =>
        weak1_ctx_cut_admissible c
        /\ weak1_sort_cut_admissible c t1 t1
        /\ weak1_sort_cut_admissible c t2 t2
    | term_eq_rule c e1 e2 t =>
        weak1_ctx_cut_admissible c
        /\ weak1_sort_cut_admissible c t t
        /\ weak1_term_cut_admissible c t e1 e1
        /\ weak1_term_cut_admissible c t e2 e2
    | sort_rule c args =>
        weak1_ctx_cut_admissible c
    | term_rule c args t =>
        weak1_ctx_cut_admissible c
        /\ weak1_sort_cut_admissible c t t
    end.
  
  Lemma weak1_eq_subst_sym' c c' s1 s2
    : wf_lang l -> lang_cut_admissible l ->
      eq_subst l c c' s1 s2 -> wf_ctx l c' -> weak1_ctx_cut_admissible c' -> eq_subst l c c' s2 s1.
  Proof using .
    intros wfl Hla.
    induction 1; intros.
    1:basic_core_crush.
    constructor.
    all:basic_goal_prep.
    1: basic_core_crush.
    
    eapply eq_term_conv; eauto using eq_term_sym.
    break.
    safe_invert H1.
    eapply H2; eauto with utils.
  Qed.

  
    
    Lemma weak1_ctx_admissible_in c n t
      : wf_lang l -> lang_cut_admissible l ->
        wf_ctx l c ->
        weak1_ctx_cut_admissible c ->
        In (n, t) c ->
        weak1_sort_cut_admissible c t t.
    Proof using V_Eqb_ok.
      intros wsl Hla.
      induction 1;
        basic_goal_prep;
        basic_core_crush.
      {
        unfold weak1_sort_cut_admissible in *;
          intros.
        autorewrite with lang_core in *.
        lazymatch goal with
        | H : eq_subst _ _ (_::_) _ _ |- _ =>
            safe_invert H
        end.
        break.
        erewrite !strengthen_subst;
          try typeclasses eauto;
          eauto.
        all: try erewrite eq_subst_map_fst_l by eassumption; eauto.
        all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
        all: try (eapply eq_subst_fresh_l; now eauto).
        all: try (eapply eq_subst_fresh_r; now eauto).
        all: eapply eq_sort_implies_ws_r; eauto with lang_core.
      }
      {
        unfold weak1_sort_cut_admissible in *;
          intros.
        lazymatch goal with
        | H : eq_subst _ _ (_::_) _ _ |- _ =>
            safe_invert H
        end.
        autorewrite with lang_core in *.
        break.
        eapply in_ctx_wf in H2; [| cbn; intuition eauto].
        erewrite !strengthen_subst;
          try typeclasses eauto;
          eauto.
        all: try erewrite eq_subst_map_fst_l by eassumption; eauto.
        all: try erewrite eq_subst_map_fst_r by eassumption; eauto.
        all: eauto with lang_core.
        all: try (eapply eq_subst_fresh_l; now eauto).
        all: try (eapply eq_subst_fresh_r; now eauto).        
      }
    Qed.

End Weak1Defs.
*)

(*
Fixpoint weak1_lang_cut_admissible l :=
  match l with
  | [] => True
  | (_, r) :: l' => weak1_rule_cut_admissible l' r /\ weak1_lang_cut_admissible l'
  end.
*)
(*
Section Weak2Defs.
  Context (l : lang).
  
  (* avoids a mutual definition to have separate weak version*)
  Definition weak2_sort_cut_admissible c' t1' t2' :=
    forall c s1 s2,
      eq_subst l c c' s1 s2 ->
      wf_ctx l c -> ctx_cut_admissible l c ->
      eq_sort l c t1' [/s1 /] t2' [/s2 /].
  Definition weak2_term_cut_admissible c' t e1 e2 :=
    forall c s1 s2,
      eq_subst l c c' s1 s2 ->
      wf_ctx l c -> ctx_cut_admissible l c ->
      eq_term l c t [/s2 /] e1 [/s1 /] e2 [/s2 /].

  Definition weak2_subst_cut_admissible c c' s1 s2 :=
    wf_ctx l c -> ctx_cut_admissible l c ->
    wf_ctx l c' -> ctx_cut_admissible l c' ->
    forall (c'' : Term.ctx V) (s1' s2' : Term.subst V),
      eq_subst l c'' c s1' s2' ->
      eq_subst l c'' c' s1 [/s1' /] s2 [/s2' /].
  
  Definition weak2_args_cut_admissible c c' s1 s2 :=
    wf_ctx l c -> ctx_cut_admissible l c ->
    wf_ctx l c' -> ctx_cut_admissible l c' ->
    forall (c'' : Term.ctx V) s1' s2',
      eq_subst l c'' c s1' s2' ->
      eq_args l c'' c' s1 [/s1' /] s2 [/s2' /].

End Weak2Defs.*)


Lemma rule_in_wf l name r
  : wf_lang l -> In (name, r) l -> wf_rule l r.
Proof.
  induction 1;
    basic_goal_prep;
    [tauto|].
  eapply rule_mono; cycle 1;
    basic_core_crush.
Qed.
Hint Resolve rule_in_wf : lang_core.

Local Ltac use_rule_in_wf :=
  lazymatch goal with
  | H:wf_lang ?l, Hin:In (_, _) ?l |- _ => pose proof (rule_in_wf _ _ _ H Hin)
  end.

(*TODO: Weak1 is a dup now*)
(*
Lemma ctx_cut_admissible_mono l l' c
  : incl l l' -> ctx_cut_admissible l c -> ctx_cut_admissible l' c.
Proof.
  induction c;
    basic_goal_prep;
    intuition subst.
  unfold sort_cut_admissible in *.
  intuition eauto.
  eapply H1; eauto.
  eapply incl_tran; eauto.
Qed.
*)

(*
Lemma rule_cut_admissible_mono l l' r
  : incl l l' -> rule_cut_admissible l r -> rule_cut_admissible l' r.
Proof.
  unfold rule_cut_admissible,
    term_cut_admissible, sort_cut_admissible,
    subst_cut_admissible, args_cut_admissible in *.
  destruct r;
    basic_goal_prep;
    intuition eauto using ctx_cut_admissible_mono.
  all: try now (eapply H1; eauto using incl_tran).
  all: try now (eapply H2; eauto using incl_tran).
  all: try now (eapply H3; eauto using incl_tran).
Qed.

Lemma lang_admissible_in l n r
  : wf_lang l ->
    lang_cut_admissible l ->
    In (n, r) l ->
    rule_cut_admissible l r.
Proof using V_Eqb_ok.
  induction 1;
    basic_goal_prep;
    basic_core_crush.
  all: eapply rule_cut_admissible_mono; eauto.
  all: basic_utils_crush.
Qed.
*)

(*
Lemma ctx_cut_admissible_mono l l' c
  : incl l l' -> ctx_cut_admissible l c -> ctx_cut_admissible l' c.
Proof.
  induction c;
    basic_goal_prep;
    intuition subst.
  unfold sort_cut_admissible in *.
  intuition eauto.
  eapply H1; eauto.
  eapply incl_tran; eauto.
Qed.

Lemma rule_cut_admissible_mono l l' r
  : incl l l' -> rule_cut_admissible l r -> rule_cut_admissible l' r.
Proof.
  unfold rule_cut_admissible,
    term_cut_admissible, sort_cut_admissible,
    subst_cut_admissible, args_cut_admissible in *.
  destruct r;
    basic_goal_prep;
    intuition eauto using ctx_cut_admissible_mono.
  all: try now (eapply H1; eauto using incl_tran).
  all: try now (eapply H2; eauto using incl_tran).
  all: try now (eapply H3; eauto using incl_tran).
Qed.
*)

Lemma lang_admissible_in l n r
  : wf_lang l ->
    lang_cut_admissible l ->
    In (n, r) l ->
    forall l', wf_lang l' -> incl l l' ->
    rule_cut_admissible l' r.
Proof using V_Eqb_ok.
  unfold lang_cut_admissible.
  intros.
  eapply H0 in H2; eauto.
  clear H0.
  revert dependent l.
  induction l;
    basic_goal_prep;
    basic_core_crush.
  eapply in_all_named_list in H4; eauto.
Qed.

(*
Lemma ctx_admissible_implies_weak l c
  : ctx_cut_admissible l c -> ctx_cut_admissible l c.
Proof.
  induction c; basic_goal_prep; intuition eauto.
  (*unfold sort_cut_admissible, sort_cut_admissible; intuition eauto.*)
Qed.
Hint Resolve ctx_admissible_implies_weak : lang_core.*)

Section WithLang.
  Context (l : lang)
    (wfl : wf_lang l).

  Local Notation wf_ctx c := (wf_ctx l c).
  Local Notation eq_sort c' t1' t2' := (eq_sort l c' t1' t2').
  Local Notation eq_term c' t e1 e2 := (eq_term l c' t e1 e2).
  Local Notation eq_subst c c' s1' s2' := (eq_subst l c c' s1' s2').
  Local Notation eq_args c c' s1' s2' := (eq_args l c c' s1' s2').

  (*
  Local Notation weak2_sort_cut_admissible c' t1' t2' := (weak2_sort_cut_admissible l c' t1' t2').
  Local Notation weak2_term_cut_admissible c' t e1 e2 := (weak2_term_cut_admissible l c' t e1 e2).
  Local Notation weak2_subst_cut_admissible c c' s1' s2' := (weak2_subst_cut_admissible l c c' s1' s2').
  Local Notation weak2_args_cut_admissible c c' s1' s2' := (weak2_args_cut_admissible l c c' s1' s2').
*)

  Context (Hla : lang_cut_admissible l).
  Context (l' : lang)
    (wsl' : wf_lang l')
    (Hincl : incl l l').

  Section WithCtx.
  Context (c : ctx).
  Context (wfc : wf_ctx c).
  Context (Hca1 : ctx_cut_admissible l c).
  Context (Hca2 : ctx_cut_admissible l' c).

  
  Hint Resolve eq_sort_lang_mono : lang_core.
  Hint Resolve eq_term_lang_mono : lang_core.
  Hint Resolve eq_args_lang_mono : lang_core.
  Hint Resolve eq_subst_lang_mono : lang_core.
  Hint Resolve ctx_lang_mono : lang_core.


  Lemma weak_cut_admissible
    : (forall t1' t2',
          eq_sort c t1' t2' ->
          sort_cut_admissible l' c t1' t2'
             /\ sort_cut_admissible l' c t1' t1'
             /\ sort_cut_admissible l' c t2' t2')
      /\ (forall (t : Term.sort V) (e1 e2 : Term.term V),
             eq_term c t e1 e2 ->
             term_cut_admissible l' c t e1 e2
             /\ term_cut_admissible l' c t e1 e1
             /\ term_cut_admissible l' c t e2 e2
             /\ sort_cut_admissible l' c t t)
      /\ (forall (c' : Term.ctx V) (s1 s2 : Term.subst V),
            eq_subst c c' s1 s2 ->
            wf_ctx c' -> ctx_cut_admissible l c' -> ctx_cut_admissible l' c' ->
            subst_cut_admissible l' c c' s1 s2
            /\ subst_cut_admissible l' c c' s1 s1
            /\ subst_cut_admissible l' c c' s2 s2)
      /\ (forall c' (s1 s2 : list term),
            eq_args c c' s1 s2 ->
            wf_ctx c' -> ctx_cut_admissible l c' -> ctx_cut_admissible l' c' ->
            args_cut_admissible l' c c' s1 s2
            /\ args_cut_admissible l' c c' s1 s1
            /\ args_cut_admissible l' c c' s2 s2).
  Proof.
    simple eapply cut_ind.
    all: unfold term_cut_admissible, sort_cut_admissible, subst_cut_admissible, args_cut_admissible.
    all: basic_goal_prep.
    all: try use_rule_in_wf; autorewrite with lang_core utils in *.
    all: repeat split.
    all: basic_goal_prep.
    all: erewrite ?subst_assoc; try typeclasses eauto;[|shelve..].
    all: fold_Substable.
    all: try lazymatch goal with
           | H : lang_cut_admissible ?l, H' : In _ ?l |- _ =>
               let Hl := fresh H in
               pose proof H as Hl;
              eapply lang_admissible_in in H ; [| eassumption | exact H' | eassumption | eassumption];
              cbn in H;
               eapply lang_admissible_in in Hl;
               [| eassumption | exact H' |  | eapply incl_refl];
               [|eassumption];
              cbn in Hl
           end.
    (*
    all: repeat lazymatch goal with
           | H : incl ?l _, H' : forall l', incl ?l l' -> _ |- _ =>
               specialize (H' _ H)
           end.
     *)
   (* all:
      lazymatch goal with
      | Hincl : incl l ?l' |- _ =>
      repeat match goal with
           | H : wf_ctx ?c |- _ =>
               tryif lazymatch goal with H : WithVar.wf_ctx l' c |- _ => idtac end
               then fail
               else pose proof H; eapply ctx_lang_mono in H; [| eassumption]
           | H : eq_sort ?c ?t1 ?t2 |- _ =>
               tryif lazymatch goal with H : WithVar.eq_sort l' c t1 t2 |- _ => idtac end
               then fail
               else pose proof H; 
               eapply eq_sort_lang_mono in H; [| eassumption]
           | H : eq_term ?c ?t ?e1 ?e2 |- _ =>
               tryif lazymatch goal with H : WithVar.eq_term l' c t e1 e2 |- _ => idtac end
               then fail
               else pose proof H;                
               eapply eq_sort_lang_mono in H; [| eassumption]
           (*| H : ctx_cut_admissible _ _ |- _ =>
               eapply ctx_cut_admissible_mono in H; [| eassumption]*)
        end
      end.*)
    all: repeat match goal with
           | H : ?A, H' : ?A -> _ |- _ =>
               let x := type of A in
               unify x Prop;
               specialize (H' H)
           | H : ?A /\ _, H' : ?A -> _ |- _ =>
               let x := type of A in
               unify x Prop;
               specialize (H' (proj1 H))
           | H' : ctx_cut_admissible ?l ?c -> _ |- _ =>
               specialize (H' ltac:(intuition eauto))
           | H : (_ -> _) /\ _ |- _ =>
               destruct H
           | H : wf_ctx ?c, H' : WithVar.wf_ctx _ ?c -> _ |- _ =>
               specialize (H' ltac:(eauto using ctx_lang_mono))
           end.
    all: try eapply eq_sort_cong; eauto.
    all: try now intuition eauto using eq_sort_by, eq_sort_cong with lang_core.

    (*
    all: repeat lazymatch goal with
           | H' : forall (l' : list (V * rule)), _ |- _ =>
               specialize (H' l')
           end.
     *)
    {
      eapply eq_sort_trans; intuition eauto using eq_sort_by, eq_subst_refl_right.
    }
    {
      eapply eq_sort_sym;
        intuition eauto using eq_subst_refl_right, eq_subst_sym' with lang_core.
      (*eapply H0.
      admit (*Not provable: make sym admissible & add conclusion here?*).*)
    }
    (*
    {
      eapply eq_term_by; eauto.
      eapply H1; intuition eauto using ctx_cut_admissible_mono with lang_core.
      }
     *)
    {
      eapply eq_term_conv;
        try now intuition eauto with lang_core.
      eapply Hla; intuition eauto using eq_subst_refl_right with lang_core.
    }
    {
      rewrite <- !Substable.with_names_from_args_subst.
      eapply eq_term_cong; eauto.
      eapply H1; intuition eauto using ctx_cut_admissible_mono with lang_core.
    }
    {
      rewrite <- !Substable.with_names_from_args_subst.
      eapply eq_term_conv.
      {
        eapply eq_term_cong; eauto.
        eapply H7; intuition eauto using ctx_cut_admissible_mono with lang_core.
      }
      {
        eapply Hla; eauto.
        eapply eq_args_implies_eq_subst.
        eapply H1; eauto.
        all: intuition eauto using eq_subst_refl_right with lang_core.
      }     
    }
    {
      rewrite <- !Substable.with_names_from_args_subst.
      eapply eq_term_conv.
      {
        eapply eq_term_cong; eauto.
        eapply H8; intuition eauto using ctx_cut_admissible_mono with lang_core.
      }
      {
        eapply Hla; eauto.
        eapply eq_args_implies_eq_subst.
        eapply H8; intuition eauto.
        all: intuition eauto using eq_subst_refl_right with lang_core.
      }     
    }
    {
      eapply Hla; eauto.
      rewrite <- !Substable.with_names_from_args_subst.
      eapply eq_args_implies_eq_subst.
      eapply H7; intuition eauto using ctx_cut_admissible_mono with lang_core.
    }
    {
      eapply ctx_admissible_in; try eassumption.
        eauto using eq_subst_refl_right, eq_subst_sym'
        with lang_core utils.
    }
    {
      eapply eq_term_trans; intuition eauto using eq_sort_by, eq_subst_refl_right.
    }
    {
      eapply eq_term_sym.
      eapply eq_term_conv; 
        eauto using eq_subst_refl_right, eq_subst_sym'
        with lang_core utils.
    }
    1-3:eapply eq_term_conv; now eauto using eq_subst_refl_right.
    all: constructor; [basic_core_crush |].
    all: eapply eq_term_conv; [basic_core_crush|].
    all: unfold sort_cut_admissible in *.
    1-3: erewrite subst_assoc; try typeclasses eauto; eauto;
    erewrite ?eq_subst_map_fst_r by eassumption;
    [|basic_core_crush].
    all: fold_Substable.
    1-3: unfold apply_subst at 2 4.
    all: unfold substable_subst.
    all: autorewrite with lang_core in *.
    all: break.
    2:{
      fold_Substable.
      eapply H5; eauto with utils.
      eapply eq_subst_sym';
           eauto using ctx_lang_mono.
      eapply H0; eauto using eq_subst_refl_right.
    }     
    all: try erewrite <- !subst_assoc; try typeclasses eauto; eauto using  eq_subst_refl_right.
    1,2:shelve.
    all: try erewrite subst_assoc; try typeclasses eauto; eauto using eq_subst_refl_right; [| shelve].
    all: rewrite !Substable.with_names_from_args_subst.
    all: eapply H5; eauto with utils.
    all: fold_Substable.
    all: rewrite <- !Substable.with_names_from_args_subst.
    all: autorewrite with lang_core in *.
    2: eapply eq_subst_sym';    
      intuition eauto using eq_subst_refl_right, eq_subst_sym', ctx_lang_mono.
    all: eapply eq_args_implies_eq_subst;
      intuition eauto using eq_subst_refl_right, eq_subst_sym', ctx_lang_mono.
    Unshelve.
    all: rewrite ?map_fst_with_names_from.
    all: erewrite ?eq_subst_map_fst_r by eassumption.
    all: erewrite ?eq_subst_map_fst_l by eassumption.
    all: autorewrite with lang_core in *.
    all: eauto with lang_core.
    all: try erewrite eq_args_len_eq_r; intuition eauto with lang_core.
  Qed.
  End WithCtx.

  Lemma ctx_cut_is_admissible c
    : wf_ctx c ->
      ctx_cut_admissible l' c .
  Proof.
    induction 1;
      basic_goal_prep;
      intuition subst.
    all:intros ? ? ? ?.
    all:eapply (proj1 (weak_cut_admissible c _ _)); eauto.
    Unshelve.
    all:eauto.
  Qed.

End WithLang.


Section WithLang.
  Context (l : lang)
    (wfl : wf_lang l).
  Context (l' : lang)
    (wfl' : wf_lang l')
    (Hincl : incl l l').

  Context (Hla : lang_cut_admissible l).

  Lemma cut_admissible' c
    : wf_ctx l c ->
      (forall t1' t2',
          eq_sort l c t1' t2' ->
          sort_cut_admissible l' c t1' t2'
             /\ sort_cut_admissible l' c t1' t1'
             /\ sort_cut_admissible l' c t2' t2')
      /\ (forall (t : Term.sort V) (e1 e2 : Term.term V),
             eq_term l c t e1 e2 ->
             term_cut_admissible l' c t e1 e2
             /\ term_cut_admissible l' c t e1 e1
             /\ term_cut_admissible l' c t e2 e2
             /\ sort_cut_admissible l' c t t)
      /\ (forall (c' : Term.ctx V) (s1 s2 : Term.subst V),
            eq_subst l c c' s1 s2 ->
            wf_ctx l c' ->
            subst_cut_admissible l' c c' s1 s2
            /\ subst_cut_admissible l' c c' s1 s1
            /\ subst_cut_admissible l' c c' s2 s2)
      /\ (forall c' (s1 s2 : list term),
            eq_args l c c' s1 s2 ->
            wf_ctx l c' ->
            args_cut_admissible l' c c' s1 s2
            /\ args_cut_admissible l' c c' s1 s1
            /\ args_cut_admissible l' c c' s2 s2).
  Proof.
    intro wfc.
    assert (ctx_cut_admissible l c) as Hca
             by  intuition eauto using ctx_cut_is_admissible with lang_core utils.
    assert (ctx_cut_admissible l' c) as Hca'
             by  intuition eauto using ctx_cut_is_admissible with lang_core utils.
    pose proof (weak_cut_admissible l wfl Hla l' wfl' Hincl c wfc Hca') as Hweak.
    (*pose proof (weak_cut_admissible l wfl Hla l wfl (incl_refl l) c wfc Hca).*)
    unfold term_cut_admissible, sort_cut_admissible,
      subst_cut_admissible, args_cut_admissible in *.
    intuition.
    all: lazymatch goal with
         | Hsub : eq_subst l _ ?c' ?s1 ?s2,
             Hctx : wf_ctx l ?c'
           |- eq_subst l' _ ?c' _ _ =>
             specialize (H0 _ _ _ Hsub Hctx ltac:(eauto using ctx_cut_is_admissible with lang_core utils)
                                                   ltac:(eauto using ctx_cut_is_admissible with lang_core utils))
         | Hsub : eq_args l _ ?c' ?s1 ?s2,
             Hctx : wf_ctx l ?c'
           |- eq_args l' _ ?c' _ _ =>
             specialize (H3 _ _ _ Hsub Hctx ltac:(eauto using ctx_cut_is_admissible with lang_core utils)
                                                   ltac:(eauto using ctx_cut_is_admissible with lang_core utils))
           end; now intuition.
(*    {
      intuition.
    repeat split; intros.
    all: eapply H in H0; clear H.
    all: intuition eauto using ctx_cut_is_admissible.*)
(*    all: eapply H || eapply H0 || eapply H7; eauto using ctx_cut_is_admissible, ctx_cut_admissible_mono.
    all: eapply ctx_cut_is_admissible; eauto.
    all: eapply ctx_cut_admissible_mono; eauto.
    TODO: build incl into ctx_cut? wrong direction...
    all: eapply ctx_cut_is_admissible; eauto.
    TODO: need l' wf
    issue: admissible for l, but have wf_ctx for l'*)
  Qed.

  Lemma rule_admissible r
    : wf_rule l r -> rule_cut_admissible l' r.
  Proof.
    unfold rule_cut_admissible;
      destruct 1;
      intuition eauto using ctx_cut_is_admissible;
      try now (eapply (proj1 (cut_admissible' _ ltac:(eassumption))); eauto).
    all: (eapply (proj1 (proj2 (cut_admissible' _ ltac:(eassumption)))); eauto).
  Qed.

End WithLang.

(*
Section WithLang.
  Context (l : lang)
    (wfl : wf_lang l).

  Context (Hla : lang_cut_admissible l).
  Context (c : ctx)
    (wfc : wf_ctx l c).

  Lemma cut_admissible'
    : (forall t1' t2',
          eq_sort l c t1' t2' ->
          forall c' s1 s2,
          eq_subst l c' c s1 s2 -> wf_ctx l c' -> eq_sort l c' t1' [/s1 /] t2' [/s2 /])
      /\ (forall (t : Term.sort V) (e1 e2 : Term.term V),
             eq_term l c t e1 e2 ->
             forall c' s1 s2,
             eq_subst l c' c s1 s2 -> wf_ctx l c' -> eq_term l c' t [/s2 /] e1 [/s1 /] e2 [/s2 /])
      /\ (forall (c' : Term.ctx V) (s1 s2 : Term.subst V),
             eq_subst l c c' s1 s2 ->
             wf_ctx l c' ->
             forall (c'' : named_list sort) (s1' s2' : named_list term),
               eq_subst l c'' c s1' s2' -> eq_subst l c'' c' s1 [/s1' /] s2 [/s2' /])
      /\ (forall c' (s1 s2 : list term),
             eq_args l c c' s1 s2 ->
             wf_ctx l c' ->
             forall (c'' : named_list sort) (s1' s2' : named_list term),
               eq_subst l c'' c s1' s2' -> eq_args l c'' c' s1 [/s1' /] s2 [/s2' /]).
  Proof.
    pose proof (cut_admissible l wfl Hla c wfc).
    unfold weak2_term_cut_admissible, weak2_sort_cut_admissible,
      weak2_subst_cut_admissible, weak2_args_cut_admissible,
      term_cut_admissible, sort_cut_admissible,
      subst_cut_admissible, args_cut_admissible in *.
    repeat split; intros.
    all: eapply H in H0; clear H.
    all: eapply H0; eauto with utils.
  Qed.

  (*
  Lemma rule_admissible r
    : wf_rule l r -> rule_cut_admissible l r.
  Proof.
    unfold rule_cut_admissible;
      destruct 1;
      intuition eauto using ctx_cut_is_admissible;
      try now (eapply (proj1 (cut_admissible _ ltac:(eassumption))); eauto).
    all: (eapply (proj1 (proj2 (cut_admissible _ ltac:(eassumption)))); eauto).
  Qed.*)

End WithLang.
*)


(*
Lemma rule_cut_admissible_mono l l' r
  : incl l l' -> rule_cut_admissible l r -> rule_cut_admissible l' r.
Proof.
  unfold rule_cut_admissible, ctx_cut_admissible
    term_cut_admissible, sort_cut_admissible,
    subst_cut_admissible, args_cut_admissible in *.
  destruct r;
    basic_goal_prep.
 *)

(*
Lemma lang_cut_admissible' l l'
  : wf_lang l -> wf_lang l' -> incl l l' -> all (rule_cut_admissible l') (map snd l).
Proof.
  induction 1;
    basic_goal_prep;
    [tauto|].
  basic_utils_crush.
  unfold rule_cut_admissible.
  eapply rule_admissible'; eauto.
  basic
 *)

(*
Lemma rule_admissible l r
  : wf_lang l -> lang_cut_admissible l ->
    wf_rule l r -> rule_cut_admissible l r.
Proof.
  unfold rule_cut_admissible;
    destruct 3.
    intuition eauto using ctx_cut_is_admissible;
    try now (eapply (proj1 (cut_admissible _ ltac:(eassumption))); eauto).
  all: (eapply (proj1 (proj2 (cut_admissible _ ltac:(eassumption)))); eauto).
Qed.*)

Lemma lang_is_cut_admissible l
  : wf_lang l ->  lang_cut_admissible l.
Proof.
  unfold lang_cut_admissible.
  induction 1;
    basic_goal_prep;
    basic_core_crush.
  eapply rule_admissible.
  4: eauto.
  all: eauto.
Qed.

Section WithLang.
  Context (l : lang)
    (wfl : wf_lang l).

  Section WithCtx.
  Context (c : ctx)
    (wfc : wf_ctx l c).

  Theorem cut_admissible
    : (forall t1' t2',
          eq_sort l c t1' t2' ->
          sort_cut_admissible l c t1' t2')
      /\ (forall (t : Term.sort V) (e1 e2 : Term.term V),
             eq_term l c t e1 e2 ->
             term_cut_admissible l c t e1 e2)
      /\ (forall (c' : Term.ctx V) (s1 s2 : Term.subst V),
            eq_subst l c c' s1 s2 ->
            wf_ctx l c' ->
            subst_cut_admissible l c c' s1 s2)
      /\ (forall c' (s1 s2 : list term),
            eq_args l c c' s1 s2 ->
            wf_ctx l c' ->
            args_cut_admissible l c c' s1 s2).
  Proof.
    intuition; eapply cut_admissible'; eauto using lang_is_cut_admissible with utils.
  Qed.

  End WithCtx.

  Section CoreWfLang.
    Context (wfl_core : Core.wf_lang l).
  
  Section WithCtx.
  Context (c : ctx)
    (wfc_core : Model.wf_ctx (Model:= core_model l) c).
                 
  Lemma cut_implies_core 
    : (forall t1 t2,
          eq_sort l c t1 t2 ->
          Core.eq_sort l c t1 t2)
      /\ (forall t e1 e2,
             eq_term l c t e1 e2 ->
             Core.eq_term l c t e1 e2)
      /\ (forall c' s1 s2,
             eq_subst l c c' s1 s2 ->
             Model.eq_subst (Model := core_model l) c c' s1 s2)
      /\ (forall c' s1 s2,
             eq_args l c c' s1 s2 ->
             Model.eq_args (Model := core_model l) c c' s1 s2).
  Proof using V_Eqb_ok wfl_core wfc_core.
    simple eapply cut_ind;
      basic_goal_prep;
      autorewrite with utils term model lang_core in *.
    all: eauto using
           sort_con_congruence,
        Core.eq_sort_trans, Core.eq_sort_sym,
        term_con_congruence,
        Core.eq_term_trans, Core.eq_term_sym
      with lang_core.      
  Qed.


  Definition eq_sort_cut_implies_core := proj1 cut_implies_core.
  Local Hint Resolve eq_sort_cut_implies_core : lang_core.
  
  Definition eq_term_cut_implies_core := proj1 (proj2 cut_implies_core).
  Local Hint Resolve eq_term_cut_implies_core : lang_core.

  Definition eq_subst_cut_implies_core := proj1 (proj2 (proj2 cut_implies_core)).
  Local Hint Resolve eq_subst_cut_implies_core : lang_core.
  
  Definition eq_args_cut_implies_core := proj2 (proj2 (proj2 cut_implies_core)).
  Local Hint Resolve eq_args_cut_implies_core : lang_core.

  End WithCtx.
    
  Lemma core_implies_cut
    : (forall c t1 t2,
          Core.eq_sort l c t1 t2 ->
          eq_sort l c t1 t2)
      /\ (forall c t e1 e2,
             Core.eq_term l c t e1 e2 ->
             eq_term l c t e1 e2)
      /\ (forall c c' s1 s2,
             Model.eq_subst (Model:= core_model l) c c' s1 s2 ->
             eq_subst l c c' s1 s2)
      /\ (forall c t,
             wf_sort l c t ->
             eq_sort l c t t)
      /\ (forall c e t,
             wf_term l c e t ->
             eq_term l c t e e)
      /\ (forall c s c',
             wf_args (Model:= core_model l) c s c' ->
             eq_args l c c' s s)
      /\ (forall c,
             Model.wf_ctx (Model:= core_model l) c -> wf_ctx l c).
  Proof using V_Eqb_ok wfl.
    simple eapply judge_ind.
    all: basic_goal_prep.
    all:eauto using  eq_sort_sym, eq_sort_trans,
        eq_term_sym, eq_term_trans, eq_term_conv, eq_term_var with lang_core.
    {
      erewrite <- sort_subst_id with (c:=c) (a:= t1) by typeclasses eauto.
      erewrite <- sort_subst_id with (c:=c) (a:= t2) by typeclasses eauto.
      fold_Substable.
      eapply eq_sort_by; eauto.
      eapply cut_id_subst_refl.
    }
    {
      eapply cut_admissible; cycle 1; eauto.
    }
    {
      eapply cut_admissible; cycle 1; eauto.
    }
    {
      erewrite <- sort_subst_id with (c:=c) (a:= t) by typeclasses eauto.
      erewrite <- term_subst_id with (c:=c) (a:= e1) by typeclasses eauto.
      erewrite <- term_subst_id with (c:=c) (a:= e2) by typeclasses eauto.
      fold_Substable.
      eapply eq_term_by; eauto.
      eapply cut_id_subst_refl.
    }
  Qed.

  Lemma ctx_iff_cut c
    : Model.wf_ctx (Model:= core_model l) c <-> wf_ctx l c.
  Proof.
    split; [ eapply core_implies_cut |].
    induction 1;
      basic_goal_prep;
      constructor; eauto.
    all: try eapply Core.eq_sort_wf_r; eauto.
    all: try eapply cut_implies_core; eauto.
  Qed.
  
  Lemma rule_iff_cut r
    : Core.wf_rule l r <-> wf_rule l r.
  Proof using V_Eqb_ok V_default wfl wfl_core.
    destruct r;
      autorewrite with lang_core;
      intuition.
    all: try eapply core_implies_cut; eauto.
    all: try eapply Core.eq_sort_wf_r; eauto.
    all: try eapply Core.eq_term_wf_r; eauto.
    all: try eapply cut_implies_core; eauto.
    all: eapply ctx_iff_cut; eauto.
  Qed.

  End CoreWfLang.

End WithLang.

Lemma wf_lang_iff_cut l
  : Core.wf_lang l <-> wf_lang l.
Proof.
  split; induction 1;
    autorewrite with utils lang_core in *;
    intuition; try constructor;
    eauto with lang_core.
  all: eapply rule_iff_cut; eauto.
Qed.

End WithVar.
