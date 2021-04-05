Require Import mathcomp.ssreflect.all_ssreflect.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Set Bullet Behavior "Strict Subproofs".

Require Import String.
From Utils Require Import Utils.
From Named Require Import Exp ARule Matches ImCore.
Import OptionMonad.

(* Proofs of wfness and relatedness

   Note: wfexps are not canonical due to wfconv,
   so there are pairs of wfexp that should be considered
   equivalent but are not equal.
   TODO: weaken properties appropriately to take this
   into account
 *)
Unset Elimination Schemes.
(*using one datatype for terms and sorts*)
Inductive wfexp : Set :=
(* variable name; congruence for variables *)
| wf_var : string -> wfexp
(* Rule label, list of subterms*)
(* congruence for constructors *)
| wf_con : string -> list wfexp -> wfexp
| wf_conv : pf -> wfexp -> wfexp
with pf : Set :=
(* appealing to a language axiom *)
| ax : string -> pf
| pf_refl : wfexp -> pf
| sym : pf -> pf
| trans : pf -> pf -> pf
| pf_subst : named_list_set pf -> pf -> pf
| pf_conv : pf -> pf -> pf.
Set Elimination Schemes.

Ltac break_monadic_do :=
  repeat (lazymatch goal with
          | [H : Some _ = Some _|-_] => inversion H; clear H
          | [H : Some _ = None|-_] => inversion H
          | [H : None = Some _ |-_] => inversion H
          | [H : Some _ = named_list_lookup_err _ _ |-_] =>
            apply named_list_lookup_err_in in H;
            try (let H' := fresh H in
                 pose proof H as H';
                 apply rule_in_wf in H'; inversion H'; clear H')
          | [H : true = (?a == ?b) |-_] =>
            symmetry in H;
            move: H => /eqP H
          | [H : false = true |-_] =>inversion H
          | [H : false = (?a == ?a) |-_] =>
            rewrite eq_refl in H; inversion H
          | |- context [ match ?e with
                         | _ => _
                         end ] => let e' := fresh in
                                  remember e as e'; destruct e'
          | [H:context [ match ?e with
                         | _ => _
                         end ] |-_] => let e' := fresh in
                                       remember e as e'; destruct e'
          end; subst; simpl in * ).

(*Stronger induction principles w/ better subterm knowledge.
  The default inductions for wfexp and pf are independent of
  eachother since to do mutual induction, you likely need
  a combined scheme anyway.
  
 *)
Section Induction.
  Context (P : wfexp -> Prop)
         (IHV : forall n, P(wf_var n))
         (IHC : forall n l, List.Forall P l -> P (wf_con n l))

         (Q : pf -> Prop)
         (IHA : forall n, Q(ax n))
         (IHSY : forall e', Q e' -> Q (sym e'))
         (IHT : forall e1 e2,
             Q e1 -> Q e2 -> Q (trans e1 e2))
         (IHS : forall p s,
             Q p ->
             List.Forall Q (map snd s) ->
             Q (pf_subst s p))
         (IHCVP : forall p e, Q p -> Q e -> Q (pf_conv p e)).

    Context
    (IHCV : forall p e, Q p -> P e -> P (wf_conv p e))
    (IHR : forall e, P e -> Q(pf_refl e)).

   Fixpoint wfexp_ind' (e : wfexp) { struct e} : P e :=
    match e with
    | wf_var n => IHV n
    | wf_con n l =>
      let fix loop l :=
          match l return List.Forall P l with
          | [::] => List.Forall_nil _
          | e' :: l' => List.Forall_cons _ (wfexp_ind' e') (loop l')
          end in
      IHC n (loop l)
    | wf_conv e1 e2 => IHCV (pf_ind' e1) (wfexp_ind' e2)
    end
   with pf_ind' (e : pf) { struct e} : Q e :=
    match e with
    | ax n => IHA n
    | pf_refl e => IHR (wfexp_ind' e)
    | sym e' => IHSY (pf_ind' e')
    | trans e1 e2 => IHT (pf_ind' e1) (pf_ind' e2)
    | pf_subst s p =>
      let fix loop l :=
          match l return List.Forall Q (map snd l) with
          | [::] => List.Forall_nil _
          | p :: l' => List.Forall_cons _ (pf_ind' p.2) (loop l')
          end in
      IHS (pf_ind' p) (loop s)
    | pf_conv e1 e2 => IHCVP (pf_ind' e1) (pf_ind' e2)
    end.

   Definition combined_wfexp_pf_ind
     : (forall e, P e) /\ (forall p, Q p) :=
     conj wfexp_ind' pf_ind'.

   Context
         (IHCV_no_mut : forall p e, P e -> P (wf_conv p e))
         (IHR_no_mut : forall e, Q(pf_refl e)).
  
  Fixpoint wfexp_ind (e : wfexp) { struct e} : P e :=
    match e with
    | wf_var n => IHV n
    | wf_con n l =>
      let fix loop l :=
          match l return List.Forall P l with
          | [::] => List.Forall_nil _
          | e' :: l' => List.Forall_cons _ (wfexp_ind e') (loop l')
          end in
      IHC n (loop l)
    | wf_conv e1 e2 => IHCV_no_mut e1 (wfexp_ind e2)
    end.

  Fixpoint pf_ind (e : pf) { struct e} : Q e :=
    match e with
    | ax n => IHA n
    | pf_refl e => IHR_no_mut e
    | sym e' => IHSY (pf_ind e')
    | trans e1 e2 => IHT (pf_ind e1) (pf_ind e2)
    | pf_subst s p =>
      let fix loop l :=
          match l return List.Forall Q (map snd l) with
          | [::] => List.Forall_nil _
          | p :: l' => List.Forall_cons _ (pf_ind p.2) (loop l')
          end in
      IHS (pf_ind p) (loop s)
    | pf_conv e1 e2 => IHCVP (pf_ind e1) (pf_ind e2)
    end.
End Induction.

(*
  TODO: non-prop induction schemes
Fixpoint pf_rect
         (P : pf -> Type)
         (IHV : forall n, P(pvar n))
         (IHC : forall n l,
             List.fold_right (fun t => prod (P t)) unit l ->
             P (pcon n l))
         (IHA : forall n pfs, 
             List.fold_right (fun p => prod (P p)) unit pfs -> P(ax n pfs))
         (IHSY : forall e', P e' -> P (sym e'))
         (IHT : forall e1 e2,
             P e1 -> P e2 -> P (trans e1 e2))
         (IHCV : forall e1 e2,
             P e1 -> P e2 -> P (conv e1 e2))
         (e : pf) { struct e} : P e :=
  match e with
  | pvar n => IHV n
  | pcon n l =>
    let fix loop l :=
        match l return List.fold_right (fun t => prod (P t)) unit l with
        | [::] => tt
        | e' :: l' => (pf_rect IHV IHC IHA IHSY IHT IHCV e',loop l')
        end in
    IHC n l (loop l)
  | ax n pfs => 
    let fix loop l :=
        match l return List.fold_right (fun t => prod (P t)) unit l with
        | [::] => tt
        | e' :: l' => (pf_rect IHV IHC IHA IHSY IHT IHCV e',loop l')
        end in
    IHA n pfs (loop pfs)
  | sym e' =>
    IHSY e' (pf_rect IHV IHC IHA IHSY IHT IHCV e')
  | trans e1 e2 =>
    IHT e1 e2 (pf_rect IHV IHC IHA IHSY IHT IHCV e1)
        (pf_rect IHV IHC IHA IHSY IHT IHCV e2)
  | conv e1 e2 =>
    IHCV e1 e2 (pf_rect IHV IHC IHA IHSY IHT IHCV e1)
        (pf_rect IHV IHC IHA IHSY IHT IHCV e2)
  end.

Definition pf_rec := 
[eta pf_rect]
     : forall P : pf -> Set, _.
*)


Definition subst_wf : Set := named_list_set wfexp.
Definition subst_pf : Set := named_list_set pf.


(*TODO:move to Utils        
Lemma get_subseq_exact (s : subst)
  : Some s = get_subseq (map fst s) s.
Proof.
  induction s; intros; break; simpl in *; auto.
  rewrite ?eq_refl.
  rewrite <-IHs; eauto.
Qed.

Lemma get_subseq_nil (s : subst)
  : Some [::] = get_subseq [::] s.
Proof.
  destruct s; simpl; reflexivity.
Qed.
*)

(* TODO: recover at some point
Section RuleChecking.
  Context (l : lang) (wfl : wf_lang l).

  Section InnerLoop.
    Context (synth_le_term : pf -> ctx -> option (sort*exp*exp)).

    Fixpoint synth_le_args (pl : list pf) (c c' : ctx) {struct pl}
      : option (list exp * list exp) :=
      match pl with
      | [::] => do [::] <- do ret c'; ret ([::],[::])
      | p::pl' =>
        do (_,t)::c'' <- do ret c';
           (t',e1,e2) <- synth_le_term p c;
           (el1,el2) <- synth_le_args pl' c c'';
           ! t' == t[/with_names_from c'' el2/];
           ret (e1::el1, e2::el2)
     end.

    Fixpoint synth_le_sort (pt : pf) (c : ctx) : option (sort * sort) :=
      match pt with
      | pvar x => None
      | pcon name pl =>
        do (sort_rule c' args) <- named_list_lookup_err l name;
           (el1, el2) <- synth_le_args pl c c';
           al1 <- get_subseq args (with_names_from c' el1);
           al2 <- get_subseq args (with_names_from c' el2);
           ret (scon name (map snd al1), scon name (map snd al2))
      | ax name pfs =>
        do (sort_le c' e1 e2) <- named_list_lookup_err l name;
           (el1, el2) <- synth_le_args pfs c c';
           let s1 := with_names_from c' el1;
           let s2 := with_names_from c' el2;
           ret (e1[/s1/],e2[/s2/])
      | sym p =>
        do (e1,e2) <- synth_le_sort p c;
           ret (e2,e1)
      | trans p1 p2 =>
        do (e1,e2) <- synth_le_sort p1 c;
           (e2',e3) <- synth_le_sort p2 c;
           !e2 == e2';
           ret (e1,e3)
      | conv pt p => None
    end.

    Lemma synth_le_args_size_l l0 l1 l2 c c0
      : Some (l1, l2) = synth_le_args l0 c c0 ->
        size l1 = size c0.
    Proof.
      revert l1 l2 c0.
      induction l0; intros; destruct c0; break; simpl in *; try by (inversion H; subst; auto).
      revert H.
      case_match; [| intro H; inversion H];
        break.
      case_match; [| intro H; inversion H];
        break.
      case_match; [| intro H; inversion H];
        break.
      symmetry in HeqH1.
      case.
      move: HeqH1 => /eqP.
      intros.
      subst.
      simpl.
      f_equal; eauto.
    Qed.

    Lemma synth_le_args_size_r l0 l1 l2 c c0
      : Some (l1, l2) = synth_le_args l0 c c0 ->
        size l2 = size c0.
    Proof.
      revert l1 l2 c0.
      induction l0; intros; destruct c0; break; simpl in *; try by (inversion H; subst; auto).
      revert H.
      case_match; [| intro H; inversion H];
        break.
      case_match; [| intro H; inversion H];
        break.
      case_match; [| intro H; inversion H];
        break.
      symmetry in HeqH1.
      case.
      move: HeqH1 => /eqP.
      intros.
      subst.
      simpl.
      f_equal; eauto.
    Qed.


  End InnerLoop.

  (* Defined over proof and implicit terms
   *)
  Fixpoint synth_le_term (p : pf) (c : ctx) {struct p} : option (sort*exp*exp) :=
    match p with
    | pvar x =>
      do t <- named_list_lookup_err c x;
         ret (t,var x, var x)
    | pcon name pl =>
      do (term_rule c' args t) <- named_list_lookup_err l name;
         (el1, el2) <- synth_le_args synth_le_term pl c c';
         al1 <- get_subseq args (with_names_from c' el1);
         al2 <- get_subseq args (with_names_from c' el2);
         ret (t[/with_names_from c' el2/],
              con name (map snd al1), con name (map snd al2))
      | ax name pfs =>
        do (term_le c' e1 e2 t) <- named_list_lookup_err l name;
           (el1, el2) <- synth_le_args synth_le_term pfs c c';
           let s1 := with_names_from c' el1;
           let s2 := with_names_from c' el2;
           ret (t[/s2/],e1[/s1/],e2[/s2/])
    | sym p' =>
      do (t,e1,e2) <- synth_le_term p' c;
         ret (t,e2,e1)
    | trans p1 p2 =>
      do (t,e1,e2) <- synth_le_term p1 c;
         (t',e2',e3) <- synth_le_term p2 c;
         ! t == t';
         ! e2 == e2';
         ret (t,e1,e3)
    | conv pt p' =>
      do (t, e1, e2) <- synth_le_term p' c;
         (t', t1) <- synth_le_sort synth_le_term pt c;
         ! t == t';
         ret (t1,e1,e2)
  end.

  Inductive pf_term_ind : pf -> Set :=
  | ind_var x : pf_term_ind (pvar x)
  | ind_con n pl : pf_args_ind pl -> pf_term_ind (pcon n pl)
  | ind_ax n pl : pf_args_ind pl -> pf_term_ind (ax n pl)
  | ind_sym p : pf_term_ind p -> pf_term_ind (sym p)
  | ind_trans p1 p2 : pf_term_ind p1 -> pf_term_ind p2 -> pf_term_ind (trans p1 p2)
  | ind_conv pt p : pf_sort_ind pt -> pf_term_ind p -> pf_term_ind (conv pt p)
  with pf_args_ind : list pf -> Set :=
  | pf_args_ind_nil : pf_args_ind [::]
  | pf_args_ind_cons p pl : pf_args_ind pl -> pf_term_ind p -> pf_args_ind (p::pl)
  with pf_sort_ind : pf -> Set :=
    (*TODO: include or no?*)
  | sind_var x : pf_sort_ind (pvar x)
  | sind_con n pl : pf_args_ind pl -> pf_sort_ind (pcon n pl)
  | sind_ax n pl : pf_args_ind pl -> pf_sort_ind (ax n pl)
  | sind_sym p : pf_sort_ind p -> pf_sort_ind (sym p)
  | sind_trans p1 p2 : pf_sort_ind p1 -> pf_sort_ind p2 -> pf_sort_ind (trans p1 p2)
  (* TODO: include or no?*)
  | sind_conv pt p : pf_sort_ind (conv pt p).


  Section InnerLoop.
    Context (pf_term_ind_trivial : forall p, pf_term_ind p).
    Fixpoint pf_args_ind_trivial pl : pf_args_ind pl :=
          match pl as pl return pf_args_ind pl with
          | [::] => pf_args_ind_nil
          | p :: pl' =>
            pf_args_ind_cons (pf_args_ind_trivial pl') (pf_term_ind_trivial p)
          end.
  End InnerLoop.

  Fixpoint pf_term_ind_trivial p : pf_term_ind p :=
    match p with
    | pvar x => ind_var x
    | pcon name pl =>
      ind_con name (pf_args_ind_trivial pf_term_ind_trivial pl)
    | ax name pl => ind_ax name (pf_args_ind_trivial pf_term_ind_trivial pl)
    | sym p' => ind_sym (pf_term_ind_trivial p')
    | trans p1 p2 =>
      ind_trans (pf_term_ind_trivial p1) (pf_term_ind_trivial p2)
    | conv pt p' =>
      ind_conv (pf_sort_ind_trivial pt) (pf_term_ind_trivial p')
    end
  with pf_sort_ind_trivial p : pf_sort_ind p :=
    match p with
    | pvar x => sind_var x
    | pcon name pl => sind_con name (pf_args_ind_trivial pf_term_ind_trivial pl)
    | ax name pl => sind_ax name (pf_args_ind_trivial pf_term_ind_trivial pl)
    | sym p' => sind_sym (pf_sort_ind_trivial p')
    | trans p1 p2 =>
      sind_trans (pf_sort_ind_trivial p1) (pf_sort_ind_trivial p2)
    | conv pt p' =>
      sind_conv pt p'
    end.

 

   Lemma synth_le_args_related' (pl : list pf)  (pa : pf_args_ind pl) c c' el1 el2 args al1 al2 al1' al2'
       : Some (el1,el2) = synth_le_args synth_le_term pl c c' ->
         Some al1 = get_subseq args (with_names_from c' el1) ->
         Some al2 = get_subseq args (with_names_from c' el2) ->
         al1' = (map snd al1) ->
         al2' = (map snd al2) ->
         le_args l c c' al1' al2' args el1 el2
   with synth_le_sort_related' (p : pf)  (ps : pf_sort_ind p) c e1 e2
    : Some (e1,e2) = synth_le_sort synth_le_term p c ->
      le_sort l c e1 e2
   with synth_le_term_related' (p : pf) (pt : pf_term_ind p) c t e1 e2
    : Some (t,e1,e2) = synth_le_term p c ->
      le_term l c t e1 e2.
   Proof using wfl.
     {
       inversion pa; intros; break; simpl in *;
         break_monadic_do; constructor;
           eauto using get_subseq_nil with imcore.
     }
    
     {
       inversion ps; intros; break; simpl in *;
       break_monadic_do; eauto with imcore.
      {
        eapply le_sort_subst; eauto with imcore.
        eapply le_subst_from_args.
        eapply synth_le_args_related'; eauto.
        eapply get_subseq_exact.
        assert (map fst (with_names_from c0 l0) = map fst (with_names_from c0 l1)).
        {
          rewrite !map_fst_with_names_from; eauto using synth_le_args_size_r, synth_le_args_size_l.
        }
        rewrite H1.
        eapply get_subseq_exact.
      }
     }
     {
       inversion pt; intros; break; simpl in *;
       break_monadic_do; eauto with imcore.
       {
         eapply le_term_subst; eauto with imcore.
         eapply le_subst_from_args.
         eapply synth_le_args_related'; eauto.
         eapply get_subseq_exact.
         assert (map fst (with_names_from c0 l0) = map fst (with_names_from c0 l1)).
         {
           rewrite !map_fst_with_names_from; eauto using synth_le_args_size_r, synth_le_args_size_l.
         }
         rewrite H1.
         eapply get_subseq_exact.
       }
     }
   Qed.

   Lemma synth_le_args_related (pl : list pf) c c' el1 el2 args al1 al2
       : Some (el1,el2) = synth_le_args synth_le_term pl c c' ->
         Some al1 = get_subseq args (with_names_from c' el1) ->
         Some al2 = get_subseq args (with_names_from c' el2) ->
         le_args l c c' (map snd al1) (map snd al2) args el1 el2.
   Proof using wfl.
     intros; eapply synth_le_args_related'; eauto using pf_args_ind_trivial,pf_term_ind_trivial.
   Qed.
   Hint Resolve synth_le_args_related : imcore.
   
   Lemma synth_le_sort_related (p : pf) c e1 e2
    : Some (e1,e2) = synth_le_sort synth_le_term p c ->
      le_sort l c e1 e2.
   Proof using wfl.
     apply synth_le_sort_related'; eauto using pf_sort_ind_trivial, pf_args_ind_trivial,pf_term_ind_trivial.
   Qed.
   Hint Resolve synth_le_sort_related : imcore.

   Lemma synth_le_term_related (p : pf) c t e1 e2
    : Some (t,e1,e2) = synth_le_term p c ->
      le_term l c t e1 e2.
   Proof using wfl.
     apply synth_le_term_related'; eauto using pf_term_ind_trivial.
   Qed.
   Hint Resolve synth_le_term_related : imcore.
   

  Section InnerLoop.
    Context (synth_wf_term : pf -> ctx -> option (sort*exp)).

    Fixpoint synth_wf_args (pl : list pf) (c c' : ctx) {struct pl}
      : option (list exp) :=
      match pl with
      | [::] => do [::] <- do ret c'; ret ([::])
      | p::pl' =>
        do (_,t)::c'' <- do ret c';
           (t',e) <- synth_wf_term p c;
           el <- synth_wf_args pl' c c'';
           ! t' == t[/with_names_from c'' el/];
           ret (e::el)
     end.
  End InnerLoop.

  (* Defined over proof and implicit terms
   *)
  Fixpoint synth_wf_term (p : pf) (c : ctx) {struct p} : option (sort*exp) :=
    match p with
    | pvar x =>
      do t <- named_list_lookup_err c x;
         ret (t,var x)
    | pcon name pl =>
      do (term_rule c' args t) <- named_list_lookup_err l name;
         el <- synth_wf_args synth_wf_term pl c c';
         al <- get_subseq args (with_names_from c' el);
         ret (t[/with_names_from c' el/], con name (map snd al))
    | ax _ _ => None
    | sym p' => None
    | trans p1 p2 => None
    | conv pt p' =>
      do (t, e) <- synth_wf_term p' c;
         (t', t1) <- synth_le_sort synth_le_term pt c;
         ! t == t';
         ret (t1,e)
  end.

  Definition synth_wf_sort (pt : pf) (c : ctx) : option sort :=
      match pt with
      | pvar x => None
      | pcon name pl =>
        do (sort_rule c' args) <- named_list_lookup_err l name;
           el <- synth_wf_args synth_wf_term pl c c';
           al <- get_subseq args (with_names_from c' el);
           ret (scon name (map snd al))
      | ax _ _ => None
      | sym p => None
      | trans p1 p2 => None
      | conv pt p => None
  end.
  

  Fixpoint synth_wf_ctx pl : option ctx :=
    match pl with
    | [::] => do ret [::]
    | (name,p)::pl' =>
      do c' <- synth_wf_ctx pl';
         ! fresh name c';
         t <- synth_wf_sort p c';
         ret (name,t)::c'
  end.

   Lemma synth_wf_args_related' (pl : list pf) (ipl : pf_args_ind pl) c c' el args al al'
       : Some (el) = synth_wf_args synth_wf_term pl c c' ->
         Some al = get_subseq args (with_names_from c' el) ->
         al' = map snd al -> 
         wf_args l c al' args el c'
   with synth_wf_term_related' (p : pf) (ip : pf_term_ind p) c t e
    : Some (t,e) = synth_wf_term p c ->
      wf_term l c e t.
   Proof using wfl.
     {
       inversion ipl; intros; break; simpl in *;
         break_monadic_do; constructor;
           eauto using get_subseq_nil with imcore.
     }
     {
       inversion ip; intros; break; simpl in *;
       break_monadic_do; eauto with imcore.
     }
   Qed.

   Lemma synth_wf_args_related (pl : list pf) c c' el args al
     : Some (el) = synth_wf_args synth_wf_term pl c c' ->
       Some al = get_subseq args (with_names_from c' el) ->
       wf_args l c (map snd al) args el c'.
   Proof using wfl.
     intros; eapply synth_wf_args_related'; eauto using pf_args_ind_trivial,pf_term_ind_trivial.
   Qed.
   Hint Resolve synth_wf_args_related : imcore.
    
   Lemma synth_wf_term_related (p : pf) c e t
    : Some (t,e) = synth_wf_term p c ->
      wf_term l c e t.
   Proof using wfl.
     intros; eapply synth_wf_term_related'; eauto using pf_args_ind_trivial,pf_term_ind_trivial.
   Qed.
   Hint Resolve synth_wf_term_related : imcore.

   Lemma synth_wf_sort_related (p : pf) c t
    : Some t = synth_wf_sort p c ->
      wf_sort l c t.
   Proof using wfl.
     destruct p; intros; break; simpl in *;
       break_monadic_do; eauto with imcore.
   Qed.
   Hint Resolve synth_wf_sort_related : imcore.

   Lemma synth_wf_ctx_related pl c
    : Some c = synth_wf_ctx pl ->
      wf_ctx l c.
   Proof using wfl.
     revert c; induction pl; intros; break; simpl in *;
       break_monadic_do; constructor; eauto with imcore.
   Qed.
   
   Hint Resolve synth_wf_ctx_related : imcore.
 *)

Variant wfexp_rule : Set :=
 | wf_sort_rule : named_list_set wfexp -> list string -> wfexp_rule
 | wf_term_rule : named_list_set wfexp -> list string -> wfexp -> wfexp_rule
 | wf_sort_le : named_list_set wfexp -> wfexp -> wfexp -> wfexp_rule
 | wf_term_le : named_list_set wfexp -> wfexp -> wfexp -> wfexp (*sort; TODO: not needed*)-> wfexp_rule.

   
Definition wfexp_lang := named_list wfexp_rule.
Definition wfexp_ctx := named_list wfexp.

(*
   Definition synth_wf_rule rp : option rule :=
    match rp with
    | sort_rule_pf pl args =>
      do c <- synth_wf_ctx pl;
         ! subseq args (map fst c);
         ret sort_rule c args
    | term_rule_pf pl args p =>
      do c <- synth_wf_ctx pl;
         t <- synth_wf_sort p c;
         ! subseq args (map fst c);
         ret term_rule c args t
    | sort_le_pf pl p1 p2 =>
      do c <- synth_wf_ctx pl;
         t1 <- synth_wf_sort p1 c;
         t2 <- synth_wf_sort p2 c;
         ret sort_le c t1 t2
    | term_le_pf pl p1 p2 pt =>
      do c <- synth_wf_ctx pl;
         (t1,e1) <- synth_wf_term p1 c;
         (t2,e2) <- synth_wf_term p2 c;
         t <- synth_wf_sort pt c;
         ! t == t1;
         ! t == t2;
         ret term_le c e1 e2 t
    end.

  Lemma synth_wf_rule_related pr r
    : Some r = synth_wf_rule pr ->
      wf_rule l r.
   Proof using wfl.
     revert r; destruct pr; intros; break; simpl in *;
       break_monadic_do; constructor; eauto with imcore.
   Qed.
   Hint Resolve synth_wf_rule_related : imcore.
       
End RuleChecking.
*)

Fixpoint eq_wfexp e1 e2 {struct e1} : bool :=
  match e1, e2 with
  | wf_var x, wf_var y => x == y
  | wf_con n1 l1, wf_con n2 l2 =>
    (eqb n1 n2) && (all2 eq_wfexp l1 l2)
  | wf_conv p1a p1b, wf_conv p2a p2b => (eq_pf p1a p2a) && (eq_wfexp p1b p2b)
  | _,_ => false
  end
with eq_pf e1 e2 {struct e1} : bool :=
  match e1, e2 with
  | ax n1, ax n2 => n1 == n2
  | pf_refl e1', pf_refl e2' => eq_wfexp e1' e2'
  | sym p1', sym p2' => (eq_pf p1' p2')
  | trans p1a p1b, trans p2a p2b => (eq_pf p1a p2a) && (eq_pf p1b p2b)
  | pf_conv p1a p1b, pf_conv p2a p2b => (eq_pf p1a p2a) && (eq_pf p1b p2b)
  | pf_subst s1 p1, pf_subst s2 p2 =>
    (eq_pf p1 p2) && (all2 (eq_pr String.eqb eq_pf) s1 s2)
  | _,_ => false
  end.

Require Import Utils.BoolAsProp.

Ltac solve_rewrite_goal :=
  solve [intuition; try match goal with [H:_=_|-_]=>inversion H end; f_equal; eauto].

Ltac rewrite_by_hyp :=
  match goal with
    [H : forall x, _ <-> _ |- _] =>
    rewrite H
  end.

(*TODO: move to bool utils*)
Lemma invert_cons A (e :A) es e' es'
  : e::es = e'::es' <-> e = e' /\ es = es'.
Proof.
  solve_rewrite_goal.
Qed.
Hint Rewrite invert_cons : bool_utils.
Lemma invert_pair A B (a a': A) (b b' : B)
  : (a,b) = (a',b') <-> a = a' /\ b = b'.
Proof.
  solve_rewrite_goal.
Qed.
Hint Rewrite invert_pair : bool_utils.

Local Lemma rewrite_eqs_combined
  : (forall e1 e2, eq_wfexp e1 e2 <-> e1 = e2)
    /\ (forall e1 e2, eq_pf e1 e2 <-> e1 = e2).
Proof.
  apply combined_wfexp_pf_ind; intros;
    match goal with
      [|- _ <-> _ = ?e2] =>
      destruct e2
    end;
    simpl;
    autorewrite with bool_utils.
  all: repeat rewrite_by_hyp; try solve_rewrite_goal.
  {
    let H := fresh in 
    enough (all2 eq_wfexp l l0 <-> l = l0) as H;
      [rewrite H; solve_rewrite_goal|].

    revert l0; induction l; intro l0; destruct l0; simpl;
      autorewrite with bool_utils; try solve_rewrite_goal.
    inversion H.
    rewrite H2.
    rewrite IHl; eauto.
    solve_rewrite_goal.
  }
  {
    let H := fresh in 
    enough (all2 (eq_pr eqb eq_pf) s n <-> s = n) as H;
      [rewrite H; solve_rewrite_goal|].

    revert n; induction s; intro l0; destruct l0; break; simpl;
      autorewrite with bool_utils; try solve_rewrite_goal.
    inversion H0.
    rewrite H3.
    rewrite IHs; eauto.
    solve_rewrite_goal.
  }
Qed.

Definition rewrite_eq_wfexp : forall e1 e2, eq_wfexp e1 e2 <-> e1 = e2
  := proj1 rewrite_eqs_combined.
Hint Rewrite rewrite_eq_wfexp : imcore.
Definition rewrite_eq_pf : forall e1 e2, eq_pf e1 e2 <-> e1 = e2
  := proj2 rewrite_eqs_combined.
Hint Rewrite rewrite_eq_pf : imcore. 
    

Lemma eq_pfP : forall e1 e2, reflect (e1 = e2) (eq_pf e1 e2).
  intros; apply Bool.iff_reflect; symmetry; apply rewrite_eq_pf.
Qed.
     
Definition pf_eqMixin := Equality.Mixin eq_pfP.

Canonical pf_eqType := @Equality.Pack pf pf_eqMixin.


Lemma eq_wfexpP : forall e1 e2, reflect (e1 = e2) (eq_wfexp e1 e2).
  intros; apply Bool.iff_reflect; symmetry; apply rewrite_eq_wfexp.
Qed.
     
Definition wfexp_eqMixin := Equality.Mixin eq_wfexpP.

Canonical wfexp_eqType := @Equality.Pack wfexp wfexp_eqMixin.

(*

Fixpoint synth_wf_lang rpl : option lang :=
  match rpl with
  | [::] => do ret [::]
  | (name,rp)::rpl' =>
    do l' <- synth_wf_lang rpl';
       ! fresh name l';
       r <- synth_wf_rule l' rp;
       ret (name,r)::l'
  end.


Lemma synth_wf_lang_related pl l
  : Some l = synth_wf_lang pl ->
    wf_lang l.
Proof.
  revert l; induction pl; intros; break; simpl in *;
    break_monadic_do; constructor; eauto with imcore.
  eapply synth_wf_rule_related; eauto with imcore.
Qed.
*)

Lemma with_names_from_names_eq {A B C:Set}
      (l1 : named_list A) (l1' : named_list B) (l2 : list C)
  : map fst l1 = map fst l1' ->
    with_names_from l1 l2 = with_names_from l1' l2.
Proof.
  revert l1' l2; induction l1; intros; subst;
    destruct l1';
    destruct l2; break;simpl in *;auto;
    match goal with
      [ H : _ = _|- _] => inversion H; clear H
    end; subst; f_equal; eauto.
Qed.

Lemma with_names_from_snd {A:Set}
      (l : named_list A)
  : with_names_from l (map snd l) = l.
Proof.
  induction l; intros; break; simpl in *; f_equal;eauto.
Qed.
  
Lemma le_args_from_subst l c c' s1 s2
      : le_subst l c c' s1 s2 ->
        le_args l c c'
                (map snd s1) (map snd s2) (map fst c')
                (map snd s1) (map snd s2).
Proof.
  intro les; induction les; simpl; constructor; eauto with imcore.
  erewrite with_names_from_names_eq;
    [| symmetry; eapply le_subst_names_eq_r];
    eauto.
  rewrite with_names_from_snd; auto.
Qed.  

(*
(*Determines whether the proofs represent equal expressions *)
Definition eq_pf_term (l : lang) c (p1 p2 : pf) : bool :=
  synth_wf_term l p1 c == synth_wf_term l p2 c.
Definition eq_pf_sort (l : lang) c (p1 p2 : pf) : bool :=
  synth_wf_sort l p1 c == synth_wf_sort l p2 c.
*)

Fixpoint wfexp_subst (s : named_list wfexp) (p : wfexp) : wfexp :=
      match p with
      | wf_var x => named_list_lookup (wf_var x) s x
      | wf_con name pl =>
        wf_con name (map (wfexp_subst s) pl)
      | wf_conv pt p => wf_conv (pf_subst (named_map pf_refl s) pt) (wfexp_subst s p)
  end.

(*
Definition check_le_sort l pf c t t' :=
  Some(t',t) = synth_le_sort l (synth_le_term l) pf c.

Definition check_le_term l pf c t e1 e2 :=
  Some(t,e1, e2) = synth_le_term l pf c.

Definition check_wf_term l pf c e t :=
  Some(t,e) = synth_wf_term l pf c.

Definition check_le_subst l pf c (c':ctx) s1 s2 :=
  match synth_le_args (synth_le_term l) pf c c' with
  | Some (es1, es2) =>
    (with_names_from c' es1 == s1) &&
    (with_names_from c' es2 == s2)
  | None => false
  end.
*)

(*
Lemma check_le_subst_false_cons_nil_l l p ps c c' s2
  : check_le_subst l (p::ps) c c' [::] s2 = false.
Proof.
  destruct c'; destruct s2; break; try reflexivity.
  unfold check_le_subst.
  simpl.
  case_match; break.
  revert HeqH; case_match; break.
  case_match; break.
    
Lemma le_subst_lookup_pf l ps c c' s1 s2 n t
  : check_le_subst l ps c c' s1 s2 ->
    all_fresh c' ->
    (n,t) \in c' ->
    check_le_term l (named_list_lookup (pvar n) (with_names_from c' ps) n)
                  c t [/s2 /] (subst_lookup s1 n) (subst_lookup s2 n).
Proof.
  revert c' s1 s2.
  induction ps; intros; destruct c'; destruct s1; destruct s2;
    repeat (break; simpl in *;
     try match goal with
         | [H: is_true(check_le_subst l [::] c (_:: _) _ _) |-_] =>
            vm_compute in H; inversion H
         | [H: is_true(check_le_subst l (_::_) c (_::_) [::] [::]) |-_]=>
            TODO
         | [H: is_true(check_le_subst l (_::_) c [::] _ _) |-_] =>
            vm_compute in H; inversion H
    | [ H : is_true(_ \in [::]) |-_] =>
    inversion H
    | [ H : is_true(_ \in _::_) |-_] =>
    rewrite in_cons in H; move: H => /orP []; intros
    | [ H : is_true(_ == _) |-_] =>
      move: H => /eqP; intros
    | [ H : (_,_)=(_,_) |-_] =>
      move: H; case; intros; subst
      end).
  cbn in H.

  Lemma check_le_subst_false_cons_nil_l
    : check_le_subst l (p::ps) c c' [::] s2 = false.
  
  hnf in H.
  rewrite a.
   
    cbv in H.


Lemma le_term_subst_pf l ps p c c' s1 s2 t e1 e2
  : wf_ctx l c' ->
    check_le_subst l ps c c' s1 s2 ->
    check_le_term l p c' t e1 e2 ->
    check_le_term l (pf_subst (with_names_from c' ps) p)
                  c t [/s2 /] e1 [/s1 /] e2 [/s2 /].
Proof.
  revert t e1 e2.
  induction p; intros; break; cbn in *.
  {
    hnf in H1; simpl in H1.
    revert H1; case_match; intro H1; inversion H1; subst.
    cbn.
    TODO: subst_lookup lem
*)
(*
Lemma synth_le_term_complete l c e1 e2 t
  : le_term l c t e1 e2 ->
    exists p, Some (t,e1,e2) = synth_le_term l p c
with synth_le_args_complete l c c' s1 s2 args es1 es2
     : le_args l c c' s1 s2 args es1 es2 ->
       exists p, Some (es1,es2) = synth_le_args (synth_le_term l) p c c'.
Proof.
  {
    intro lt; destruct lt.
    repeat lazymatch goal with
     | [ H : le_term _ _ _ _ _|-_] =>
      apply synth_le_term_complete in H;
        let p := fresh "p" in
        destruct H as [p H]
     | [ H : le_subst _ _ _ _ _|-_] =>
      apply le_args_from_subst in H;
      apply synth_le_args_complete in H;
        let p := fresh "p" in
        destruct H as [p H]
    end.
    (*TODO: define substitution on proofs, prove correct*)
     Search _ le_subst.
    Check le_subst_from_args.
    

*)

Definition eq_rule_pf r1 r2 : bool :=
  match r1, r2 with
  | wf_sort_rule c1 args1, wf_sort_rule c2 args2 => (c1 == c2) && (args1 == args2)
  | wf_term_rule c1 args1 t1, wf_term_rule c2 args2 t2 =>
    (c1 == c2) && (args1 == args2) && (t1 == t2)
  | wf_sort_le c1 t1 t1', wf_sort_le c2 t2 t2' =>
    (c1 == c2) && (t1 == t2) && (t1' == t2')
  | wf_term_le c1 e1 e1' t1, wf_term_le c2 e2 e2' t2 =>
    (c1 == c2) && (e1 == e2) && (e1' == e2') && (t1 == t2)
  | _,_ => false
  end.

Lemma eq_rule_pfP r1 r2 : reflect (r1 = r2) (eq_rule_pf r1 r2).
Proof using .
  destruct r1; destruct r2; simpl; solve_reflect_norec.
Qed.

Definition rule_pf_eqMixin := Equality.Mixin eq_rule_pfP.

Canonical rule_pf_eqType := @Equality.Pack wfexp_rule rule_pf_eqMixin.


Module Notations.

  
  Declare Custom Entry wfexp.
  Declare Custom Entry pf.

  Declare Custom Entry wfexp_ctx.
  Declare Custom Entry wfexp_ctx_binding.

  (* Since contexts are regular lists, 
     we need a scope to determine when to print them *)
  Declare Scope wfexp_ctx_scope.
  Bind Scope wfexp_ctx_scope with wfexp_ctx.

  
  Notation "'{{wf' e }}" := (e) (at level 0,e custom wfexp at level 100).
  Notation "'{{p' e }}" := (e) (at level 0,e custom pf at level 100).
  
  Notation "{ x }" :=
    x (in custom wfexp at level 0, x constr).
  (* TODO: issues; fix *)
  Notation "{ x }" :=
    x (in custom pf at level 0, x constr).
  (* TODO: issues; fix *)
  Notation "{ x }" :=
    x (in custom wfexp_ctx at level 0, x constr).

  
  Notation "( e )" := e (in custom wfexp at level 0, e custom wfexp at level 100).
  Notation "( e )" := e (in custom pf at level 0, e custom pf at level 100).
  
  Notation "# c" :=
    (wf_con c%string [::])
      (right associativity,in custom wfexp at level 0, c constr at level 0,
                              format "# c").
  
  Definition wf_constr_app e e' :=
    match e with
    | wf_con c l => wf_con c (e'::l)
    | _ => wf_con "ERR" [::]
    end.

  Notation "c e" :=
    (wf_constr_app c e)
      (left associativity, in custom wfexp at level 10,
                              c custom wfexp, e custom wfexp at level 9).

  
  Notation "< p > e" :=
    (wf_conv p e)
      (left associativity, in custom wfexp at level 9,
                              p custom pf, e custom wfexp at level 8).
  (*TODO: subst notation*)

  Notation "% x" :=
    (wf_var x%string)
      (in custom wfexp at level 0, x constr at level 0, format "% x").

  Notation "! c" :=
    (ax c%string)
      (right associativity,in custom pf at level 0, c constr at level 0,
                              format "! c").
  
  Notation "e" :=
    (pf_refl e)
      (right associativity,in custom pf at level 5, e custom wfexp at level 5,
                              format "e").

  Notation "p1 , p2" :=
    (trans p1 p2)
      (left associativity, in custom pf at level 30,
                              p1 custom pf, p2 custom pf at level 29).

  Notation "~ p1" :=
    (sym p1)
      (right associativity, in custom pf at level 25, p1 custom pf).
  
  Notation "< p > e" :=
    (pf_conv p e)
      (left associativity, in custom pf at level 9,
                              p custom pf, e custom pf at level 8).
  (*TODO: subst notation*)

  Check {{wf #"foo" }}.
  Check {{wf #"foo" (#"bar" %"x") #"baz" %"y"}}.
  Check {{wf <!"beta">(#"baz" %"y")}}.
  Check {{wf < <!"t_beta">!"beta", ~(#"baz" %"y"), (#"baz" %"y") >(#"baz" %"y")}}.
  
  Eval compute in {{wf #"foo" (#"bar" %"x") #"baz" %"y"}}.
  
  Notation "# c e1 .. en"
    := (wf_con c (cons en .. (cons e1 nil) ..))
      (left associativity,
         in custom pf at level 10,
            c constr at level 0,
            e1 custom pf at level 9,
            en custom pf at level 9,
            only printing, format "# c  e1  ..  en").
  
  Eval compute in {{wf #"foo" (#"bar" %"x") #"baz" %"y"}}.
  Eval compute in {{wf #"foo" }}.

  Notation "'{{pc' }}" := nil (at level 0) : wfexp_ctx_scope.
  Notation "'{{pc' bd , .. , bd' '}}'" :=
    (cons bd' .. (cons bd nil)..)
      (at level 0, bd custom wfexp_ctx_binding at level 100,
       format "'[' {{pc '[hv' bd ,  '/' .. ,  '/' bd' ']' }} ']'")
    : wfexp_ctx_scope.

  Notation "bd , .. , bd'" :=
    (cons bd' .. (cons bd nil)..)
      (in custom wfexp_ctx at level 100, bd custom wfexp_ctx_binding at level 100,
          format "'[hv' bd ,  '/' .. ,  '/' bd' ']'") : wfexp_ctx_scope.

  Notation "" := nil (*(@nil (string*sort))*)
                   (in custom wfexp_ctx at level 0) : wfexp_ctx_scope.

  Notation "x : t" :=
    (x%string, t)
      (in custom wfexp_ctx_binding at level 100, x constr at level 0,
          t custom wfexp at level 100).

  Local Definition as_ctx (c:wfexp_ctx) :=c.
  Check (as_ctx {{pc }}).
  Check (as_ctx {{pc "x" : #"env"}}).
  Check (as_ctx {{pc "x" : #"env", "y" : #"ty" %"x", "z" : #"ty" %"x"}}).

End Notations.

(*
Inductive ws_pf {c : list string} : pf -> Prop :=
| ws_var x : x \in c -> ws_pf (pvar x)
| ws_con n l : List.Forall ws_pf l -> ws_pf (pcon n l)
| ws_ax n l : List.Forall ws_pf l -> ws_pf (ax n l)
| ws_sym p : ws_pf p -> ws_pf (sym p)
| ws_trans p1 p2 : ws_pf p1 -> ws_pf p2 -> ws_pf (trans p1 p2)
| ws_conv p1 p2 : ws_pf p1 -> ws_pf p2 -> ws_pf (conv p1 p2).

Arguments ws_pf : clear implicits.

Fixpoint fv (p : pf) :=
  match p with
  | pvar x => [:: x]
  | pcon _ l => flat_map fv l
  | ax _ l => flat_map fv l
  | sym p => fv p
  | trans p1 p2 => fv p1 ++ fv p2
  | conv p1 p2 => fv p1 ++ fv p2
  end.
*)
