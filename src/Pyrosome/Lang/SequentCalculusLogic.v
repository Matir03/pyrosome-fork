Set Implicit Arguments.
Set Bullet Behavior "Strict Subproofs".

Require Import String List.
Require Import Coq.Strings.Ascii.
Import ListNotations.
Open Scope string.
Open Scope list.
From Utils Require Import Utils.
From Pyrosome Require Import Theory.Core Elab.Elab Tools.Matches.
Import Core.Notations.

Require Coq.derive.Derive.


Notation named_list := (@named_list string).
Notation named_map := (@named_map string).
Notation term := (@term string).
Notation ctx := (@ctx string).
Notation sort := (@sort string).
Notation subst := (@subst string).
Notation rule := (@rule string).
Notation lang := (@lang string).


Definition sequent_logic_def : lang :=
  {[l
  [s|
      -----------------------------------------------
      #"prop" srt
  ];

  [s|
      -----------------------------------------------
      #"env" srt
  ];
  [:| -----------------------------------------------
      #"emp": #"env"
  ];
  [:| "G": #"env", "A": #"prop"
      -----------------------------------------------
      #"ext" "G" "A": #"env"
  ];

  [:| "G": #"env", "H": #"env"
      -----------------------------------------------
      #"concat" "G" "H": #"env"
  ];
  [:= "G": #"env"
      ----------------------------------------------- ("concat_emp")
      #"concat" "G" #"emp" = "G" : #"env"
  ];
  [:= "G": #"env", "H": #"env", "A": #"prop"
      ----------------------------------------------- ("concat_ext")
      #"concat" "G" (#"ext" "H" "A") =
      #"ext" (#"concat" "G" "H") "A" : #"env"
  ];

  [:= "G": #"env", "A": #"prop"
      ----------------------------------------------- ("contraction")
      #"ext" (#"ext" "G" "A") "A" =
      #"ext" "G" "A" : #"env"
  ];
  [:= "G": #"env", "A": #"prop", "B": #"prop", "H": #"env"
      ----------------------------------------------- ("exchange")
      #"concat" (#"ext" (#"ext" "G" "A") "B") "H" =
      #"concat" (#"ext" (#"ext" "G" "B") "A") "H" : #"env"
  ];

  [s| "G": #"env", "A": #"prop"
      -----------------------------------------------
      #"entails" "G" "A" srt
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop",
      "e": #"entails" "G" "B"
      -----------------------------------------------
      #"weaken" "e": #"entails" (#"ext" "G" "A") "B"
  ];

  (* [:= "G": #"env", "A": #"prop",
      "e": #"entails" "G" "A",
      "f": #"entails" "G" "A"
      ----------------------------------------------- ("entailment_unique")
      "e" = "f" : #"entails" "G" "A"
  ] *)

  [:| "A": #"prop"
      -----------------------------------------------
      #"tauto": #"entails" (#"ext" #"emp" "A") "A"
  ];

  [:|
      -----------------------------------------------
      #"top": #"prop"
  ];
  [:| "G": #"env"
      -----------------------------------------------
      #"unit": #"entails" "G" #"top"
  ];
  [:| "G": #"env", "A": #"prop",
      "e": #"entails" "G" "A"
      -----------------------------------------------
      #"fluff" "e": #"entails" (#"ext" "G" #"top") "A"
  ];

  [:|
      -----------------------------------------------
      #"bot": #"prop"
  ];
  [:| "G": #"env", "A": #"prop"
      -----------------------------------------------
      #"contradiction": #"entails" (#"ext" "G" #"bot") "A"
  ];

  [:| "A": #"prop", "B": #"prop"
      -----------------------------------------------
      #"imp" "A" "B": #"prop"
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop",
      "e": #"entails" (#"ext" "G" "A") "B"
      -----------------------------------------------
      #"abs" "e": #"entails" "G" (#"imp" "A" "B")
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop",
      "x": #"entails" "G" "A"
      -----------------------------------------------
      #"app" "x": #"entails" (#"ext" "G" (#"imp" "A" "B")) "B"
  ];

  [:| "A": #"prop", "B": #"prop"
      -----------------------------------------------
      #"and" "A" "B": #"prop"
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop",
      "a": #"entails" "G" "A",
      "b": #"entails" "G" "B"
      -----------------------------------------------
      #"pair" "a" "b": #"entails" "G" (#"and" "A" "B")
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop"
      -----------------------------------------------
      #"fst": #"entails" (#"ext" "G" (#"and" "A" "B")) "A"
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop"
      -----------------------------------------------
      #"snd": #"entails" (#"ext" "G" (#"and" "A" "B")) "B"
  ];

  [:| "A": #"prop", "B": #"prop"
      -----------------------------------------------
      #"or" "A" "B": #"prop"
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop",
      "a": #"entails" "G" "A"
      -----------------------------------------------
      #"inl" "a": #"entails" "G" (#"or" "A" "B")
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop",
      "b": #"entails" "G" "B"
      -----------------------------------------------
      #"inr" "b": #"entails" "G" (#"or" "A" "B")
  ];
  [:| "G": #"env", "A": #"prop", "B": #"prop", "C": #"prop",
      "f": #"entails" (#"ext" "G" "A") "C",
      "g": #"entails" (#"ext" "G" "B") "C"
      -----------------------------------------------
      #"sum" "f" "g": #"entails" (#"ext" "G" (#"or" "A" "B")) "C"
  ]


  ]}.

Derive sequent_logic
       SuchThat (elab_lang_ext [] sequent_logic_def sequent_logic)
       As sequent_logic_wf.
Proof. auto_elab. Qed.