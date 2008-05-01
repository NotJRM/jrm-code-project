﻿using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace Microcode
{
    public abstract class SCode
    {
        // return value is so this is an expression
        internal abstract object EvalStep (Interpreter interpreter, object etc);
    }

    sealed class Access : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly string var;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode env;

        public Access (SCode env, string name)
        {
            this.var = name;
            this.env = env;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.env, new AccessLookup (interpreter.Continuation, this.var));
        }

     }

    sealed class AccessLookup : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly string name;

        public AccessLookup (Continuation parent, string name)
            : base (parent)
        {
            this.name = name;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            Environment env = value as Environment;
            if (env == null)
                env = InterpreterEnvironment.Global;
            return this.Parent.Invoke (interpreter, env.Lookup (this.name));
        }
    }


    sealed class Assignment : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly string target;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode value;

        public Assignment (string target, SCode value)
        {
            if (target == null) throw new ArgumentNullException ("target");
            if (value == null) throw new ArgumentNullException ("value");
            this.target = target;
            this.value = value;
        }

        public string Name
        {
            [DebuggerStepThrough]
            get
            {
                return this.target;
            }
        }

        public override string ToString ()
        {
            return "#<ASSIGNMENT " + this.target + ">";
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.value, new AssignContinue (interpreter.Continuation, this, interpreter.Environment));
        }
    }

    sealed class AssignContinue : Subproblem<Assignment>
    {
        public AssignContinue (Continuation next, Assignment expression, Environment environment)
            : base (next, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.Return (this.Environment.Assign (this.Expression.Name, value));
        }

     }


    sealed class Combination : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode [] components;

        public Combination (SCode [] components)
        {
            this.components = components;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            Environment environment = interpreter.Environment;
            if (components.Length == 1)
            {
                return interpreter.EvalSubproblem (components [0], new CombinationApply (interpreter.Continuation, new object [] { }));
            }
            else
                return interpreter.EvalSubproblem (components [components.Length - 1],
                                                   new CombinationAccumulate (interpreter.Continuation, components,
                                                                              null,
                                                                              components.Length - 1,
                                                                              environment));
        }
    }

    sealed class CombinationAccumulate : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode [] components;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Cons values;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        int index;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Environment environment;

        public CombinationAccumulate (Continuation next, SCode [] components, Cons values, int index, Environment environment)
            : base (next)
        {
            this.components = components;
            this.values = values;
            this.index = index;
            this.environment = environment;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            if (this.index == 1)
            {
                object [] valuevector = new object [this.components.Length - 1];
                Cons tail = this.values;
                int scan = 1;
                valuevector [0] = value;
                while (tail != null)
                {
                    valuevector [scan++] = tail.Car;
                    tail = (Cons) tail.Cdr;
                }
                return interpreter.EvalSubproblem (this.components [0], this.environment, new CombinationApply (this.Parent, valuevector));
            }
            else
                return interpreter.EvalSubproblem (this.components [this.index - 1], this.environment,
                                                   new CombinationAccumulate (this.Parent,
                                                                              this.components,
                                                                              new Cons (value, this.values),
                                                                              this.index - 1,
                                                                              this.environment));
        }
    }

    sealed class CombinationApply : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object [] arguments;

        public CombinationApply (Continuation next, object [] arguments)
            : base (next)
        {
            this.arguments = arguments;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.Apply (value, arguments);
        }
    }


    sealed class Combination1 : SCode, ISystemPair
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rator;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rand;

        public Combination1 (SCode rator, SCode rand)
        {
            if (rator == null)
                throw new ArgumentNullException ("rator");
            if (rand == null)
                throw new ArgumentNullException ("rand");
            this.rator = rator;
            this.rand = rand;
        }

        public SCode Operator
        {
            [DebuggerStepThrough]
            get
            {
                return this.rator;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.rand, new Combination1First (interpreter.Continuation, this, interpreter.Environment));
        }

        #region ISystemPair Members

        public object SystemPairCar
        {
            get
            {
                throw new NotImplementedException ();
            }
            set
            {
                throw new NotImplementedException ();
            }
        }

        public object SystemPairCdr
        {
            get
            {
                throw new NotImplementedException ();
            }
            set
            {
                throw new NotImplementedException ();
            }
        }

        #endregion
    }

    sealed class Combination1First : Subproblem<Combination1>
    {
        public Combination1First (Continuation next, Combination1 expression, Environment environment)
            : base (next, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalSubproblem (this.Expression.Operator, this.Environment, new Combination1Apply (this.Parent, value));
        }
    }

    sealed class Combination1Apply : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand;

        public Combination1Apply (Continuation next, object rand)
            : base (next)
        {
            this.rand = rand;
        }
 
        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.CallProcedure ((SCode) value, this.rand);
        }
    }


    class Combination2 : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rator;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rand0;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rand1;

        public Combination2 (SCode rator, SCode rand0, SCode rand1)
        {
            if (rator == null)
                throw new ArgumentNullException ("rator");
            if (rand0 == null)
                throw new ArgumentNullException ("rand0");
            if (rand1 == null)
                throw new ArgumentNullException ("rand1");
            this.rator = rator;
            this.rand0 = rand0;
            this.rand1 = rand1;
        }

        public static SCode Make (SCode rator, SCode rand0, SCode rand1)
        {
            return new Combination2 (rator, rand0, rand1);
        }

        public SCode Rand1
        {
            [DebuggerStepThrough]
            get
            {
                return this.rand1;
            }
        }

        public SCode Rator
        {
            [DebuggerStepThrough]
            get
            {
                return this.rator;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.rand0, new Combination2First (interpreter.Continuation, this, interpreter.Environment));
        }
    }

    sealed class Combination2First : Subproblem<Combination2>
    {
        public Combination2First (Continuation next, Combination2 expression, Environment environment)
            : base (next, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalSubproblem (this.Expression.Rand1, this.Environment, new Combination2Second (this.Parent, this.Expression, value, this.Environment));
        }
    }

    sealed class Combination2Second : Subproblem<Combination2>
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand0;

 
        public Combination2Second (Continuation next, Combination2 expression, object rand0, Environment environment)
            : base (next, expression, environment)
        {
            this.rand0 = rand0;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalSubproblem (this.Expression.Rator, this.Environment, new Combination2Apply (this.Parent, this.rand0, value));
        }
    }

    sealed class Combination2Apply : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand0;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand1;

        public Combination2Apply (Continuation next, object rand0, object rand1)
            : base (next)
        {
            this.rand0 = rand0;
            this.rand1 = rand1;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.CallProcedure ((SCode) value, this.rand0, this.rand1);
        }
    }

    sealed class Comment : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object text;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode code;

        public Comment (SCode code, object text)
        {
            if (code == null) throw new ArgumentNullException ("code");
            // comment text can be null
            this.code = code;
            this.text = text;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalReduction (this.code);
        }
    }

    sealed class Conditional : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode predicate;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode consequent;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode alternative;

        Conditional (SCode predicate, SCode consequent, SCode alternative)
        {
            if (predicate == null) throw new ArgumentNullException ("predicate");
            if (consequent == null) throw new ArgumentNullException ("consequent");
            if (alternative == null) throw new ArgumentNullException ("alternative");
            this.predicate = predicate;
            this.consequent = consequent;
            this.alternative = alternative;
        }

        public static SCode Make (SCode predicate, SCode consequent, SCode alternative)
        {
            return new Conditional (predicate, consequent, alternative);
        }

        public SCode Predicate
        {
            [DebuggerStepThrough]
            get
            {
                return this.predicate;
            }
        }

        public SCode Consequent
        {
            [DebuggerStepThrough]
            get
            {
                return this.consequent;
            }
        }

        public SCode Alternative
        {
            [DebuggerStepThrough]
            get
            {
                return this.alternative;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.predicate, new ConditionalDecide (interpreter.Continuation, this, interpreter.Environment));
        }
    }

    sealed class ConditionalDecide : Subproblem<Conditional>
    {
        public ConditionalDecide (Continuation next, Conditional expression, Environment environment)
            : base (next, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalReduction (value == null || value is bool && (bool) value == false
                                                  ? this.Expression.Alternative
                                                  : this.Expression.Consequent, this.Environment);
        }
    }


    sealed class Definition : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly string name;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode value;

        public Definition (string name, SCode value)
        {
            if (name == null) throw new ArgumentNullException ("name");
            if (value == null) throw new ArgumentNullException ("value");
            this.name = name;
            this.value = value;
        }

        public string Name
        {
            [DebuggerStepThrough]
            get
            {
                return this.name;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.value, new DefineContinue (interpreter.Continuation, this, interpreter.Environment));
        }
    }

    sealed class DefineContinue : Subproblem<Definition>
    {
        public DefineContinue (Continuation next, Definition definition, Environment environment)
            : base (next, definition, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            this.Environment.AddBinding (this.Expression.Name);
            this.Environment.Assign (this.Expression.Name, value);
            // like MIT Scheme, discard old value and return name.
            return interpreter.Return (this.Expression.Name);
        }
    }

    sealed class Disjunction : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode predicate;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode alternative;

        public Disjunction (SCode predicate, SCode alternative)
        {
            if (predicate == null) throw new ArgumentNullException ("predicate");
            if (alternative == null) throw new ArgumentNullException ("alternative");
            this.predicate = predicate;
            this.alternative = alternative;
        }

        public SCode Alternative
        {
            [DebuggerStepThrough]
            get
            {
                return this.alternative;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.predicate, new DisjunctionDecide (interpreter.Continuation, this, interpreter.Environment));
        }
    }

    sealed class DisjunctionDecide : Subproblem<Disjunction>
    {
        public DisjunctionDecide (Continuation next, Disjunction disjunction, Environment environment)
            : base (next, disjunction, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            if (value == null || value is bool && (bool) value == false)
            {
                return interpreter.EvalReduction (this.Expression.Alternative, this.Environment);
            }
            else
                return interpreter.Return (value);
        }
    }


    class Lambda : SCode, ISystemPair
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public readonly string [] formals;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public readonly SCode body;

        public Lambda (SCode body, string [] formals)
        {
            // body can be null?!
            if (formals == null)
                throw new ArgumentNullException ("formals");
            this.body = body;
            this.formals = formals;
        }

        public Lambda (object body, object formals)
        {
            SCode sbody = body as SCode;

            object [] cdrArray = (object []) formals;
            string [] sformals = new string [cdrArray.Length];
            for (int i = 0; i < sformals.Length; i++)
                sformals [i] = (string) cdrArray [i];
            this.body = (sbody == null) ? Quotation.Make (body) : sbody;
            this.formals = sformals;
        }

        public SCode Body
        {
            [DebuggerStepThrough]
            get
            {
                return this.body;
            }
        }

        public string Name
        {
            [DebuggerStepThrough]
            get
            {
                return this.formals [0];
            }
        }

        public string [] Formals
        {
            [DebuggerStepThrough]
            get
            {
                return this.formals;
            }
        }

        public int FormalOffset (string name)
        {
            for (int i = 0; i < formals.Length; i++)
                //if (name == formals [i])
                if (Object.ReferenceEquals (name, formals [i]))
                    return i - 1;
            return -1;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.Return (new Closure (this, interpreter.Environment));
        }


        #region ISystemPair Members

        public object SystemPairCar
        {
            get
            {
                throw new NotImplementedException ();
            }
            set
            {
                throw new NotImplementedException ();
            }
        }

        public object SystemPairCdr
        {
            get
            {
                throw new NotImplementedException ();
            }
            set
            {
                throw new NotImplementedException ();
            }
        }

        #endregion
    }

    sealed class ExtendedLambda : Lambda
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public readonly uint required;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public readonly uint optional;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public readonly bool rest;

        public ExtendedLambda (SCode body, string [] formals, uint required, uint optional, bool rest)
            : base (body, formals)
        {
            this.required = required;
            this.optional = optional;
            this.rest = rest;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.Return (new ExtendedClosure (this, interpreter.Environment));
        }
    }

    sealed class PrimitiveCombination0 : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Primitive0 procedure;

        public PrimitiveCombination0 (Primitive0 procedure)
        {
            if (procedure == null) throw new ArgumentNullException ("procedure");
            this.procedure = procedure;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.CallPrimitive (this.procedure);
        }
    }

    sealed class PrimitiveCombination1 : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        Primitive1 procedure;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        SCode arg0;

        PrimitiveCombination1 (Primitive1 procedure, SCode arg0)
        {
            this.procedure = procedure;
            this.arg0 = arg0;
        }

        public static SCode Make (Primitive1 rator, SCode rand)
        {
            if (rator == null) throw new ArgumentNullException ("rator");
            if (rand == null) throw new ArgumentNullException ("rand");
            return new PrimitiveCombination1 (rator, rand);
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.arg0, new PrimitiveCombination1Apply (interpreter.Continuation, this.procedure));
        }
    }

    sealed class PrimitiveCombination1Apply : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Primitive1 rator;

        public PrimitiveCombination1Apply (Continuation next, Primitive1 rator)
            : base (next)
        {
            this.rator = rator;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.CallPrimitive (this.rator, value);
        }

        public Primitive1 Operator
        {
            [DebuggerStepThrough]
            get
            {
                return this.rator;
            }
        }
    }


    class PrimitiveCombination2 : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Primitive2 rator;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rand0;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode rand1;

        protected PrimitiveCombination2 (Primitive2 rator, SCode rand0, SCode rand1)
        {
            this.rator = rator;
            this.rand0 = rand0;
            this.rand1 = rand1;
        }

        public Primitive2 Rator
        {
            [DebuggerStepThrough]
            get
            {
                return this.rator;
            }
        }

        public SCode Rand0
        {
            [DebuggerStepThrough]
            get
            {
                return this.rand0;
            }
        }

        public SCode Rand1
        {
            [DebuggerStepThrough]
            get
            {
                return this.rand1;
            }
        }

        public static SCode Make (Primitive2 rator, SCode rand0, SCode rand1)
        {
            if (rator == null)
                throw new ArgumentNullException ("rator");
            if (rand0 == null)
                throw new ArgumentNullException ("rand0");
            if (rand1 == null)
                throw new ArgumentNullException ("rand1");
            return new PrimitiveCombination2 (rator, rand0, rand1);
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.rand0, new PrimitiveCombination2First (interpreter.Continuation, this, interpreter.Environment));

        }
    }

    sealed class PrimitiveCombination2First : Subproblem<PrimitiveCombination2>
    {
        public PrimitiveCombination2First (Continuation next, PrimitiveCombination2 expression, Environment environment)
            : base (next, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalSubproblem (this.Expression.Rand1, this.Environment, new PrimitiveCombination2Apply (this.Parent, this.Expression.Rator, value));
        }
    }

    sealed class PrimitiveCombination2Apply : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Primitive2 rator;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand0;

        public PrimitiveCombination2Apply (Continuation next, Primitive2 rator, object rand0)
            : base (next)
        {
            this.rator = rator;
            this.rand0 = rand0;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.CallPrimitive (this.rator, this.rand0, value);
        }
    }

    sealed class PrimitiveCombination3 : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        Primitive3 procedure;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        SCode arg0;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        SCode arg1;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        SCode arg2;

        public PrimitiveCombination3 (Primitive3 procedure, SCode arg0, SCode arg1, SCode arg2)
        {
            if (procedure == null) throw new ArgumentNullException ("procedure");
            if (arg0 == null) throw new ArgumentNullException ("arg0");
            if (arg1 == null) throw new ArgumentNullException ("arg1");
            if (arg2 == null) throw new ArgumentNullException ("arg2");
            this.procedure = procedure;
            this.arg0 = arg0;
            this.arg1 = arg1;
            this.arg2 = arg2;
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.arg0, new PrimitiveCombination3First (interpreter.Continuation, this, interpreter.Environment));
        }

        public Primitive3 Operator
        {
            [DebuggerStepThrough]
            get
            {
                return this.procedure;
            }
        }

        public SCode Operand0
        {
            [DebuggerStepThrough]
            get
            {
                return this.arg0;
            }
        }

        public SCode Operand1
        {
            [DebuggerStepThrough]
            get
            {
                return this.arg1;
            }
        }

        public SCode Operand2
        {
            [DebuggerStepThrough]
            get
            {
                return this.arg2;
            }
        }

        [SchemePrimitive ("PRIMITIVE-COMBINATION3?", 1)]
        public static void IsPrimitiveCombination3 (Interpreter interpreter, object arg)
        {
            interpreter.Return (arg is PrimitiveCombination3);
        }
    }

    sealed class PrimitiveCombination3First : Subproblem<PrimitiveCombination3>
    {
        public PrimitiveCombination3First (Continuation next, PrimitiveCombination3 expression, Environment environment)
            : base (next, expression, environment)
        {
        }

 
        internal override object Invoke (Interpreter interpreter, object value)
        {
             return interpreter.EvalSubproblem (this.Expression.Operand1, this.Environment, new PrimitiveCombination3Second (this.Parent, this.Expression, this.Environment, value));
        }
    }

    sealed class PrimitiveCombination3Second : Subproblem<PrimitiveCombination3>
    {
        readonly object rand0;

        public PrimitiveCombination3Second (Continuation next, PrimitiveCombination3 expression, Environment environment, object rand0)
            : base (next, expression, environment)
        {
            this.rand0 = rand0;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalSubproblem (this.Expression.Operand2, this.Environment, new PrimitiveCombination3Apply (this.Parent, this.Expression.Operator, this.rand0, value));
        }
    }

    sealed class PrimitiveCombination3Apply : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly Primitive3 rator;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand0;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object rand1;

        public PrimitiveCombination3Apply (Continuation next, Primitive3 rator, object rand0, object rand1)
            : base (next)
        {
            this.rator = rator;
            this.rand0 = rand0;
            this.rand1 = rand1;
        }


        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.CallPrimitive (this.rator, this.rand0, this.rand1, value);
        }
    }

    sealed class Quotation : SCode
    {
        // Space optimization.
        static Dictionary<object, Quotation> table = new Dictionary<object, Quotation> (8000);
        static Quotation QuoteNull;

        static int cacheHits;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object item;

        Quotation (object item)
        {
            this.item = item;
        }

        static bool cacheItem (object item)
        {
            return (item is bool)
                || (item is char)
                || (item is int)
                || (item is string)
                || (item is Constant)
                || (item is Primitive)
                || (item is ReferenceTrap)
                ;
        }

        public static Quotation Make (object item)
        {
            if (item == null) {
                if (QuoteNull == null)
                    QuoteNull = new Quotation (null);
                return QuoteNull;
            }
            else if (cacheItem (item)) {
                Quotation probe;
                cacheHits++;
                if (table.TryGetValue (item, out probe) != true) {
                    cacheHits--;
                    probe = new Quotation (item);
                    table.Add (item, probe);
                }
                return probe;
            }
            else
                return new Quotation (item);
        }

        public object Quoted
        {
            [DebuggerStepThrough]
            get
            {
                return this.item;
            }
        }

        public override string ToString ()
        {
            if (this.item == null)
                return "#<SCODE-QUOTE NULL>";
            else
                return "#<SCODE-QUOTE " + this.item.ToString () + ">";
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.Return (this.item);
        }
    }

    sealed class RestoreInterruptMask : Continuation
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly int old_mask;

        public RestoreInterruptMask (Continuation next, int old_mask)
            : base (next)
        {
            this.old_mask = old_mask;
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            interpreter.InterruptMask = this.old_mask;
            return interpreter.Return (value);
        }
    }


    sealed class Sequence2 : SCode, ISystemPair
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode first;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode second;

        public Sequence2 (SCode first, SCode second)
        {
            if (first == null)
                throw new ArgumentNullException ("first");
            if (second == null)
                throw new ArgumentNullException ("second");
            this.first = first;
            this.second = second;
        }

        public SCode Second
        {
            [DebuggerStepThrough]
            get
            {
                return this.second;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.first, new Sequence2Second (interpreter.Continuation, this, interpreter.Environment));
        }

        #region ISystemPair Members

        public object SystemPairCar
        {
            get
            {
                throw new NotImplementedException ();
            }
            set
            {
                throw new NotImplementedException ();
            }
        }

        public object SystemPairCdr
        {
            get
            {
                throw new NotImplementedException ();
            }
            set
            {
                throw new NotImplementedException ();
            }
        }

        #endregion
    }

    sealed class Sequence2Second : Subproblem<Sequence2>
    {
        public Sequence2Second (Continuation next, Sequence2 sequence, Environment environment)
            : base (next, sequence, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalReduction (this.Expression.Second, this.Environment);
        }
    }


    sealed class Sequence3 : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode first;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode second;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly SCode third;

        public Sequence3 (SCode first, SCode second, SCode third)
        {
            if (first == null)
                throw new ArgumentNullException ("first");
            if (second == null)
                throw new ArgumentNullException ("second");
            if (third == null)
                throw new ArgumentNullException ("third");
            this.first = first;
            this.second = second;
            this.third = third;
        }

        public SCode First
        {
            [DebuggerStepThrough]
            get
            {
                return this.first;
            }
        }

        public SCode Second
        {
            [DebuggerStepThrough]
            get
            {
                return this.second;
            }
        }

        public SCode Third
        {
            [DebuggerStepThrough]
            get
            {
                return this.third;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.EvalSubproblem (this.first, 
                new Sequence3Second (interpreter.Continuation, this, interpreter.Environment)); 
        }
    }

    class Sequence3Second : Subproblem<Sequence3>
    {
        public Sequence3Second (Continuation parent, Sequence3 expression, Environment environment)
            : base (parent, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalSubproblem (this.Expression.Second, this.Environment, new Sequence3Third (this.parent, this.Expression, this.Environment));
        }
    }

    sealed class Sequence3Third : Subproblem<Sequence3>
    {
        public Sequence3Third (Continuation next, Sequence3 expression, Environment environment)
            : base (next, expression, environment)
        {
        }

        internal override object Invoke (Interpreter interpreter, object value)
        {
            return interpreter.EvalReduction (this.Expression.Third, this.Environment);
        }
    }

    sealed class TheEnvironment : SCode
    {
        public TheEnvironment ()
        {
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.Return (interpreter.Environment);
        }
    }

    class Variable : SCode
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public readonly string name;

        public Variable (string name)
        {
            if (name == null)
                throw new ArgumentNullException ("name");
            this.name = name;
        }

        string Name
        {
            get
            {
                return this.name;
            }
        }

        internal override object EvalStep (Interpreter interpreter, object etc)
        {
            return interpreter.Return (interpreter.Environment.Lookup (this.name));
        }
    }
}
