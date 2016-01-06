functor Compiler (R : REFINER) : COMPILER =
struct
  structure Refiner = R
  structure T = R.Tacticals

  open Abt ScriptOperatorData OperatorData
  infix $ \

  exception MalformedScript of string

  fun pop [] = raise Subscript
    | pop (x :: xs) = x

  fun getTerm hasTerm es =
    if hasTerm then
      case es of
          (_ \ m) :: _ => SOME m
         | _ => raise MalformedScript "Expected term argument"
    else
      NONE

  fun getVec m =
    case #1 (infer m) of
         VEC_LIT _ $ es => es
       | _ => raise MalformedScript "Expected vector argument"

  (* The idea is to translate scripts like [u... <- elim h; t2]
   * into ML tactics like [Elim h u... THEN t2] *)
  fun go stack m =
    case #1 (infer m) of
         S (THEN _) $ [_ \ t1, (us, _) \ t2] =>
           T.THEN (go (us :: stack) t1, go stack t2)
       | S (THENL _) $ [_ \ t1, (us, _) \ ts] =>
           T.THENL (go (us :: stack) t1, map (fn (_ \ m) => go stack m) (getVec ts))
       | S (ELIM ({target, hasTerm}, _)) $ es =>
           R.Elim target (pop stack) (getTerm hasTerm es)
       | S (HYP ({target}, _)) $ _ =>
           R.Hyp target
       | S (INTRO ({rule, hasTerm}, _)) $ es =>
           R.Intro rule (getTerm hasTerm es)
       | _ => raise MalformedScript "Expected tactical"

  fun compile m = go [] m

  (* TODO: treat source annotations properly *)
end