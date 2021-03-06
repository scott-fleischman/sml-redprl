(* type-specific modules *)
functor RefinerTypeRules (Sig : MINI_SIGNATURE) =
struct
  structure Kit = RefinerKit (Sig)
  structure ComRefinerKit = RefinerCompositionKit (Sig)
  open RedPrlAbt Kit ComRefinerKit

  type sign = Sig.sign
  type rule = (int -> Sym.t) -> Lcf.jdg Lcf.tactic
  type catjdg = abt CJ.jdg
  type opid = Sig.opid

  infixr @@
  infix 1 || #>
  infix 2 >> >: >:? >:+ $$ $# // \ @>
  infix orelse_

  structure WeakBool =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "WeakBool.EqType"
        val (I, H) >> CJ.EQ_TYPE (a, b) = jdg
        val Syn.WBOOL = Syn.out a
        val Syn.WBOOL = Syn.out b
      in
        T.empty #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected typehood sequent"]

    fun EqTT _ jdg =
      let
        val _ = RedPrlLog.trace "WeakBool.EqTT"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.WBOOL = Syn.out ty
        val Syn.TT = Syn.out m
        val Syn.TT = Syn.out n
      in
        T.empty #> (I, H, trivial)
      end

    fun EqFF _ jdg =
      let
        val _ = RedPrlLog.trace "WeakBool.EqFF"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.WBOOL = Syn.out ty
        val Syn.FF = Syn.out m
        val Syn.FF = Syn.out n
      in
        T.empty #> (I, H, trivial)
      end

    fun EqFCom alpha jdg =
      let
        val _ = RedPrlLog.trace "EqFCom"
        val (I, H) >> CJ.EQ ((lhs, rhs), ty) = jdg
        val Syn.WBOOL = Syn.out ty
        val Syn.FCOM args0 = Syn.out lhs
        val Syn.FCOM args1 = Syn.out rhs
      in
        ComKit.EqFComDelegator alpha (I, H) args0 args1 ty
      end

    fun Elim z _ jdg =
      let
        val _ = RedPrlLog.trace "WeakBool.Elim"
        val (I, H) >> CJ.TRUE cz = jdg
        val CJ.TRUE ty = lookupHyp H z
        val Syn.WBOOL = Syn.out ty

        val tt = Syn.into Syn.TT
        val ff = Syn.into Syn.FF

        val (goalT, holeT) = makeTrue (I, Hyps.modifyAfter z (CJ.map (substVar (tt, z))) H) (substVar (tt, z) cz)
        val (goalF, holeF) = makeTrue (I, Hyps.modifyAfter z (CJ.map (substVar (ff, z))) H) (substVar (ff, z) cz)

        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val if_ = Syn.into @@ Syn.IF ((z, cz), ztm, (holeT, holeF))
      in
        |>: goalT >: goalF #> (I, H, if_)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected bool elimination problem"]

    fun ElimEq alpha jdg =
      let
        val _ = RedPrlLog.trace "WeakBool.ElimEq"
        val (I, H) >> CJ.EQ ((if0, if1), c) = jdg
        val Syn.IF ((x, c0x), m0, (t0, f0)) = Syn.out if0
        val Syn.IF ((y, c1y), m1, (t1, f1)) = Syn.out if1

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val c0z = substVar (ztm, x) c0x
        val c1z = substVar (ztm, y) c1y
        val c0tt = substVar (Syn.into Syn.TT, x) c0x
        val c0ff = substVar (Syn.into Syn.FF, x) c0x
        val c0m0 = substVar (m0, x) c0x

        val goalTy = makeEqType (I, H @> (z, CJ.TRUE @@ Syn.into Syn.WBOOL)) (c0z, c1z)
        val goalM = makeEq (I, H) ((m0, m1), Syn.into Syn.WBOOL)
        val goalTy0 = makeEqTypeIfDifferent (I, H) (c0m0, c) (* c0m0 type *)
        val goalT = makeEq (I, H) ((t0, t1), c0tt)
        val goalF = makeEq (I, H) ((f0, f1), c0ff)
      in
        |>: goalM >: goalT >: goalF >:? goalTy0 >: goalTy #> (I, H, trivial)
      end
  end

  structure StrictBool =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "StrictBool.EqType"
        val (I, H) >> CJ.EQ_TYPE (a, b) = jdg
        val Syn.BOOL = Syn.out a
        val Syn.BOOL = Syn.out b
      in
        T.empty #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected typehood sequent"]

    fun EqTT _ jdg =
      let
        val _ = RedPrlLog.trace "StrictBool.EqTT"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.BOOL = Syn.out ty
        val Syn.TT = Syn.out m
        val Syn.TT = Syn.out n
      in
        T.empty #> (I, H, trivial)
      end

    fun EqFF _ jdg =
      let
        val _ = RedPrlLog.trace "StrictBool.EqFF"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.BOOL = Syn.out ty
        val Syn.FF = Syn.out m
        val Syn.FF = Syn.out n
      in
        T.empty #> (I, H, trivial)
      end

    fun Elim z _ jdg =
      let
        val _ = RedPrlLog.trace "StrictBool.Elim"
        val (I, H) >> CJ.TRUE cz = jdg
        val CJ.TRUE ty = lookupHyp H z
        val Syn.BOOL = Syn.out ty

        val tt = Syn.into Syn.TT
        val ff = Syn.into Syn.FF

        val (goalT, holeT) = makeTrue (I, Hyps.modifyAfter z (CJ.map (substVar (tt, z))) H) (substVar (tt, z) cz)
        val (goalF, holeF) = makeTrue (I, Hyps.modifyAfter z (CJ.map (substVar (ff, z))) H) (substVar (ff, z) cz)

        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val if_ = Syn.into @@ Syn.S_IF (ztm, (holeT, holeF))
      in
        |>: goalT >: goalF #> (I, H, if_)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected strict bool elimination problem"]

    (* this rule is outdated because the paper version has changed. *)
    fun ElimEq _ jdg =
      let
        val _ = RedPrlLog.trace "StrictBool.ElimEq"
        val (I, H) >> CJ.EQ ((if0, if1), c) = jdg
        val Syn.S_IF (m0, (t0, f0)) = Syn.out if0
        val Syn.S_IF (m1, (t1, f1)) = Syn.out if1

        val goalM = makeEq (I, H) ((m0, m1), Syn.into Syn.BOOL)
        val goalT = makeEq (I, H) ((t0, t1), c)
        val goalF = makeEq (I, H) ((f0, f1), c)
      in
        |>: goalM >: goalT >: goalF #> (I, H, trivial)
      end

    fun EqElim z _ jdg =
      let
        val _ = RedPrlLog.trace "StrictBool.EqElim"
        val (I, H) >> catjdg = jdg
        val CJ.EQ ((m0z, m1z), cz) = catjdg

        val CJ.TRUE ty = lookupHyp H z
        val Syn.BOOL = Syn.out ty

        val tt = Syn.into Syn.TT
        val ff = Syn.into Syn.FF

        val goalM0 = makeMem (I, H) (m0z, cz)
        val goalM1 = makeMem (I, H) (m1z, cz)
        val goalT = makeGoal' @@ (I, Hyps.modifyAfter z (CJ.map (substVar (tt, z))) H) >> CJ.map (substVar (tt, z)) catjdg
        val goalF = makeGoal' @@ (I, Hyps.modifyAfter z (CJ.map (substVar (ff, z))) H) >> CJ.map (substVar (ff, z)) catjdg
      in
        |>: goalT >: goalF >: goalM0 >: goalM1 #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected strict bool elimination problem"]
  end

  structure Int =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "Int.EqType"
        val (I, H) >> CJ.EQ_TYPE (a, b) = jdg
        val Syn.INT = Syn.out a
        val Syn.INT = Syn.out b
      in
        T.empty #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected typehood sequent"]

    fun Eq _ jdg =
      let
        val _ = RedPrlLog.trace "Int.Eq"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.INT = Syn.out ty
        val Syn.NUMBER i0 = Syn.out m
        val Syn.NUMBER i1 = Syn.out n
        val () = Assert.paramEq "Int.Eq" (i0, i1)
      in
        T.empty #> (I, H, trivial)
      end
  end

  structure Nat =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "Nat.EqType"
        val (I, H) >> CJ.EQ_TYPE (a, b) = jdg
        val Syn.NAT = Syn.out a
        val Syn.NAT = Syn.out b
      in
        T.empty #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected typehood sequent"]

    fun Eq _ jdg =
      let
        val _ = RedPrlLog.trace "Nat.Eq"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.NAT = Syn.out ty
        (* till we can generate "less-than" goals we can only handle numerals *)
        val Syn.NUMBER (P.APP (P.NUMERAL i0)) = Syn.out m
        val Syn.NUMBER (P.APP (P.NUMERAL i1)) = Syn.out n
        val true = i0 = i1
        val true = IntInf.>= (i0, 0)
      in
        T.empty #> (I, H, trivial)
      end
  end

  structure Void =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "Void.EqType"
        val (I, H) >> CJ.EQ_TYPE (a, b) = jdg
        val Syn.VOID = Syn.out a
        val Syn.VOID = Syn.out b
      in
        T.empty #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected typehood sequent"]

    fun Elim z _ jdg =
      let
        val _ = RedPrlLog.trace "Void.Elim"
        val (I, H) >> catjdg = jdg
        val CJ.TRUE ty = lookupHyp H z
        val Syn.VOID = Syn.out ty

        val evidence =
          case catjdg of
             CJ.TRUE _ => Syn.into Syn.TT (* should be some fancy symbol *)
           | CJ.EQ _ => trivial
           | CJ.EQ_TYPE _ => trivial
           | _ => raise Fail "Void.Elim cannot be called with this kind of goal"
      in
        T.empty #> (I, H, evidence)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected Void elimination problem"]
  end

  structure S1 =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "S1.EqType"
        val (I, H) >> CJ.EQ_TYPE (a, b) = jdg
        val Syn.S1 = Syn.out a
        val Syn.S1 = Syn.out b
      in
        T.empty #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected typehood sequent"]

    fun EqBase _ jdg =
      let
        val _ = RedPrlLog.trace "S1.EqBase"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.S1 = Syn.out ty
        val Syn.BASE = Syn.out m
        val Syn.BASE = Syn.out n
      in
        T.empty #> (I, H, trivial)
      end

    fun EqLoop _ jdg =
      let
        val _ = RedPrlLog.trace "S1.EqLoop"
        val (I, H) >> CJ.EQ ((m, n), ty) = jdg
        val Syn.S1 = Syn.out ty
        val Syn.LOOP r1 = Syn.out m
        val Syn.LOOP r2 = Syn.out n
        val () = Assert.paramEq "S1.EqLoop" (r1, r2)
      in
        T.empty #> (I, H, trivial)
      end

    fun EqFCom alpha jdg =
      let
        val _ = RedPrlLog.trace "EqFCom"
        val (I, H) >> CJ.EQ ((lhs, rhs), ty) = jdg
        val Syn.S1 = Syn.out ty
        val Syn.FCOM args0 = Syn.out lhs
        val Syn.FCOM args1 = Syn.out rhs
      in
        ComKit.EqFComDelegator alpha (I, H) args0 args1 ty
      end

    fun Elim z alpha jdg =
      let
        val _ = RedPrlLog.trace "S1.Elim"
        val (I, H) >> CJ.TRUE cz = jdg
        val CJ.TRUE ty = lookupHyp H z
        val Syn.S1 = Syn.out ty

        val u = alpha 0
        val base = Syn.into Syn.BASE
        val loop = Syn.into o Syn.LOOP @@ P.ret u
        val Hbase = Hyps.modifyAfter z (CJ.map (substVar (base, z))) H
        val cbase = substVar (base, z) cz

        val (goalB, holeB) = makeTrue (I, Hbase) cbase
        val (goalL, holeL) = makeTrue (I @ [(u, P.DIM)], Hyps.modifyAfter z (CJ.map (substVar (loop, z))) H) (substVar (loop, z) cz)

        val l0 = substSymbol (P.APP P.DIM0, u) holeL
        val l1 = substSymbol (P.APP P.DIM1, u) holeL

        val goalCoh0 = makeEqIfDifferent (I, Hbase) ((l0, holeB), cbase) (* holeB well-typed *)
        val goalCoh1 = makeEqIfAllDifferent (I, Hbase) ((l1, holeB), cbase) [l0]

        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val elim = Syn.into @@ Syn.S1_ELIM ((z, cz), ztm, (holeB, (u, holeL)))
      in
        |>: goalB >: goalL >:? goalCoh0 >:? goalCoh1 #> (I, H, elim)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected circle elimination problem"]

    fun ElimEq alpha jdg =
      let
        val _ = RedPrlLog.trace "S1.ElimEq"
        val (I, H) >> CJ.EQ ((elim0, elim1), c) = jdg
        val Syn.S1_ELIM ((x, c0x), m0, (b0, (u, l0u))) = Syn.out elim0
        val Syn.S1_ELIM ((y, c1y), m1, (b1, (v, l1v))) = Syn.out elim1

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val c0z = substVar (ztm, x) c0x
        val c1z = substVar (ztm, y) c1y

        val c0m0 = substVar (m0, x) c0x

        val l1u = substSymbol (P.ret u, v) l1v

        val l00 = substSymbol (P.APP P.DIM0, u) l0u
        val l01 = substSymbol (P.APP P.DIM1, u) l0u

        val cbase = substVar (Syn.into Syn.BASE, x) c0x
        val cloop = substVar (Syn.into @@ Syn.LOOP (P.ret u), x) c0x

        val S1 = Syn.into Syn.S1

        val goalCz = makeEqType (I, H @> (z, CJ.TRUE S1)) (c0z, c1z)
        val goalM = makeEq (I, H) ((m0, m1), S1)
        val goalCM = makeEqTypeIfDifferent (I, H) (c0m0, c) (* c0m0 type *)
        val goalB = makeEq (I, H) ((b0, b1), cbase)
        val goalL = makeEq (I @ [(u,P.DIM)], H) ((l0u, l1u), cloop)
        val goalL00 = makeEqIfAllDifferent (I, H) ((l00, b0), cbase) [b1]
        val goalL01 = makeEqIfAllDifferent (I, H) ((l01, b0), cbase) [l00, b1]

        val psi = |>: goalCz >: goalM >: goalB >: goalL >:? goalCM >:? goalL00 >:? goalL01
      in
        psi #> (I, H, trivial)
      end
  end

  structure DFun =
  struct
    fun EqType alpha jdg =
      let
        val _ = RedPrlLog.trace "DFun.EqType"
        val (I, H) >> CJ.EQ_TYPE (dfun0, dfun1) = jdg
        val Syn.DFUN (a0, x, b0x) = Syn.out dfun0
        val Syn.DFUN (a1, y, b1y) = Syn.out dfun1

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val b0z = substVar (ztm, x) b0x
        val b1z = substVar (ztm, y) b1y

        val goalA = makeEqType (I, H) (a0, a1)
        val goalB = makeEqType (I, H @> (z, CJ.TRUE a0)) (b0z, b1z)
      in
        |>: goalA >: goalB #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected dfun typehood sequent"]

    fun Eq alpha jdg =
      let
        val _ = RedPrlLog.trace "DFun.Eq"
        val (I, H) >> CJ.EQ ((lam0, lam1), dfun) = jdg
        val Syn.LAM (x, m0x) = Syn.out lam0
        val Syn.LAM (y, m1y) = Syn.out lam1
        val Syn.DFUN (a, z, bz) = Syn.out dfun

        val w = alpha 0
        val wtm = Syn.into @@ Syn.VAR (w, O.EXP)

        val m0w = substVar (wtm, x) m0x
        val m1w = substVar (wtm, y) m1y
        val bw = substVar (wtm, z) bz

        val goalM = makeEq (I, H @> (w, CJ.TRUE a)) ((m0w, m1w), bw)
        val goalA = makeType (I, H) a
      in
        |>: goalM >: goalA #> (I, H, trivial)
      end

    fun True alpha jdg =
      let
        val _ = RedPrlLog.trace "DFun.True"
        val (I, H) >> CJ.TRUE dfun = jdg
        val Syn.DFUN (a, x, bx) = Syn.out dfun

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val bz = substVar (ztm, x) bx

        val goalA = makeType (I, H) a
        val (goalLam, hole) = makeTrue (I, H @> (z, CJ.TRUE a)) bz

        val lam = Syn.into @@ Syn.LAM (z, substVar (ztm, z) hole)
      in
        |>: goalLam >: goalA #> (I, H, lam)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected dfun truth sequent"]

    fun Eta _ jdg =
      let
        val _ = RedPrlLog.trace "DFun.Eta"
        val (I, H) >> CJ.EQ ((m, n), dfun) = jdg
        val Syn.DFUN (_, x, _) = Syn.out dfun

        val xtm = Syn.into @@ Syn.VAR (x, O.EXP)
        val m' = Syn.into @@ Syn.LAM (x, Syn.into @@ Syn.AP (m, xtm))
        val goal1 = makeMem (I, H) (m, dfun)
        val goal2 = makeEq (I, H) ((m', n), dfun)
      in
        |>: goal1 >: goal2 #> (I, H, trivial)
      end

    fun Elim z alpha jdg =
      let
        val _ = RedPrlLog.trace "DFun.Elim"
        val (I, H) >> CJ.TRUE cz = jdg
        val CJ.TRUE dfun = lookupHyp H z
        val Syn.DFUN (a, x, bx) = Syn.out dfun
        val (goalA, holeA) = makeTrue (I, H) a

        val u = alpha 0
        val v = alpha 1

        val b' = substVar (holeA, x) bx

        val utm = Syn.into @@ Syn.VAR (u, O.EXP)
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val aptm = Syn.into @@ Syn.AP (ztm, holeA)
        (* note: a and bx come from the telescope so they are types *)
        val H' = Hyps.empty @> (u, CJ.TRUE b') @> (v, CJ.EQ ((utm, aptm), b'))
        val H'' = Hyps.interposeAfter H z H'

        val (goal2, hole2) = makeTrue (I, H'') cz

        val aptm = Syn.into @@ Syn.AP (ztm, holeA)
        val rho = Var.Ctx.insert (Var.Ctx.insert Var.Ctx.empty u aptm) v trivial
        val hole2' = substVarenv rho hole2
      in
        |>: goalA >: goal2 #> (I, H, hole2')
      end

    fun ApEq _ jdg =
      let
        val _ = RedPrlLog.trace "DFun.ApEq"
        val (I, H) >> CJ.EQ ((ap0, ap1), _) = jdg
        val Syn.AP (m0, n0) = Syn.out ap0
        val Syn.AP (m1, n1) = Syn.out ap1

        val (goalDFun0, holeDFun0) = makeSynth (I, H) m0
        val (goalDFun1, holeDFun1) = makeSynth (I, H) m1
        val goalDFunEq = makeEqTypeIfDifferent (I, H) (holeDFun0, holeDFun1)
        val (goalDom, holeDom) = makeMatch (O.MONO O.DFUN, 0, holeDFun0, [], [])
        val goalN = makeEq (I, H) ((n0, n1), holeDom)
      in
        |>: goalDFun0 >: goalDFun1 >:? goalDFunEq >: goalDom >: goalN
        #> (I, H, trivial)
      end
  end

  structure DProd =
  struct
    fun EqType alpha jdg =
      let
        val _ = RedPrlLog.trace "DProd.EqType"
        val (I, H) >> CJ.EQ_TYPE (dprod0, dprod1) = jdg
        val Syn.DPROD (a0, x, b0x) = Syn.out dprod0
        val Syn.DPROD (a1, y, b1y) = Syn.out dprod1

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val b0z = substVar (ztm, x) b0x
        val b1z = substVar (ztm, y) b1y

        val goalA = makeEqType (I, H) (a0, a1)
        val goalB = makeEqType (I, H @> (z, CJ.TRUE a0)) (b0z, b1z)
      in
        |>: goalA >: goalB #> (I, H, trivial)
      end
      handle Bind =>
        raise E.error [Fpp.text "Expected dprod typehood sequent"]

    fun Eq alpha jdg =
      let
        val _ = RedPrlLog.trace "DProd.Eq"
        val (I, H) >> CJ.EQ ((pair0, pair1), dprod) = jdg
        val Syn.PAIR (m0, n0) = Syn.out pair0
        val Syn.PAIR (m1, n1) = Syn.out pair1
        val Syn.DPROD (a, x, bx) = Syn.out dprod

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val bz = substVar (ztm, x) bx

        val goal1 = makeEq (I, H) ((m0, m1), a)
        val goal2 = makeEq (I, H) ((n0, n1), substVar (m0, x) bx)
        val goalFam = makeType (I, H @> (z, CJ.TRUE a)) bz
      in
        |>: goal1 >: goal2 >: goalFam #> (I, H, trivial)
      end

    fun Eta _ jdg =
      let
        val _ = RedPrlLog.trace "DProd.Eta"
        val (I, H) >> CJ.EQ ((m, n), dprod) = jdg
        val Syn.DPROD _ = Syn.out dprod

        val m' = Syn.into @@ Syn.PAIR (Syn.into @@ Syn.FST m, Syn.into @@ Syn.SND m)
        val goal1 = makeMem (I, H) (m, dprod)
        val goal2 = makeEqIfDifferent (I, H) ((m', n), dprod) (* m' well-typed *)
      in
        |>: goal1 >:? goal2 #> (I, H, trivial)
      end

    fun FstEq _ jdg =
      let
        val _ = RedPrlLog.trace "DProd.FstEq"
        val (I, H) >> CJ.EQ ((fst0, fst1), ty) = jdg
        val Syn.FST m0 = Syn.out fst0
        val Syn.FST m1 = Syn.out fst1

        val (goalTy, holeTy) = makeSynth (I, H) m0
        val (goalTyA, holeTyA) = makeMatch (O.MONO O.DPROD, 0, holeTy, [], [])
        val goalEq = makeEqIfDifferent (I, H) ((m0, m1), holeTy) (* m0 well-typed *)
        val goalEqTy = makeEqTypeIfDifferent (I, H) (holeTyA, ty) (* holeTyA type *)
      in
        |>: goalTy >: goalTyA >:? goalEq >:? goalEqTy
        #> (I, H, trivial)
      end

    fun SndEq _ jdg =
      let
        val _ = RedPrlLog.trace "DProd.SndEq"
        val (I, H) >> CJ.EQ ((snd0, snd1), ty) = jdg
        val Syn.SND m0 = Syn.out snd0
        val Syn.SND m1 = Syn.out snd1

        val (goalTy, holeTy) = makeSynth (I, H) m0
        val (goalTyB, holeTyB) = makeMatch (O.MONO O.DPROD, 1, holeTy, [], [Syn.into @@ Syn.FST m0])
        val goalEq = makeEqIfDifferent (I, H) ((m0, m1), holeTy) (* m0 well-typed *)
        val goalEqTy = makeEqTypeIfDifferent (I, H) (holeTyB, ty) (* holeTyB type *)
      in
        |>: goalTy >: goalTyB >:? goalEq >:? goalEqTy
        #> (I, H, trivial)
      end

    fun True alpha jdg =
      let
        val _ = RedPrlLog.trace "DProd.True"
        val (I, H) >> CJ.TRUE dprod = jdg
        val Syn.DPROD (a, x, bx) = Syn.out dprod

        val z = alpha 0
        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val bz = substVar (ztm, x) bx

        val (goal1, hole1) = makeTrue (I, H) a
        val (goal2, hole2) = makeTrue (I, H) (substVar (hole1, x) bx)
        val goalFam = makeType (I, H @> (z, CJ.TRUE a)) bz
        val pair = Syn.into @@ Syn.PAIR (hole1, hole2)
      in
        |>: goal1 >: goal2 >: goalFam #> (I, H, pair)
      end

    fun Elim z alpha jdg =
      let
        val _ = RedPrlLog.trace "DProd.Elim"
        val (I, H) >> CJ.TRUE cz = jdg
        val CJ.TRUE dprod = lookupHyp H z
        val Syn.DPROD (a, x, bx) = Syn.out dprod

        val z1 = alpha 0
        val z2 = alpha 1

        val z1tm = Syn.into @@ Syn.VAR (z1, O.EXP)
        val z2tm = Syn.into @@ Syn.VAR (z2, O.EXP)

        val bz1 = substVar (z1tm, x) bx
        val pair = Syn.into @@ Syn.PAIR (z1tm, z2tm)

        val H' = Hyps.empty @> (z1, CJ.TRUE a) @> (z2, CJ.TRUE bz1)
        val H'' = Hyps.interposeAfter H z H'

        val (goal, hole) =
          makeTrue
            (I, Hyps.modifyAfter z (CJ.map (substVar (pair, z))) H'')
            (substVar (pair, z) cz)

        val ztm = Syn.into @@ Syn.VAR (z, O.EXP)
        val fstz = Syn.into @@ Syn.FST ztm
        val sndz = Syn.into @@ Syn.SND ztm
        val rho = Var.Ctx.insert (Var.Ctx.insert Var.Ctx.empty z1 fstz) z2 sndz
        val hole' = substVarenv rho hole
      in
        |>: goal #> (I, H, hole')
      end
  end

  structure Path =
  struct
    fun EqType _ jdg =
      let
        val _ = RedPrlLog.trace "Path.EqType"
        val (I, H) >> CJ.EQ_TYPE (ty0, ty1) = jdg
        val Syn.PATH_TY ((u, a0u), m0, n0) = Syn.out ty0
        val Syn.PATH_TY ((v, a1v), m1, n1) = Syn.out ty1

        val a1u = substSymbol (P.ret u, v) a1v

        val a00 = substSymbol (P.APP P.DIM0, u) a0u
        val a01 = substSymbol (P.APP P.DIM1, u) a0u

        val tyGoal = makeEqType (I, H) (a0u, a1u)
        val goal0 = makeEq (I, H) ((m0, m1), a00)
        val goal1 = makeEq (I, H) ((n0, n1), a01)
      in
        |>: tyGoal >: goal0 >: goal1 #> (I, H, trivial)
      end

    fun True alpha jdg =
      let
        val _ = RedPrlLog.trace "Path.True"
        val (I, H) >> CJ.TRUE ty = jdg
        val Syn.PATH_TY ((u, a), p0, p1) = Syn.out ty
        val a0 = substSymbol (P.APP P.DIM0, u) a
        val a1 = substSymbol (P.APP P.DIM1, u) a

        val v = alpha 0

        val (mainGoal, mhole) = makeTrue (I @ [(v, P.DIM)], H) (substSymbol (P.ret v, u) a)

        (* note: m0 and m1 are already well-typed *)
        val m0 = substSymbol (P.APP P.DIM0, v) mhole
        val m1 = substSymbol (P.APP P.DIM1, v) mhole
        val cohGoal0 = makeEqIfDifferent (I, H) ((m0, p0), a0)
        val cohGoal1 = makeEqIfDifferent (I, H) ((m1, p1), a1)

        val abstr = Syn.into @@ Syn.PATH_ABS (v, mhole)
      in
        |>: mainGoal >:? cohGoal0 >:? cohGoal1
        #> (I, H, abstr)
      end

    fun Eq alpha jdg =
      let
        val _ = RedPrlLog.trace "Path.Eq"
        val (I, H) >> CJ.EQ ((abs0, abs1), ty) = jdg
        val Syn.PATH_TY ((u, au), p0, p1) = Syn.out ty
        val Syn.PATH_ABS (v, m0v) = Syn.out abs0
        val Syn.PATH_ABS (w, m1w) = Syn.out abs1

        val z = alpha 0
        val az = substSymbol (P.ret z, u) au
        val m0z = substSymbol (P.ret z, v) m0v
        val m1z = substSymbol (P.ret z, w) m1w

        val a0 = substSymbol (P.APP P.DIM0, u) au
        val a1 = substSymbol (P.APP P.DIM1, u) au
        val m00 = substSymbol (P.APP P.DIM0, v) m0v
        val m01 = substSymbol (P.APP P.DIM1, v) m0v

        val goalM = makeEq (I @ [(z, P.DIM)], H) ((m0z, m1z), az)
        (* note: m00 and m01 are already well-typed *)
        val goalM00 = makeEqIfDifferent (I, H) ((m00, p0), a0)
        val goalM01 = makeEqIfDifferent (I, H) ((m01, p1), a1)
      in
        |>: goalM >:? goalM00 >:? goalM01 #> (I, H, trivial)
      end

    fun ApEq _ jdg =
      let
        val _ = RedPrlLog.trace "Path.ApEq"
        val (I, H) >> CJ.EQ ((ap0, ap1), ty) = jdg
        val Syn.PATH_AP (m0, r0) = Syn.out ap0
        val Syn.PATH_AP (m1, r1) = Syn.out ap1
        val () = Assert.paramEq "Path.ApEq" (r0, r1)
        val (goalSynth, holeSynth) = makeSynth (I, H) m0
        val goalMem = makeEqIfDifferent (I, H) ((m0, m1), holeSynth) (* m0 well-typed *)
        val (goalLine, holeLine) = makeMatch (O.MONO O.PATH_TY, 0, holeSynth, [r0], [])
        val goalTy = makeEqTypeIfDifferent (I, H) (holeLine, ty) (* holeLine type *)
      in
        |>: goalSynth >:? goalMem >: goalLine >:? goalTy #> (I, H, trivial)
      end

    fun ApConstCompute _ jdg =
      let
        val _ = RedPrlLog.trace "Path.ApConstCompute"
        val (I, H) >> CJ.EQ ((ap, p), a) = jdg
        val Syn.PATH_AP (m, P.APP r) = Syn.out ap
        val (goalSynth, holeSynth) = makeSynth (I, H) m

        val dimAddr = case r of P.DIM0 => 1 | P.DIM1 => 2
        val (goalLine, holeLine) = makeMatch (O.MONO O.PATH_TY, 0, holeSynth, [P.APP r], [])
        val (goalEndpoint, holeEndpoint) = makeMatch (O.MONO O.PATH_TY, dimAddr, holeSynth, [], [])
        val goalTy = makeEqType (I, H) (a, holeLine)
        val goalEq = makeEq (I, H) ((holeEndpoint, p), a)
      in
        |>: goalSynth >: goalLine >: goalEndpoint >: goalTy >: goalEq
        #> (I, H, trivial)
      end

    fun Eta _ jdg =
      let
        val _ = RedPrlLog.trace "Path.Eta"
        val (I, H) >> CJ.EQ ((m, n), pathTy) = jdg
        val Syn.PATH_TY ((u, _), _, _) = Syn.out pathTy

        val m' = Syn.into @@ Syn.PATH_ABS (u, Syn.into @@ Syn.PATH_AP (m, P.ret u))
        val goal1 = makeMem (I, H) (m, pathTy)
        val goal2 = makeEqIfDifferent (I, H) ((m', n), pathTy) (* m' will-typed *)
      in
        |>: goal1 >:? goal2 #> (I, H, trivial)
      end

  end
end
