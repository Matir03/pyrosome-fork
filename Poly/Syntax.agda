{-# OPTIONS --safe --sized-types #-}

module Poly.Syntax where

open import Size
open import Data.Bool
open import Data.Unit
open import Data.List.Base as L hiding ([_])
open import Data.List.All hiding (mapA; sequenceA)
open import Data.List.Properties using (map-++-commute;++-assoc)
open import Data.Product as Prod
open import Data.Product using (Σ-syntax)
open import Function hiding (case_of_)
open import Relation.Binary.PropositionalEquality hiding ([_])

open import Data.Var hiding (z; s)
open import Relation.Unary
open import Data.Environment as E hiding (sequenceA)

-- TODO: should be in environent/descutils
extendΔ : {J : Set} → {Δ' Δ : List J} → Thinning Δ (Δ' ++ Δ)
extendΔ {Δ' = []} = E.identity
E.lookup (extendΔ  {Δ' = x ∷ Δ'}) v = E.lookup extend (E.lookup extendΔ v)

-- Descriptions and their Interpretation

record DescTy (J : Set) : Set₁ where
  field
    type : J ─Scoped
    th^Ty : ∀ {j} → Thinnable (type j)
  
  Tp : List J → Set
  Tp Δ = Σ[ j ∈ J ] type j Δ

  ↑Δ : ∀{j Δ'} → ∀[ type j ⇒ (Δ' ++_) ⊢ type j ]
  ↑Δ ty = th^Ty ty extendΔ

open DescTy


data Desc {J : Set} (I : DescTy J) (Δ : List J) : Set₁ where
  `σ : (A : Set) → (A → Desc I Δ) → Desc I Δ
  `T : (j : J) → Desc I Δ → Desc I Δ
  `X : (Δ' : List J) → List (Tp I (Δ' ++ Δ)) → Tp I (Δ' ++ Δ) → Desc I (Δ' ++ Δ) → Desc I Δ
  `∎ :  Tp I Δ  → Desc I Δ

--Simple descriptions (i.e. with simple types)
SDesc : Set → Set₁
SDesc I = Desc {⊤} (record { type = const (const I) ; th^Ty = th^const }) []

-- simple X, where no type variables are bound
`SX : {I : Set} → List I → I → SDesc I → SDesc I
`SX Γ i d = `X [] (L.map (tt ,_) Γ) (tt , i) d

`S∎ : {I : Set} → I → SDesc I
`S∎ i = `∎ (tt , i)

cast : ∀{ℓ} → ∀ {A : Set} → ∀ {a b : A} → a ≡ b → (P : A → Set ℓ) → P a → P b
cast refl P = id

--TODO: move cast to utils

reindex : ∀{J L : Set} → {I : DescTy J} → {K : DescTy L} →
          (f : J → L) → (∀{i Δ} → type I i Δ → type K (f i) (L.map f Δ)) → ∀{Δ} → Desc I Δ → Desc K (L.map f Δ)
reindex f g (`σ A d)   = `σ A λ a → reindex f g (d a)
reindex f g (`T j d) = `T (f j) (reindex f g d)
reindex {I = I} {K = K} f g {Δ} (`X Δ' Γ j d) =
  `X (L.map f Δ') (L.map mapg Γ) (mapg j) (cast (map-++-commute f Δ' Δ) (Desc K) (reindex f g d)) where
    mapg : Tp I (Δ' ++ Δ) → Tp K (L.map f Δ' ++ L.map f Δ)
    mapg = (Prod.map f (cast (map-++-commute f Δ' Δ) (type K (f _)) ∘ g))
reindex f g (`∎ i)     = `∎ (Prod.map f g i)

-- old reindexing for simple descriptions
sreindex : {I J : Set} → (I → J) → SDesc I → SDesc J
sreindex f = reindex id f

{- TODO
-- simpler version that does not reindex types
reindex' : ∀{J} → {I K : J ─Scoped} → ∀₂[ I ⇒₂ K ] → Desc I → Desc K
reindex' g = reindex id {!TODO: should just be g (modulo types)!}

-- only reindexes types
reindexᵗ : {J K : Set} → {I : J ─Scoped} → (J → K) → Desc I → Desc {!!}
reindexᵗ f = reindex f id
-}

Tp-Scoped : ∀{J} → DescTy J → List J → Set₁
Tp-Scoped {J} I Δ = (Δ' : List J) → List (Tp I (Δ' ++ Δ)) → (Tp I (Δ' ++ Δ)) ─Scoped

_─Scoped² : ∀ {J} → DescTy J → List J → Set₁
(I ─Scoped²) Δ = (Tp I Δ) ─Scoped

private
  variable
    J : Set
    I : DescTy J
    j : J
    Δ : List J
    i σ : type I j Δ
    Γ₁ Γ₂ : List (Tp I Δ)
    s : Size
    X Y : Tp-Scoped I Δ

⟦_⟧ : ∀[ Desc I ⇒ Tp-Scoped I ⇒ I ─Scoped² ]
⟦ `σ A d    ⟧ X i Γ = Σ[ a ∈ A ] (⟦ d a ⟧ X i Γ)
⟦_⟧ {I = I} {Δ} (`T j d) X i Γ = type I j Δ × ⟦ d ⟧ X i Γ
⟦_⟧ {I = I} {Δ} (`X Δ' Γ' j d) X i Γ =
  X Δ' Γ' j ↑Γ × ⟦ d ⟧ ↑X (map₂ (↑Δ I) i) ↑Γ where
  ↑Γ : List (Tp I (Δ' ++ Δ))
  ↑Γ = L.map (map₂ (↑Δ I)) Γ
  ↑X : Tp-Scoped I (Δ' ++ Δ)
  ↑X Δ'' Γ ty Γ' =
    X (Δ'' ++ Δ')
      (cast (sym (++-assoc Δ'' Δ' Δ)) (List ∘ (Tp I)) Γ)
      (cast (sym (++-assoc Δ'' Δ' Δ)) (Tp I) ty)
      (cast (sym (++-assoc Δ'' Δ' Δ)) (List ∘ (Tp I)) Γ')
⟦ `∎ j      ⟧ X i Γ = i ≡ j

-- TODO: Desc to type
-- TODO: type in terms???

-- Syntaxes: Free Relative Monad of a Description's Interpretation


Scope : J ─Scoped → List J → J ─Scoped
Scope T Δ i = (Δ ++_) ⊢ T i


module _ {J : Set} {I : DescTy J} where

  ↑ΔD : ∀ Δ' → ∀[ Desc I ⇒ (Δ' ++_) ⊢ Desc I ]
  ↑ΔD Δ' (`σ A d) = `σ A (λ a → ↑ΔD Δ' (d a))
  ↑ΔD Δ' (`T j d) = `T j (↑ΔD Δ' d)
  ↑ΔD Δ' (`X Δ'' Γ i d) = `X Δ'' {!L.map (map₂ (↑Δ I)) Γ!} (map₂ (↑Δ I) i) {!↑ΔD Δ'!}
  ↑ΔD Δ' (`∎ x) = {!!}

  --TODO: this only scopes Γ
  Scope² : Π[ I ─Scoped² ⇒ List ∘ (Tp I) ⇒ I ─Scoped² ]
  Scope² Δ T Γ i = (Γ ++_) ⊢ T i

  data Tm (Δ : List J) (d : Desc I Δ) : Size → (I ─Scoped²) Δ where
    -- TODO: why is the quantified I wrong?
    `var  : ∀{i} → ∀[ Var i ⇒ Tm Δ d (↑ s) i ]
    `con  : ∀{i} → ∀[ ⟦ d ⟧
      (λ Δ' Γ → Scope² (Δ' ++ Δ) (Tm (Δ' ++ Δ) (↑ΔD Δ' d) s) (L.map (map₂ (↑Δ _)) Γ)) i  ⇒ Tm Δ d (↑ s) i ]

{-
module _ {I i Γ} {d : Desc I} where

  `var-inj : ∀ {t u} → (Tm d ∞ i Γ ∋ `var t) ≡ `var u → t ≡ u
  `var-inj refl = refl

  `con-inj : ∀ {t u} → (Tm d ∞ i Γ ∋ `con t) ≡ `con u → t ≡ u
  `con-inj refl = refl

-- Closed terms
module _ {I : Set} where

  TM : Desc I → I → Set
  TM d i = Tm d ∞ i []


-- Descriptions are closed under sums
-}
--TODO: `+ for non-simple descriptions
module _ {I : Set} where

 infixr 5 _`+_


 _`+_ : SDesc I → SDesc I → SDesc I
 d `+ e = `σ Bool $ λ isLeft →
          if isLeft then d else e
{-
module _ {I : Set} {d e : SDesc I} {X : List I → I ─Scoped}
         {A : Set} {i : I} {Γ : List I} where

 case : (⟦ d ⟧ X i Γ → A) → (⟦ e ⟧ X i Γ → A) →
        (⟦ d `+ e  ⟧ X i Γ → A)
 case l r (true   , t) = l t
 case l r (false  , t) = r t


module PAPERXS {I : Set} where
-- Descriptions are closed under products of recursive positions


 `Xs : List (List I × I) → Desc I → Desc I
 `Xs Δjs d = foldr (uncurry `X) d Δjs


module PAPER {I : Set} {d : Desc I} {X : List I → I ─Scoped} {i : I} {Γ : List I} where
 open PAPERXS

 unXs :  ∀ Δjs → ⟦ `Xs Δjs d ⟧ X i Γ →
         All (uncurry $ λ Δ j → X Δ j Γ) Δjs × ⟦ d ⟧ X i Γ

 unXs []       v        = [] , v
 unXs (σ ∷ Δ)  (r , v)  = Prod.map₁ (r ∷_) (unXs Δ v)


module _ {I : Set} where
-- Descriptions are closed under products of recursive positions


 `Xs : List I → Desc I → Desc I
 `Xs js d = foldr (`X []) d js


module _ {I : Set} {d : Desc I} {X : List I → I ─Scoped} {i : I} {Γ : List I} where

 unXs : ∀ Δ → ⟦ `Xs Δ d ⟧ X i Γ → (Δ ─Env) (X []) Γ × ⟦ d ⟧ X i Γ
 unXs []       v       = ε , v
 unXs (σ ∷ Δ)  (r , v) = Prod.map₁ (_∙ r) (unXs Δ v)

-- Descriptions give rise to traversable functors

module _ {I : Set} {X Y : List I → I ─Scoped} {Γ Δ} {i} where


 fmap :  (d : Desc I) → (∀ Θ i → X Θ i Γ → Y Θ i Δ) → ⟦ d ⟧ X i Γ → ⟦ d ⟧ Y i Δ
 fmap (`σ A d)    f = Prod.map₂ (fmap (d _) f)
 fmap (`X Δ j d)  f = Prod.map (f Δ j) (fmap d f)
 fmap (`∎ i)      f = id


 fmap-ext : (d : Desc I) {f g : ∀ Θ i → X Θ i Γ → Y Θ i Δ} →
            (f≈g : ∀ Θ i x → f Θ i x ≡ g Θ i x) (v : ⟦ d ⟧ X i Γ) →
            fmap d f v ≡ fmap d g v
 fmap-ext (`σ A d)   f≈g (a , v) = cong (a ,_) (fmap-ext (d a) f≈g v)
 fmap-ext (`X Δ j d) f≈g (r , v) = cong₂ _,_ (f≈g Δ j r) (fmap-ext d f≈g v)
 fmap-ext (`∎ i)     f≈g v       = refl

module _ {I : Set} {X : List I → I ─Scoped} where

 fmap-id : (d : Desc I) {Γ : List I} {i : I} (v : ⟦ d ⟧ X i Γ) → fmap d (λ _ _ x → x) v ≡ v
 fmap-id (`σ A d)    (a , v)  = cong (a ,_) (fmap-id (d a) v)
 fmap-id (`X Δ j d)  (r , v)  = cong (r ,_) (fmap-id d v)
 fmap-id (`∎ x)      v        = refl

module _ {I : Set} {X Y Z : List I → I ─Scoped} where

 fmap² : (d : Desc I) {Γ Δ Θ : List I} {i : I}
         (f : ∀ Φ i → X Φ i Γ → Y Φ i Δ) (g : ∀ Φ i → Y Φ i Δ → Z Φ i Θ)
         (t : ⟦ d ⟧ X i Γ) →
         fmap  {I} {Y} {Z} d g (fmap d f t) ≡ fmap d (λ Φ i → g Φ i ∘ f Φ i) t
 fmap² (`σ A d)    f g (a , t)  = cong (_ ,_) (fmap² (d a) f g t)
 fmap² (`X Δ j d)  f g (r , t)  = cong (_ ,_) (fmap² d f g t)
 fmap² (`∎ i)      f g t        = refl


open import Category.Applicative

module _ {A : Set → Set} {{app : RawApplicative A}} where

 module A = RawApplicative app
 open A

 sequenceA : (d : Desc I) →
             ∀[ ⟦ d ⟧ (λ Δ j Γ → A (X Δ j Γ)) i ⇒ A ∘ ⟦ d ⟧ X i ]
 sequenceA (`σ A d)    (a , t)  = (λ b → a , b) A.<$> sequenceA (d a) t
 sequenceA (`X Δ j d)  (r , t)  = _,_ A.<$> r ⊛ sequenceA d t
 sequenceA (`∎ i)      t        = pure t

 mapA : (d : Desc I) →
        (f : ∀ Δ j → X Δ j Γ₁ → A (Y Δ j Γ₂))
        → ⟦ d ⟧ X σ Γ₁ → A (⟦ d ⟧ Y σ Γ₂)
 mapA d f = sequenceA d ∘ fmap d f

-- Desc Morphisms

record DescMorphism {I : Set} (d e : Desc I) : Set₁ where
  constructor MkDescMorphism
  field apply : ∀ {X i Δ} → ⟦ d ⟧ X i Δ → ⟦ e ⟧ X i Δ

module _ {I : Set} {d e : Desc I} where

  map^Tm : DescMorphism d e → ∀ {i σ Γ} → Tm d i σ Γ → Tm e i σ Γ
  map^Tm f (`var v) = `var v
  map^Tm f (`con t) = `con (DescMorphism.apply f (fmap d (λ _ _ → map^Tm f) t))
-}
