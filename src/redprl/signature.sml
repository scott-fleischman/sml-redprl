structure Signature :> SIGNATURE =
struct
  structure Tm = RedPrlAbt and Ar = RedPrlArity
  structure P = struct open RedPrlSortData RedPrlParamData end
  structure E = ElabMonadUtil (ElabMonad)
  structure ElabNotation = MonadNotation (E)
  open ElabNotation infix >>= *> <*

  fun @@ (f, x) = f x
  infixr @@

  open MiniSig
  structure O = RedPrlOpData and E = ElabMonadUtil (ElabMonad)

  fun intersperse s xs =
    case xs of
       [] => []
     | [x] => [x]
     | x::xs => Fpp.seq [x, s] :: intersperse s xs

  fun prettyParams ps =
    Fpp.Atomic.braces @@ Fpp.grouped @@ Fpp.hvsep @@
      intersperse Fpp.Atomic.comma @@
        List.map (fn (u, sigma) => Fpp.hsep [Fpp.text (Sym.toString u), Fpp.Atomic.colon, Fpp.text (Ar.Vl.PS.toString sigma)]) ps

  fun prettyArgs args =
    Fpp.Atomic.parens @@ Fpp.grouped @@ Fpp.hvsep @@
      intersperse (Fpp.text ";") @@
        List.map (fn (x, vl) => Fpp.hsep [Fpp.text (Metavar.toString x), Fpp.Atomic.colon, TermPrinter.ppValence vl]) args

  fun prettyEntry (_ : sign) (opid : symbol, entry as {spec, state,...} : entry) : Fpp.doc =
    let
      val arguments = entryArguments entry
    in
      Fpp.hsep
        [Fpp.text "Def",
          Fpp.seq [Fpp.text @@ Sym.toString opid, prettyArgs arguments],
          Fpp.Atomic.colon,
          Fpp.grouped @@ Fpp.Atomic.squares @@ Fpp.seq
            [Fpp.nest 2 @@ Fpp.seq [Fpp.newline, RedPrlSequent.pretty TermPrinter.ppTerm spec],
            Fpp.newline],
          Fpp.Atomic.equals,
          Fpp.grouped @@ Fpp.Atomic.squares @@ Fpp.seq
            [Fpp.nest 2 @@ Fpp.seq [Fpp.newline, TermPrinter.ppTerm @@ extract state],
            Fpp.newline],
          Fpp.char #"."]
    end


  val empty =
    {sourceSign = Telescope.empty,
     elabSign = ETelescope.empty,
     nameEnv = NameEnv.empty}

  local
    val getEntry =
      fn EDEF entry => SOME entry
       | _ => NONE

    fun arityOfDecl (entry : entry) : Tm.psort list * Tm.O.Ar.t =
      let
        val params = entryParams entry
        val arguments = entryArguments entry
        val sort = entrySort entry
      in
        (List.map #2 params, (List.map #2 arguments, sort))
      end

    structure OptionMonad = MonadNotation (OptionMonad)

    fun arityOfOpid (sign : sign) opid =
      let
        open OptionMonad infix >>=
      in
        NameEnv.find (#nameEnv sign) opid
          >>= ETelescope.find (#elabSign sign)
          >>= E.run
          >>= Option.map arityOfDecl o getEntry
      end

    structure Err = RedPrlError

    fun error pos msg = raise Err.annotate pos (Err.error msg)

    (* During parsing, the arity of a custom-operator application is not known; but we can
     * derive it from the signature "so far". Prior to adding a declaration to the signature,
     * we process its terms to fill this in. *)
    local
      open RedPrlAst
      infix $ $$ $# $$# \


      fun inheritAnnotation t1 t2 =
        case getAnnotation t2 of
          NONE => setAnnotation (getAnnotation t1) t2
        | _ => t2


      fun processOp pos sign =
        fn O.POLY (O.CUST (opid, ps, NONE)) =>
           (case arityOfOpid sign opid of
               SOME (psorts, ar) =>
                 let
                   val ps' = ListPair.mapEq (fn ((p, _), tau) => (O.P.check tau p; (p, SOME tau))) (ps, psorts)
                 in
                   O.POLY (O.CUST (opid, ps', SOME ar))
                 end
             | NONE => error pos [Fpp.text "Encountered undefined custom operator:", Fpp.text opid])
         | O.POLY (O.RULE_LEMMA (opid, ps)) =>
           (case arityOfOpid sign opid of
               SOME (psorts, _) =>
                 let
                   val ps' = ListPair.mapEq (fn ((p, _), tau) => (O.P.check tau p; (p, SOME tau))) (ps, psorts)
                 in
                   O.POLY (O.RULE_LEMMA (opid, ps'))
                 end
             | NONE => error pos [Fpp.text "Encountered undefined custom operator:", Fpp.text opid])
         | O.POLY (O.RULE_CUT_LEMMA (opid, ps)) =>
           (case arityOfOpid sign opid of
               SOME (psorts, _) =>
                 let
                   val ps' = ListPair.mapEq (fn ((p, _), tau) => (O.P.check tau p; (p, SOME tau))) (ps, psorts)
                 in
                   O.POLY (O.RULE_CUT_LEMMA (opid, ps'))
                 end
             | NONE => error pos [Fpp.text "Encountered undefined custom operator:", Fpp.text opid])
         | th => th

      fun processTerm' sign m =
        case out m of
           `x => ``x
         | th $ es => processOp (getAnnotation m) sign th $$ List.map (fn bs \ m => bs \ processTerm sign m) es
         | x $# (ps, ms) => x $$# (ps, List.map (processTerm sign) ms)

      and processTerm sign m =
        inheritAnnotation m (processTerm' sign m)

      fun processSrcCatjdg sign =
        RedPrlCategoricalJudgment.map (processTerm sign)

      fun processSrcSeq sign (hyps, concl) =
        (List.map (fn (x, hyp) => (x, processSrcCatjdg sign hyp)) hyps, processSrcCatjdg sign concl)

      fun processSrcGenJdg sign (bs, seq) =
        (bs, processSrcSeq sign seq)

      fun processSrcRuleSpec sign (premises, goal) =
        (List.map (processSrcGenJdg sign) premises, processSrcSeq sign goal)

    in
      fun processDecl sign =
        fn DEF {arguments, params, sort, definiens} => DEF {arguments = arguments, params = params, sort = sort, definiens = processTerm sign definiens}
         | THM {arguments, params, goal, script} => THM {arguments = arguments, params = params, goal = processSrcSeq sign goal, script = processTerm sign script}
         | TAC {arguments, params, script} => TAC {arguments = arguments, params = params, script = processTerm sign script}
    end

    structure MetaCtx = Tm.Metavar.Ctx

    structure LcfModel = LcfModel (MiniSig)
    structure LcfSemantics = NominalLcfSemantics (LcfModel)

    fun elabDeclArguments args =
      List.foldr
        (fn ((x, vl), (args', mctx)) =>
          let
            val x' = Metavar.named x
          in
            ((x', vl) :: args', MetaCtx.insert mctx x' vl)
          end)
        ([], MetaCtx.empty)
        args

    fun elabDeclParams (sign : sign) (params : string params) : symbol params * Tm.symctx * symbol NameEnv.dict =
      let
        val (ctx0, env0) =
          ETelescope.foldl
            (fn (x, _, (ctx, env)) => (Tm.Sym.Ctx.insert ctx x P.OPID, NameEnv.insert env (Tm.Sym.toString x) x))
            (Tm.Sym.Ctx.empty, NameEnv.empty)
            (#elabSign sign)
      in
        List.foldr
          (fn ((x, tau), (ps, ctx, env)) =>
            let
              val x' = Tm.Sym.named x
            in
              ((x', tau) :: ps, Tm.Sym.Ctx.insert ctx x' tau, NameEnv.insert env x x')
            end)
          ([], ctx0, env0)
          params
      end

    fun scopeCheck (metactx, symctx, varctx) term : Tm.abt E.t =
      let
        val termPos = Tm.getAnnotation term
        val symOccurrences = Susp.delay (fn _ => Tm.symOccurrences term)
        val varOccurrences = Susp.delay (fn _ => Tm.varOccurrences term)

        val checkSyms =
          Tm.Sym.Ctx.foldl
            (fn (u, tau, r) =>
              let
                val tau' = Tm.Sym.Ctx.find symctx u
                val ustr = Tm.Sym.toString u
                val pos =
                  case Tm.Sym.Ctx.find (Susp.force symOccurrences) u of
                      SOME (pos :: _) => SOME pos
                    | _ => (print ("couldn't find position for var " ^ ustr); termPos)
              in
                E.when (tau' = NONE, E.fail (pos, Fpp.text ("Unbound symbol: " ^ ustr)))
                  *> E.when (Option.isSome tau' andalso not (tau' = SOME tau), E.fail (pos, Fpp.text ("Symbol sort mismatch: " ^ ustr)))
                  *> r
              end)
            (E.ret ())
            (Tm.symctx term)

        val checkVars =
          Tm.Var.Ctx.foldl
            (fn (x, tau, r) =>
               let
                 val tau' = Tm.Var.Ctx.find varctx x
                 val xstr = Tm.Sym.toString x
                 val pos =
                   case Tm.Var.Ctx.find (Susp.force varOccurrences) x of
                      SOME (pos :: _) => SOME pos
                    | _ => termPos
               in
                 E.when (tau' = NONE, E.fail (pos, Fpp.text ("Unbound variable: " ^ xstr)))
                  *> E.when (Option.isSome tau' andalso not (tau' = SOME tau), E.fail (pos, Fpp.text ("Variable sort mismatch: " ^ xstr)))
                  *> r
               end)
            (E.ret ())
            (Tm.varctx term)

        val checkMetas =
          Tm.Metavar.Ctx.foldl
            (fn (x, _, r) =>
               r <* E.unless (Option.isSome (Tm.Metavar.Ctx.find metactx x), E.fail (termPos, Fpp.text ("Unbound metavar: " ^ Tm.Metavar.toString x))))
            (E.ret ())
            (Tm.metactx term)
      in
        checkVars *> checkSyms *> checkMetas *> E.ret term
      end

    fun metactxToNameEnv metactx =
      Tm.Metavar.Ctx.foldl
        (fn (x, _, r) => AstToAbt.NameEnv.insert r (Tm.Metavar.toString x) x)
        AstToAbt.NameEnv.empty
        metactx

    structure CJ = RedPrlCategoricalJudgment and Sort = RedPrlOpData and Hyps = RedPrlSequent.Hyps

    fun elabAst (metactx, env) ast : abt =
      let
        val abt = AstToAbt.convertOpen (metactx, metactxToNameEnv metactx) (env, env) (ast, Sort.EXP)
      in
        abt
      end

    fun elabSrcCatjdg (metactx, symctx, varctx, env) : src_catjdg -> abt CJ.jdg =
      CJ.map (elabAst (metactx, env))
      (* TODO check scoping *)

    fun addHypName (env, symctx, varctx) (srcname, tau) =
      let
        val x = NameEnv.lookup env srcname handle _ => Sym.named srcname
        val env' = NameEnv.insert env srcname x
        val symctx' = Sym.Ctx.insert symctx x (RedPrlSortData.HYP tau)
        val varctx' = Sym.Ctx.insert varctx x tau
      in
        (env', symctx', varctx', x)
      end

    fun addSymName (env, symctx) (srcname, psort) =
      let
        val u = Sym.named srcname
        val env' = NameEnv.insert env srcname u
        val symctx' = Sym.Ctx.insert symctx u psort
      in
        (env', symctx')
      end

    fun elabSrcSeqHyp (metactx, symctx, varctx, env) (srcname, srcjdg) : Tm.symctx * Tm.varctx * symbol NameEnv.dict * symbol * abt CJ.jdg =
      let
        val catjdg = elabSrcCatjdg (metactx, symctx, varctx, env) srcjdg
        val tau = CJ.synthesis catjdg
        val (env', symctx', varctx', x) = addHypName (env, symctx, varctx) (srcname, tau)
      in
        (symctx', varctx', env', x, catjdg)
      end

    fun elabSrcSeqHyps (metactx, symctx, varctx, env) : src_seqhyp list -> symbol NameEnv.dict * abt CJ.jdg Hyps.telescope =
      let
        fun go env _ _ H [] = (env, H)
          | go env syms vars H (hyp :: hyps) =
              let
                val (syms', vars', env', x, jdg) = elabSrcSeqHyp (metactx, syms, vars, env) hyp
              in
                go env' syms' vars' (Hyps.snoc H x jdg) hyps
              end
      in
        go env symctx varctx Hyps.empty
      end

    fun elabSrcSequent (metactx, symctx, varctx, env) (seq : src_sequent) : symbol NameEnv.dict * jdg =
      let
        val (hyps, concl) = seq
        val (env', hyps') = elabSrcSeqHyps (metactx, symctx, varctx, env) hyps
        val concl' = elabSrcCatjdg (metactx, symctx, varctx, env') concl
      in
        (env', RedPrlSequent.>> (([], hyps'), concl')) (* todo: I := ? *)
      end

    fun convertToAbt (metactx, symctx, env) ast sort =
      E.wrap (RedPrlAst.getAnnotation ast, fn () =>
        AstToAbt.convertOpen (metactx, metactxToNameEnv metactx) (env, NameEnv.empty) (ast, sort)
        handle AstToAbt.BadConversion (msg, pos) => error pos [Fpp.text msg])
      >>= scopeCheck (metactx, symctx, Var.Ctx.empty)

    fun valenceToSequent ((sigmas, taus), tau) =
      let
        open RedPrlSequent RedPrlCategoricalJudgment infix >>
        val I = List.map (fn sigma => (Sym.new (), sigma)) sigmas
        val H = List.foldr (fn (tau, H) => Hyps.cons (Var.new ()) (TERM tau) H) Hyps.empty taus
      in
        (I, H) >> TERM tau
      end

    fun argumentsToSubgoals arguments = 
      List.foldr
        (fn ((x,vl), r) => Lcf.Tl.cons x (valenceToSequent vl) r)
        Lcf.Tl.empty
        arguments

    fun elabDef (sign : sign) opid {arguments, params, sort, definiens} =
      let
        val (arguments', metactx) = elabDeclArguments arguments
        val (params', symctx, env) = elabDeclParams sign params
      in
        convertToAbt (metactx, symctx, env) definiens sort >>= (fn definiens' =>
          let
            val tau = sort
            open Tm infix \
            val subgoals = argumentsToSubgoals arguments'
            val state = Lcf.|> (subgoals, checkb (([],[]) \ definiens', (([],[]), tau)))
            val spec = RedPrlSequent.>> ((params', Hyps.empty), CJ.TERM tau)
          in
            E.ret (EDEF {sourceOpid = opid, spec = spec, state = state})
          end)
      end

    local
      open RedPrlSequent Tm RedPrlOpData infix >> \ $$

      fun names i = Sym.named ("@" ^ Int.toString i)

      fun elabRefine sign (seqjdg, script) =
        let
          val pos = getAnnotation script
        in
          E.wrap (pos, fn _ => LcfSemantics.tactic (sign, Var.Ctx.empty) script names seqjdg)
        end

      structure Tl = TelescopeUtil (Lcf.Tl)

      fun checkProofState (pos, subgoalsSpec) state =
        let
          val Lcf.|> (subgoals, _) = state
          fun goalEqualTo goal1 goal2 =
            if RedPrlSequent.eq (goal1, goal2) then true
            else
              (RedPrlLog.print RedPrlLog.WARN (pos, Fpp.hvsep [RedPrlSequent.pretty TermPrinter.ppTerm goal1, Fpp.text "not equal to", RedPrlSequent.pretty TermPrinter.ppTerm goal2]);
               false)

          fun go ([], Tl.ConsView.EMPTY) = true
            | go (jdgSpec :: subgoalsSpec, Tl.ConsView.CONS (_, jdgReal, subgoalsReal)) =
                goalEqualTo jdgSpec jdgReal andalso go (subgoalsSpec, Tl.ConsView.out subgoalsReal)
            | go _ = false

          val proofStateCorrect = go (subgoalsSpec, Tl.ConsView.out subgoals)
          val subgoalsCount = Tl.foldr (fn (_,_,n) => 1 + n) 0 subgoals
        in
          if proofStateCorrect then
            E.ret state
          else
            E.warn (pos, Fpp.text (Int.toString (subgoalsCount) ^ " Remaining Obligations"))
              *> E.ret state
        end
    in

      fun elabThm sign opid pos {arguments, params, goal, script} =
        let
          val (arguments', metactx) = elabDeclArguments arguments
          val (params', symctx, env) = elabDeclParams sign params
        in
          E.wrap (pos, fn () => elabSrcSequent (metactx, symctx, Var.Ctx.empty, env) goal) >>= (fn (_, seqjdg as (syms, hyps) >> concl) =>
            let
              (* TODO: deal with syms ?? *)
              val (params'', symctx', env') =
                Hyps.foldr
                  (fn (x, jdgx, (ps, ctx, env)) =>
                    let
                      val taux = CJ.synthesis jdgx
                    in
                      (ps,
                       Tm.Sym.Ctx.insert ctx x (RedPrlSortData.HYP taux),
                       NameEnv.insert env (Sym.toString x) x)
                    end)
                  (params', symctx, env)
                  hyps
              val termSubgoals = argumentsToSubgoals arguments'
            in
              convertToAbt (metactx, symctx', env') script TAC >>= 
              (fn scriptTm => elabRefine sign (seqjdg, scriptTm)) >>= 
              checkProofState (pos, []) >>=
              (fn Lcf.|> (subgoals, validation) => 
                let
                  val subgoals' = Lcf.Tl.append termSubgoals subgoals
                  val state = Lcf.|> (subgoals', validation)
                  val spec = (params'' @ syms, hyps) >> concl
                in
                  E.ret @@ EDEF {sourceOpid = opid, spec = spec, state = state}
                end)
            end)
        end
      end

    fun elabTac (sign : sign) opid {arguments, params, script} =
      let
        val (arguments', metactx) = elabDeclArguments arguments
        val (params', symctx, env) = elabDeclParams sign params
      in
        convertToAbt (metactx, symctx, env) script O.TAC >>= (fn script' =>
          let
            open O Tm infix \
            val subgoals = argumentsToSubgoals arguments'
            val state = Lcf.|> (subgoals, checkb (([],[]) \ script', (([],[]), TAC)))

            val spec = RedPrlSequent.>> ((params', Hyps.empty), CJ.TERM TAC)
          in
            E.ret @@ EDEF {sourceOpid = opid, spec = spec, state = state}
          end)
      end

    fun elabDecl (sign : sign) (opid, eopid) (decl : src_decl, pos) : elab_sign =
      let
        val esign' = ETelescope.truncateFrom (#elabSign sign) eopid
        val sign' = {sourceSign = #sourceSign sign, elabSign = esign', nameEnv = #nameEnv sign}
      in
        ETelescope.snoc esign' eopid (E.delay (fn _ =>
          case processDecl sign decl of
             DEF defn => elabDef sign' opid defn
           | THM defn => elabThm sign' opid pos defn
           | TAC defn => elabTac sign' opid defn))
      end

    fun elabPrint (sign : sign) (pos, opid) =
      E.wrap (SOME pos, fn _ => NameEnv.lookup (#nameEnv sign) opid) >>= (fn eopid =>
        E.hush (ETelescope.lookup (#elabSign sign) eopid) >>= (fn edecl =>
          E.ret (ECMD (PRINT eopid)) <*
            (case edecl of
                EDEF entry => E.info (SOME pos, Fpp.vsep [Fpp.text "Elaborated:", prettyEntry sign (eopid, entry)])
              | _ => E.warn (SOME pos, Fpp.text "Invalid declaration name"))))

    local
      open Tm infix $ \
      fun printExtractOf (pos, state) : unit E.t =
        E.info (SOME pos, Fpp.vsep [Fpp.text "Extract:", TermPrinter.ppTerm (extract state)])
    in
      fun elabExtract (sign : sign) (pos, opid) =
        E.wrap (SOME pos, fn _ => NameEnv.lookup (#nameEnv sign) opid) >>= (fn eopid =>
          E.hush (ETelescope.lookup (#elabSign sign) eopid) >>= (fn edecl =>
            E.ret (ECMD (EXTRACT eopid)) <*
              (case edecl of
                  EDEF entry => printExtractOf (pos, #state entry)
                | _ => E.warn (SOME pos, Fpp.text "Invalid declaration name"))))
    end

    fun elabCmd (sign : sign) (cmd, pos) : elab_sign =
      case cmd of
         PRINT opid =>
           let
             val fresh = Sym.named "_"
           in
             ETelescope.snoc (#elabSign sign) fresh (E.delay (fn _ => elabPrint sign (pos, opid)))
           end
       | EXTRACT opid =>
           let
             val fresh = Sym.named "_"
           in
             ETelescope.snoc (#elabSign sign) fresh (E.delay (fn _ => elabExtract sign (pos, opid)))
           end


    fun insertAstDecl sign opid (decl, pos) =
      let
        val sign' = Telescope.truncateFrom sign opid
      in
        Telescope.snoc sign' opid (decl, pos)
      end
      handle Telescope.Duplicate l => error pos [Fpp.text "Duplicate identitifier:", Fpp.text l]

  in
    fun insert (sign : sign) opid (decl, pos) =
      let
        val sourceSign = insertAstDecl (#sourceSign sign) opid (decl, pos)

        val eopid = Tm.Sym.named opid
        val elabSign = elabDecl sign (opid, eopid) (decl, pos)
        val nameEnv = NameEnv.insert (#nameEnv sign) opid eopid
      in
        {sourceSign = sourceSign, elabSign = elabSign, nameEnv = nameEnv}
      end

    fun command (sign : sign) (cmd, pos) =
      let
        val elabSign = elabCmd sign (cmd, pos)
      in
        {sourceSign = #sourceSign sign, elabSign = elabSign, nameEnv = #nameEnv sign}
      end
  end

  structure L = RedPrlLog

  val checkAlg : (elab_decl, bool) E.alg =
    {warn = fn (msg, _) => (L.print L.WARN msg; false),
     info = fn (msg, r) => (L.print L.INFO msg; r),
     dump = fn (msg, r) => (L.print L.DUMP msg; r),
     init = true,
     succeed = fn (_, r) => r,
     fail = fn (msg, _) => (L.print L.FAIL msg; false)}

  fun check ({elabSign,...} : sign) =
    ETelescope.foldl (fn (_, e, r) => E.fold checkAlg e andalso r) true elabSign
end
