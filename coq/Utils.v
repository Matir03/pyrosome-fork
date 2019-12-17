
Require Import mathcomp.ssreflect.all_ssreflect.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Set Bullet Behavior "Strict Subproofs".

(***************
 Tactics 
****************)

Tactic Notation "intro_to" constr(ty) :=
  repeat match goal with
         | |- ty -> _ => idtac
         | |- ty _ -> _ => idtac
         | |- ty _ _-> _ => idtac
         | |- ty _ _ _ -> _ => idtac
         | |- ty _ _ _ _ -> _ => idtac
         | |- ty _ _ _ _ _ -> _ => idtac
         | |- ty _ _ _ _ _ _ -> _ => idtac
         | |- ty _ _ _ _ _ _ _ -> _ => idtac
         | |- _ -> _ => intro
         | |- _ => fail 2 "could not find argument with head" ty
         end.


Ltac construct_with t :=
  constructor; apply: t; eauto.


Tactic Notation "inversion" :=
  let H := fresh in
  move => H; inversion H.

Tactic Notation "swap" :=
  let H := fresh in
  let H' := fresh in
  move => H H';
  move: H' H.
  


(****************
Definitions
*****************)

(* grouped right with the fixpoint for better decreasing argument analysis*)
Definition all2 := 
fun (S T : Type) (r : S -> T -> bool) =>
fix all2 (s : seq S) (t : seq T) {struct s} : bool :=
  match s, t with
  | [::], [::] => true
  | x :: s0, y::t0 => r x y && all2 s0 t0
  | _,_ => false
  end.

Lemma all2P {T} eqb (l1 l2 : seq T)
  : (forall e1 e2, reflect (e1 = e2) (eqb e1 e2)) ->
    reflect (l1 = l2) (all2 eqb l1 l2).
Proof.
  move => eqbP.
  elim: l1 l2.
  - case; simpl; [by constructor|].
    intros.
    constructor; eauto.
    move => H; inversion H.
  - move => a l IH.
    case; simpl.
    constructor; move => H; inversion H.
    intros.
    move: (eqbP a a0).
    case (eqb a a0); simpl.
    move: (IH l0); case:(all2 eqb l l0); simpl.
    + constructor.
      inversion IH0; inversion eqbP0; by subst.
    + constructor.
      move => lfl.
      inversion lfl.
      inversion IH0; eauto.
    + constructor; move => lfl.
      inversion lfl; inversion eqbP0; auto.
Qed.

Notation " x <- e ; e'" := (obind (fun x => e') e)
  (*match e with None => None | Some x => e' end*)
    (right associativity, at level 88).

Definition try_map {A B : Type} (f : A -> option B) (l : seq A) : option (seq B) :=
  foldr (fun e acc =>
           accl <- acc;
             fe <- f e;
             Some (fe::accl)
        ) (Some [::]) l.

Lemma try_map_map_distribute {A B C : Type} (f : B -> option C) (g : A -> B) l
  : try_map f (map g l) = try_map (fun x => f (g x)) l.
Proof.
  elim: l => //=.
  intros; by rewrite H.
Qed.

Lemma omap_some {A B} (e' : B) (f : A -> B) me : Some e' = omap f me -> exists e, me = Some e.
Proof.
  case: me => //=; eauto.
Qed.

Lemma omap_some' {A B} (e' : B) (f : A -> B) me
  : Some e' = omap f me -> exists e, Some e' = omap f (Some e).
Proof.
  move => someeq.
  suff: exists e, me = Some e.
  move: someeq.
  swap.
  case => e ->.
  eauto.
  apply: omap_some; eauto.
Qed.