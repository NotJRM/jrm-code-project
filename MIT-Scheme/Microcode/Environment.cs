﻿using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace Microcode
{
    [Serializable]
    public abstract class Environment : SchemeObject, ISystemVector
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        public override TC TypeCode { get { return TC.ENVIRONMENT; } }

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        static readonly GlobalEnvironment systemGlobalEnvironment = new GlobalEnvironment ();

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        internal readonly ClosureBase closure;

        internal Environment (ClosureBase closure)
        {
            this.closure = closure;
        }

        // Gets the closure that created this closureEnvironment
        internal ClosureBase Closure { [DebuggerStepThrough] get { return this.closure; } }

        public static GlobalEnvironment Global
        {
            [DebuggerStepThrough]
            get
            {
                return systemGlobalEnvironment;
            }
        }

        // This is to capture stupid calls to `ToEnvironment' when we
        // already know it is an environmnet.
        static public Environment ToEnvironment (Environment env)
        {
            throw new NotImplementedException ();
        }

        static public Environment ToEnvironment (object env)
        {
            Environment eenv = env as Environment;
            if (eenv == null) {
                if (env is bool && (bool) env == false)
                    return Environment.Global;
                else
                    throw new NotImplementedException ();
            }
            else
                return eenv;
        }

#if DEBUG
        [NonSerialized]
        static protected long [] foundAtDepth = new long [128];
        [NonSerialized]
        static protected long [] foundInAuxes = new long [128];
        [NonSerialized]
        static protected long [] foundInGlobal = new long [128];
        [NonSerialized]
        static protected long [] extendedBy = new long [1024];
#endif

        // Abstract functions on environments

        // Grab the variable at randOffset in frame.  Must be int.
        public abstract object ArgumentValue (int offset);
        public abstract object Argument0Value { get; }
        public abstract object Argument1Value { get; }

        // Deep search for variable location and smash the value.
        public abstract bool Assign (out object oldValue, object name, object newValue);
        //internal abstract bool AssignArg (out object oldValue, ushort offset, object newValue);

        // Define a variable in the topmost frame.  This will shadow
        // other definitions.  Returns false on success, true if there
        // is a problem.
        public abstract bool Define (object name, object value);

        // Deep search the lexical closureEnvironment for the variable.
        // returns false on success, true if there is a problem.
        public abstract bool DeepSearch (out object value, object name);
        // internal call tracks randDepth.
        internal abstract bool DeepSearch (out object value, object name, uint depth);
        public abstract bool DeepSearchSkip (out object value, object name, int skip);
        internal abstract bool DeepSearchSkip (out object value, object name, int skip, uint depth);
        internal abstract bool DeepSearchType (out object value, object name);

        // Used to link variables.
        internal abstract ValueCell GetValueCell (object name);

        internal abstract bool LexicalRef (out object value, object name, int depth, int offset);
        // LexicalRef1 is a lexical variable one frame back.
        internal abstract bool LexicalRef1 (out object value, object name, int offset);
        // Fast lexical ref does not check the incrementals.
        //internal abstract bool FastLexicalRef (out object value, LexicalVariable lexicalVariable);
        //internal abstract bool FastLexicalRef1 (out object value, LexicalVariable lexicalVariable);

        internal abstract TRet LocateVariable<TRet> (object name,
            Func<ValueCell, TRet> ifExistingGlobal,
            Func<GlobalEnvironment, TRet> ifFutureGlobal,
            Func<int,TRet> ifArgument,
            Func<int,TRet> ifLexical1,
            Func<int,int,TRet> ifLexical);

        internal abstract Environment PartialExtend (LambdaBase lamda);

        // walk up the chain.  Zero steps means stay here.
        // int is necessary here
        internal abstract Environment GetAncestorEnvironment (int depth);

        // Implementation of primitive.
        internal abstract bool SafeDeepSearch (out object value, object name);

        internal abstract int SearchFormals (object name);
        internal abstract ValueCell SearchIncrementals (object name);
        // Used to link variables.
        internal abstract bool SetValueCell (object name, ValueCell newCell);
        internal abstract bool IsUnbound (object name);
        internal abstract bool IsUnreferenceable (object name);

        internal abstract bool UnbindVariable (out object answer, object name);

        [SchemePrimitive ("LEXICAL-UNBOUND?", 2, false)]
        public static bool IsLexicalUnbound (out object answer, object env, object name)
        {
            answer = ToEnvironment (env).IsUnbound ((Symbol) name);
            return false; // copacetic
        }

        [SchemePrimitive ("LEXICAL-UNREFERENCEABLE?", 2, false)]
        public static bool IsLexicalUnreferenceable (out object answer, object env, object name)
        {
            answer = ToEnvironment (env).IsUnreferenceable ((Symbol) name);
            return false; // copacetic
        }

        // Same as assigning in the interpreter.
        [SchemePrimitive ("LEXICAL-ASSIGNMENT", 3, false)]
        public static bool LexicalAssignment (out object answer, object aenv, object aname, object value)
        {
            Environment env = ToEnvironment (aenv);
            Symbol name = (Symbol) aname;
            object oldValue;
            if (env.Assign (out oldValue, name, value))
                throw new NotImplementedException ("error during assignment");
            answer = oldValue;
            return false;
        }

        // Same as evaluating variable.
        [SchemePrimitive ("LEXICAL-REFERENCE", 2, false)]
        public static bool LexicalReference (out object answer, object env, object name)
        {
            if (ToEnvironment (env).DeepSearch (out answer, (Symbol) name))
                throw new NotImplementedException ("Error during lexical-reference.");
            return false;
        }

        // Looks up variable, tells whether it is a macro, unassigned, etc.
        [SchemePrimitive ("LEXICAL-REFERENCE-TYPE", 2, false)]
        public static bool LexicalReferenceType (out object answer, object env, object name)
        {
            if (ToEnvironment (env).DeepSearchType (out answer, (Symbol) name))
                throw new NotImplementedException ("Error during lexical-reference-type.");
            return false;
        }


        [SchemePrimitive ("SAFE-LEXICAL-REFERENCE", 2, false)]
        public static bool SafeLexicalReference (out object answer, object env, object name)
        {
            if (ToEnvironment (env).SafeDeepSearch (out answer, (Symbol) name))
                throw new NotImplementedException ("Error during lexical-reference.");
            return false;
        }

        [SchemePrimitive ("LINK-VARIABLES", 4, false)]
        public static bool LinkVariables (out object answer, object [] arglist)
        {
            Environment target_env = ToEnvironment (arglist [0]);

            Symbol target_name = (Symbol) arglist [1];
            Environment source_env = ToEnvironment (arglist [2]);
            Symbol source_name = (Symbol) arglist [3];
            if (target_env.SetValueCell (target_name, source_env.GetValueCell (source_name)))
                throw new NotImplementedException ("Error during link-variables.");
            else {
                answer = null;
                return false;
            }
        }


        // This has the same effect as a DEFINE in the interpreter.
        [SchemePrimitive ("LOCAL-ASSIGNMENT", 3, false)]
        public static bool LocalAssignment (out object answer, object env, object aname, object value)
        {
            if (ToEnvironment (env).Define ((Symbol) aname, value)) throw new NotImplementedException ();

            answer = aname;
            return false;
        }

        [SchemePrimitive ("ENVIRONMENT?", 1, true)]
        public static bool IsEnvironment (out object answer, object arg)
        {
            answer = arg is Environment || (arg is bool && (bool) arg == false);
            return false;
        }

        [SchemePrimitive ("UNBIND-VARIABLE", 2, false)]
        public static bool UnbindVariable (out object answer, object env, object name)
        {
            if (ToEnvironment (env).UnbindVariable (out answer, (Symbol) name))
                throw new NotImplementedException ("Error during lexical-reference-type.");
            return false;
        }

        #region ISystemVector Members

        public int SystemVectorSize
        {
            get { throw new NotImplementedException (); }
        }

        public virtual object SystemVectorRef (int index)
        {
            throw new NotImplementedException ();
        }

        public object SystemVectorSet (int index, object newValue)
        {
            throw new NotImplementedException ();
        }

        #endregion
    }

    // There are four different kinds of closureEnvironment.  
    // The null closureEnvironment doesn't respond to anything yet.
    // A Root closureEnvironment has no parent and no frame.  It is
    // used for the systemGlobalEnvironment closureEnvironment.
    // A `Top Level' closureEnvironment has a frame and incrementals.
    // it can be extended, searched, etc.  A full-feature closureEnvironment.

    [Serializable]
    class NullEnvironment : Environment
    {
        public NullEnvironment (ClosureBase closure)
            : base (closure)
        {
        }

        public override object ArgumentValue (int offset)
        {
            throw new NotImplementedException ();
        }

        public override bool Assign (out object oldValue, object name, object newValue)
        {
            throw new NotImplementedException ();
        }

        public override bool Define (object name, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearch (out object value, object name, uint depth)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object name, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchType (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object name)
        {
            throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }
        public override object Argument1Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        //internal override bool FastLexicalRef (out object value, object name, uint depth, uint offset)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment GetAncestorEnvironment (int depth)
        {
            if (depth == 0) return this;
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            throw new NotImplementedException ();
        }

        //internal override bool AssignArg (out object oldValue, uint offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }

    [Serializable]
    public sealed class GlobalEnvironment : Environment
    {
        // Object -> value cell so we have EQ semantics
        // rather than string= semantics.
        readonly Dictionary<object, ValueCell> globalBindings = new Dictionary<object, ValueCell> ();

        public GlobalEnvironment ()
            : base (null)
        {
        }

        public override object ArgumentValue (int offset)
        {
            throw new NotImplementedException ();
        }

        public override bool Assign (out object oldValue, object name, object newValue)
        {
            ValueCell vcell = null;
            if (this.globalBindings.TryGetValue (name, out vcell)) {
                if (vcell.Assign (out oldValue, newValue))
                    throw new NotImplementedException ("Error in Assign.");
                return false;
            }
            throw new NotImplementedException ("IsUnbound variable in Assign.");
        }

        public override bool Define (object name, object value)
        {
            ValueCell cell = null;
            if (this.globalBindings.TryGetValue (name, out cell) == false) {
                cell = new ValueCell (name, value);
                this.globalBindings.Add (name, cell);
            }
            else {
                object oldValue;
                Debug.WriteLine ("Redefining " + name);
                cell.Assign (out oldValue, value);
            }
            return false; // no problems
        }

        public override bool DeepSearch (out object value, object name)
        {
            return DeepSearch (out value, name, 0);
        }

        internal override bool DeepSearch (out object value, object name, uint depth)
        {
            ValueCell cell = null;
            if (this.globalBindings.TryGetValue (name, out cell)) {
#if DEBUG
                foundInGlobal [depth] += 1;
#endif
                if (cell.GetValue (out value))
                    throw new NotImplementedException ("Error getting value from cell");
                return false;
            }
            value = new UnboundVariableError ((Symbol) name);
            return true;
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object name)
        {
            ValueCell cell = null;
            this.globalBindings.TryGetValue (name, out cell);
            return cell;
        }

        internal override bool SafeDeepSearch (out object value, object name)
        {
            ValueCell cell = null;
            if (this.globalBindings.TryGetValue (name, out cell)) {

                if (cell.SafeGetValue (out value))
                    throw new NotImplementedException ("Error getting value from cell");
                return false;
            }
            throw new NotImplementedException ("Variable not bound");
        }

        internal override bool DeepSearchType (out object value, object name)
        {
            ValueCell cell = null;
            if (this.globalBindings.TryGetValue (name, out cell)) {

                if (cell.GetType (out value))
                    throw new NotImplementedException ("Error getting value from cell");
                return false;
            }
            // if it is unbound, the reference type is 0
            value = 0;
            return false;
        }

        internal override bool SetValueCell (object name, ValueCell newCell)
        {
            ValueCell cell = null;
            if (this.globalBindings.TryGetValue (name, out cell)) {
                if (cell != newCell)
                    throw new NotImplementedException ("Value cell already exists.");
                else
                    // No effect to just do it again, even if it is weird.
                    return false;
            }
            this.globalBindings.Add (name, newCell);
            return false; // copacetic
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        internal override bool IsUnreferenceable (object name)
        {
            ValueCell vcell;
            if (this.globalBindings.TryGetValue (name, out vcell)) {
                return vcell.Unreferenceable ();
            }
            else return true;
        }

        internal override bool IsUnbound (object name)
        {
            throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        public override object Argument1Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        //internal override bool FastLexicalRef (out object value, object name, uint depth, uint offset)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override Environment GetAncestorEnvironment (int depth)
        {
            if (depth == 0) return this;
            else throw new NotImplementedException ("Global environments have no ancestor.");
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            throw new NotImplementedException ();
        }

        //internal override bool FastLexicalRef1 (out object value, object name, uint offset)
        //{
        //    throw new NotImplementedException ();
        //}

        //internal override bool AssignArg (out object oldValue, uint offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}
        internal override TRet LocateVariable<TRet> (object name, 
            Func<ValueCell, TRet> ifExistingGlobal,
            Func<GlobalEnvironment, TRet> ifFutureGlobal,
            Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            ValueCell vcell;
            if (this.globalBindings.TryGetValue (name, out vcell)) {
                return ifExistingGlobal (vcell);
            }
            else
                // Doesn't exist, but might when invoked.
                return ifFutureGlobal (this);
        }

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lambda)
        {
            return new PartialEnvironment (lambda.PartialClose (this));
        }
    }

    class PartialEnvironment : Environment
    {
        bool incrementals;

        public PartialEnvironment (PartialClosure closure)
            : base (closure)
        {
            this.incrementals = closure.FirstClassEnvironment;
        }

        public override object ArgumentValue (int offset)
        {
            throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get { throw new NotImplementedException (); }
        }

        public override object Argument1Value
        {
            get { throw new NotImplementedException (); }
        }

        public override bool Assign (out object oldValue, object name, object newValue)
        {
            throw new NotImplementedException ();
        }

        public override bool Define (object name, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearch (out object value, object name, uint depth)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchType (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name,
            Func<ValueCell, TRet> ifExistingGlobal,
            Func<GlobalEnvironment, TRet> ifFutureGlobal,
            Func<int,  TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int,int,TRet> ifLexical)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                if (this.incrementals) {
                    // Aux variables exist, cannot skip this frame.
                    return this.closure.Environment.LocateVariable<TRet> (name,
                           delegate (ValueCell vcell) { throw new NotImplementedException (); },
                           delegate (GlobalEnvironment env) { throw new NotImplementedException(); },
                           delegate (int argOffset) { throw new NotImplementedException(); },
                           delegate (int lex1Offset) { throw new NotImplementedException(); },
                           delegate (int lexDepth, int lexOffset) { throw new NotImplementedException(); }
                    );
                }
                else {
                    // No aux variables, so we can skip this frame.
                    return this.closure.Environment.LocateVariable<TRet> (name,
                        delegate (ValueCell vcell) { throw new NotImplementedException (); },
                        ifFutureGlobal,
                        ifLexical1,
                        delegate (int lexical1Offset) { return ifLexical (2, lexical1Offset); },
                        delegate (int lexicalDepth, int lexicalOffset) { return ifLexical (lexicalDepth + 1, lexicalOffset); }
                    );
                }
            }
            else {
                return ifArgument (offset);
            }  
        }

        internal override Environment PartialExtend (LambdaBase lambda)
        {
            return new PartialEnvironment (lambda.PartialClose (this));
        }

        internal override Environment GetAncestorEnvironment (int depth)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object name, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }
    }

    [Serializable]
    abstract class LexicalEnvironment : Environment
    {
#if DEBUG
        //static long lexicalCacheCreations;
        //static long lexicalCacheHits;
        //static long lexicalCacheSavings;
        //static long lexicalRefCount;
#endif
        //long transitCount;
        //Environment [] lexicalCache;

        protected LexicalEnvironment (ClosureBase closure)
            : base (closure)
        {
        }

//        internal override bool FastLexicalRef (out object value, object name, LexicalAddress address)
//        {
//#if DEBUG
//            lexicalRefCount += 1;
//            //if (depth < 2) Debugger.Break ();
//#endif
//            switch (address.Depth) {
//                case 0: value = this.ArgumentValue (address.Offset); break;
//                case 1: value = this.closure.Environment.ArgumentValue (address.Offset); break;
//                default: value = GetAncestorEnvironment (address.Depth).ArgumentValue (address.Offset); break;
//            }
//            return false;
//        }


        internal override Environment GetAncestorEnvironment (int depth)
        {
            throw new NotImplementedException();
//            if (depth == 0) throw new NotImplementedException ();
//            else if (depth == 1) return this.closure.Environment;
//            else {
//                if (this.lexicalCache == null) {
//                    if ((transitCount++ < 4 && this.Closure.Lambda.LexicalCacheSize == 0) ||
//                         !Configuration.EnableLexicalCache) {
//                        return this.Closure.Environment.GetAncestorEnvironment (depth - 1);
//                    }
//                    else {
//#if DEBUG
//                        lexicalCacheCreations += 1;
//#endif
//                        int size = this.Closure.Lambda.LexicalCacheSize;
//                        if (size < depth) {
//                            size = depth;
//                            this.Closure.Lambda.LexicalCacheSize = depth;
//                        }
//                        this.lexicalCache = new Environment [size + 1];
//                    }
//                }
//                else if (this.lexicalCache.Length <= depth) {
//                    this.Closure.Lambda.LexicalCacheSize = depth;
//                    Environment [] newCache = new Environment [depth + 1];
//                    Array.Copy (this.lexicalCache, newCache, this.lexicalCache.Length);
//                    this.lexicalCache = newCache;
//                }

//                Environment env = this.lexicalCache [depth];
//                if (env == null) {
//#if DEBUG
//                    lexicalCacheHits -= 1;
//#endif
//                    env = this.Closure.Environment.GetAncestorEnvironment (depth - 1);
//                    this.lexicalCache [depth] = env;
//                }
//                else {
//#if DEBUG
//                    lexicalCacheSavings += (depth - 1);
//#endif
//                }
//#if DEBUG
//                lexicalCacheHits += 1;
//#endif
//                return env;
//           }
        }

        public override object ArgumentValue (int offset)
        {
            throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get { throw new NotImplementedException (); }
        }

        public override object Argument1Value
        {
            get { throw new NotImplementedException (); }
        }

        public override bool Assign (out object oldValue, object name, object newValue)
        {
            throw new NotImplementedException ();
        }

        public override bool Define (object name, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearch (out object value, object name, uint depth)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchType (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object name, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object name)
        {
            throw new NotImplementedException ();
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        //internal override bool FastLexicalRef1 (out object value, object name, int offset)
        //{
        //    throw new NotImplementedException ();
        //}

    }


    /// <summary>
    /// A StandardEnvironment supports sharable bindings and incremental
    /// definition.
    /// </summary>
    [Serializable]
    sealed class StandardEnvironment : LexicalEnvironment
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly ValueCell [] bindings;
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        Dictionary <object,ValueCell> incrementals;

        internal StandardEnvironment (ClosureBase closure)
            : base (closure)
        {
#if DEBUG
            extendedBy [0] += 1;
            // sanity check.
            object [] formals = closure.Lambda.Formals;
            if (formals.Length != 0)
                throw new NotImplementedException ();
#endif
        }

        internal StandardEnvironment (ClosureBase closure, object [] initialValues)
            : base (closure)
        {
            object [] formals = closure.Lambda.Formals;
            this.bindings = new ValueCell [initialValues.Length];
            for (int i = 0; i < initialValues.Length; i++)
                this.bindings [i] = new ValueCell (formals [i], initialValues [i]);
#if DEBUG
            extendedBy [initialValues.Length] += 1;
            // sanity check
            if (formals.Length != initialValues.Length)
                throw new NotImplementedException ();
#endif
        }

        internal override int SearchFormals (object name)
        {
            return this.closure.FormalOffset (name);
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            ValueCell vcell = null;
            if (this.incrementals != null)
                this.incrementals.TryGetValue (name, out vcell);
            return vcell;
        }

        public override object ArgumentValue (int offset)
        {
            object answer;
            if (bindings [offset].GetValue (out answer)) throw new NotImplementedException ();
            return answer;
        }

        public override object Argument0Value
        {
            get
            {
                object answer;
                if (bindings [0].GetValue (out answer)) throw new NotImplementedException ();
                return answer;
            }
        }

        public override object Argument1Value
        {
            get
            {
                object answer;
                if (bindings [1].GetValue (out answer)) throw new NotImplementedException ();
                return answer;
            }
        }

        public override bool Assign (out object oldValue, object name, object newValue)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (this.incrementals != null
                    && this.incrementals.TryGetValue (name, out vcell))
                    return vcell.Assign (out oldValue, newValue);
                else
                    return closure.Environment.Assign (out oldValue, name, newValue);
            }
            return bindings [offset].Assign (out oldValue, newValue);
        }

        public override bool Define (object name, object value)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                if (this.incrementals == null)
                    this.incrementals = new Dictionary<object, ValueCell> ();
                ValueCell vcell;
                if (this.incrementals.TryGetValue (name, out vcell)) {
                    // cell exists.
                    object oldValue = null;
                    if (vcell.Assign (out oldValue, value))
                        throw new NotImplementedException ("Error during incremental definition.");
                    return false; // copacetic
                }
                else {
                    this.incrementals.Add (name, new ValueCell (name, value));
                    return false;
                }
            }
            else {
                object oldValue = null;
                if (this.bindings [offset].Assign (out oldValue, value))
                    throw new NotImplementedException ("Error during redefinition.");
                return false;
            }
        }

        public override bool DeepSearch (out object value, object name)
        {
            return DeepSearch (out value, name, 0);
        }

        internal override bool DeepSearch (out object value, object name, uint depth)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (this.incrementals != null
                    && this.incrementals.TryGetValue (name, out vcell)) {
#if DEBUG
                    foundInAuxes [depth] += 1;
#endif
                    return vcell.GetValue (out value);
                }
                else
                    return closure.Environment.DeepSearch (out value, name, depth + 1);
            }
#if DEBUG
            foundAtDepth [depth] += 1;
#endif
            return bindings [offset].GetValue (out value);
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            if (skip == 0)
                return DeepSearch (out value, name, depth);
            else
                return closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

        //internal override bool FastLexicalRef (out object value, object name, int depth, int offset)
        //{
        //    throw new NotImplementedException ();
        ////    if (randDepth == 0) return bindings [randOffset].GetValue (out value);
        ////    ValueCell vcell;
        ////    if (this.incrementals != null
        ////        && this.incrementals.TryGetValue (ratorName, out vcell)) {
        ////        return vcell.GetValue (out value);
        ////    }

        ////    return closure.Environment.FastLexicalRef (out value, ratorName, randDepth - 1, randOffset);
        //}

        internal override TRet LocateVariable<TRet> (object name,
            Func<ValueCell, TRet> ifExistingGlobal,
            Func<GlobalEnvironment, TRet> ifFutureGlobal,
            Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
            //int offset = this.closure.FormalOffset (name);
            //if (offset == -1) {
            //    ValueCell vcell;
            //    if (this.incrementals != null
            //        && this.incrementals.TryGetValue (name, out vcell)) {
            //        return ifAux (this, 0);
            //    }
            //    else {
            //        throw new NotImplementedException ();
            //        //return LocateVariable (name,
            //        //    ifNotFound,
            //        //    ifGlobal,
            //        //    delegate (LexicalEnvironment env, int depth, int offset1) { return ifLexical (env, depth + 1, offset1); },
            //        //    delegate (StandardEnvironment env, int depth) { return ifAux (env, depth + 1); });
            //    }
            //}
            //return ifLexical (this, 0, offset);
        }

        internal override ValueCell GetValueCell (object name)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (this.incrementals != null
                    && this.incrementals.TryGetValue (name, out vcell)) {
                    return vcell;
                }
                else
                    return closure.Environment.GetValueCell (name);
            }
            return bindings [offset];
        }

        internal override bool SetValueCell (object name, ValueCell newCell)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (incrementals != null
                    && incrementals.TryGetValue (name, out vcell)) {
                    throw new NotImplementedException ("Existing value cell in incrementals.");
                }
                else {
                    // no existing value cell in incrementals.
                    // add one.
                    // Shadow any existing value cell.
                    incrementals.Add (name, newCell);
                    return false; //ok
                }
            }
            // A value cell exists in the formal parameters.
            // Replace it.
            this.bindings [offset] = newCell;
            return false;
        }

        internal override bool SafeDeepSearch (out object value, object name)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (this.incrementals != null
                    && this.incrementals.TryGetValue (name, out vcell)) {
                    return vcell.SafeGetValue (out value);
                }
                else
                    return closure.Environment.SafeDeepSearch (out value, name);
            }
            return bindings [offset].SafeGetValue (out value);
        }

        internal override bool DeepSearchType (out object value, object name)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (this.incrementals != null
                    && this.incrementals.TryGetValue (name, out vcell)) {
                    return vcell.GetType (out value);
                }
                else
                    return closure.Environment.DeepSearchType (out value, name);
            }
            return bindings [offset].GetType (out value);
        }

        internal override bool IsUnreferenceable (object name)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (incrementals != null
                    && incrementals.TryGetValue (name, out vcell))
                    return vcell.Unreferenceable ();
                else
                    return this.closure.Environment.IsUnreferenceable (name);
            }
            return bindings [offset].Unreferenceable ();
        }


        internal override bool IsUnbound (object name)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (incrementals != null
                    && incrementals.TryGetValue (name, out vcell))
                    return vcell.Unbound ();
                else
                    return this.closure.Environment.IsUnbound (name);
            }
            return bindings [offset].Unbound ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) return bindings [offset].GetValue (out value);
            ValueCell vcell;
            if (this.incrementals != null
                && this.incrementals.TryGetValue (name, out vcell)) {
                return vcell.GetValue (out value);
            }

            return closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            throw new NotImplementedException ();
        }

        static int cacheableFreeRefs;
        static int allFreeRefs;

        internal bool FreeRef (out object value, object name)
        {
            allFreeRefs += 1;
                ValueCell vcell;
                if (this.incrementals != null
                    && this.incrementals.TryGetValue (name, out vcell)) {
                    cacheableFreeRefs += 1;
                    return vcell.GetValue (out value);
                }
                else
                    return closure.Environment.DeepSearch (out value, name, 1);
        }

        public override object SystemVectorRef (int index)
        {
            if (index == 0)
                return this.Closure;
            else {
                object answer;
                if (this.bindings [index - 1].GetValue (out answer))
                    throw new NotImplementedException ();
                return answer;
            }
        }

        //internal override bool FastLexicalRef1 (out object value, object name, int offset)
        //{
        //    throw new NotImplementedException ();
        //}

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            int offset = this.closure.FormalOffset (name);
            if (offset == -1) {
                ValueCell vcell;
                if (incrementals != null
                    && incrementals.TryGetValue (name, out vcell)) {
                    // Ugh!  Delete the cell!
                    incrementals.Remove (name);
                    answer = Constant.sharpT;
                    return false;
                }

                else
                    return this.closure.Environment.UnbindVariable (out answer, name);
            }
            throw new NotImplementedException ("Found in bindings.");
        }

        internal override Environment PartialExtend (LambdaBase lambda)
        {
            return new PartialEnvironment (lambda.PartialClose (this));
        }
    }

    /// <summary>
    /// A StaticEnvironment prohibits sharable bindings and incremental
    /// definition, but allows assignment and redefinition.
    /// </summary>
    [Serializable]
    sealed class StaticEnvironment : LexicalEnvironment
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object [] bindings;

        internal StaticEnvironment (ClosureBase closure)
            : base (closure)
        {
#if DEBUG
            extendedBy [0] += 1;
            // sanity check.
            object [] formals = closure.Lambda.Formals;
            if (formals.Length != 0)
                throw new NotImplementedException ();
#endif
        }

        internal StaticEnvironment (ClosureBase closure, object [] initialValues)
            : base (closure)
        {
            this.bindings = initialValues;
#if DEBUG
            extendedBy [initialValues.Length] += 1;
            // sanity check
            if (closure.Lambda.Formals.Length != initialValues.Length)
                throw new NotImplementedException ();
#endif
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        public override object ArgumentValue (int offset)
        {
            object answer = bindings [offset];
            if (answer is ReferenceTrap) throw new NotImplementedException ();
            return answer;
        }

        public override object Argument0Value
        {
            get
            {
                object answer = bindings [0];
                if (answer is ReferenceTrap) throw new NotImplementedException ();
                return answer;
            }
        }

        public override object Argument1Value
        {
            get
            {
                object answer = bindings [1];
                if (answer is ReferenceTrap) throw new NotImplementedException ();
                return answer;
            }
        }

        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1)
                return closure.Environment.Assign (out oldValue, varname, newValue);
            object temp = bindings [offset];
            bindings [offset] = (newValue == Constant.ExternalUnassigned)
                ? ReferenceTrap.Unassigned
                : newValue;
            oldValue = (temp == ReferenceTrap.Unassigned) ? Constant.ExternalUnassigned : temp;
            return false;
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    object temp = bindings [offset];
        //    bindings [offset] = (newValue == Constant.ExternalUnassigned)
        //        ? ReferenceTrap.Unassigned
        //        : newValue;
        //    oldValue = (temp == ReferenceTrap.Unassigned) ? Constant.ExternalUnassigned : temp;
        //    return false; 
        //}

        public override bool Define (object varname, object value)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1)
                throw new NotImplementedException ("Incremental define not supported in static environment.");
            bindings [offset] = (value == Constant.ExternalUnassigned)
                ? ReferenceTrap.Unassigned
                : value;
            return false;
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return DeepSearch (out value, varname, 0);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            if (Configuration.EnableLexicalAddressing)
                throw new NotImplementedException ("Deep search should not be necessary");
            else {
                int offset = this.closure.FormalOffset (varname);
                if (offset == -1)
                    return this.closure.Environment.DeepSearch (out value, varname, depth + 1);
                else {
                    value = bindings [offset];
                    return false;
                }
            }
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

        internal override TRet LocateVariable<TRet> (object name,
            Func<ValueCell, TRet> ifExistingGlobal, 
            Func<GlobalEnvironment, TRet> ifFutureGlobal,
            Func<int, TRet> ifNArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) {
                value = bindings [offset];
                return false;
            }

            return this.closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }
        
        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }
    }

    /// <summary>
    /// A SimpleEnvironment prohibits sharable bindings and incremental
    /// definition, assignment, and redefinition.
    /// </summary>

    [Serializable]
    sealed class SimpleEnvironment : LexicalEnvironment
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        readonly object [] bindings;
        
        internal SimpleEnvironment (ClosureBase closure)
            : base (closure)
        {
#if DEBUG
            extendedBy [0] += 1;
            // sanity check.
            object [] formals = closure.Lambda.Formals;
            if (formals.Length != 0)
                throw new NotImplementedException ();
#endif
        }

        internal SimpleEnvironment (ClosureBase closure, object [] initialValues)
            : base (closure)
        {
            this.bindings = initialValues;
#if DEBUG
            extendedBy [initialValues.Length] += 1;
            // sanity check
            if (closure.Lambda.Formals.Length != initialValues.Length)
                throw new NotImplementedException ();
#endif
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        public override object ArgumentValue (int offset)
        {
            return this.bindings [offset];
        }

        public override object Argument0Value
        {
            get
            {
                return this.bindings [0];
            }
        }

        public override object Argument1Value
        {
            get
            {
                return this.bindings [1];
            }
        }

        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1)
                return closure.Environment.Assign (out oldValue, varname, newValue);
            throw new NotImplementedException ();
        }

        public override bool Define (object varname, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return DeepSearch (out value, varname, 0);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1)
                return this.closure.Environment.DeepSearch (out value, varname, depth + 1);
            value = this.bindings [offset];
            return value is ReferenceTrap;
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

                internal override TRet LocateVariable<TRet> (object name,
            Func<ValueCell, TRet> ifGlobal, 
                    Func<GlobalEnvironment, TRet> ifFutureGlobal,
                    Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) {
                value = this.bindings [offset];
                return value is ReferenceTrap;
            }
            else
                return this.closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }
    }

    [Serializable]
    sealed class SmallEnvironment0 : LexicalEnvironment
    {
        internal SmallEnvironment0 (ClosureBase closure)
            : base (closure)
        {
        }

        public override object ArgumentValue (int offset)
        {
             throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        public override object Argument1Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            return closure.Environment.Assign (out oldValue, varname, newValue);
        }

        public override bool Define (object varname, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return closure.Environment.DeepSearch (out value, varname, 1);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            return closure.Environment.DeepSearch (out value, varname, depth + 1);
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) {
                throw new NotImplementedException ();
            }
            return this.Closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }


    /// <summary>
    /// A SmallEnvironment needs no value cells because
    /// the bindings are never mutated.
    /// </summary>
    [Serializable]
    sealed class SmallEnvironment1 : LexicalEnvironment
    {
        readonly object value0;

        internal SmallEnvironment1 (ClosureBase closure, object value0)
            : base (closure)
        {
#if DEBUG
            if (value0 is ReferenceTrap) throw new NotImplementedException ();
#endif
            this.value0 = value0;
        }

        internal SmallEnvironment1 (ClosureBase closure, Lambda value0)
            : base (closure)
        {
            this.value0 = value0.Close (this);
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        public override object ArgumentValue (int offset)
        {
            if (offset == 0) return this.value0;
            else throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get
            {
                return this.value0;
            }
        }

        public override object Argument1Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.Assign (out oldValue, varname, newValue);
            }
            throw new NotImplementedException ();
        }

        public override bool Define (object varname, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return DeepSearch (out value, varname, 0);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.DeepSearch (out value, varname, depth + 1);
            }
#if DEBUG
            foundAtDepth [depth] += 1;
#endif
            value = value0;
            return false;
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) {
                if (offset == 0) {
                    value = value0;
                    return false;
                }
                else
                    throw new NotImplementedException ();
            }
            return this.Closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }

    [Serializable]
    sealed class SmallEnvironment2 : LexicalEnvironment
    {
        readonly object value0;
        readonly object value1;

        internal SmallEnvironment2 (ClosureBase closure, object value0, object value1)
            : base (closure)
        {
#if DEBUG
            if (value0 is ReferenceTrap) throw new NotImplementedException ();
            if (value1 is ReferenceTrap) throw new NotImplementedException ();
#endif
            this.value0 = value0;
            this.value1 = value1;
        }

        public override object ArgumentValue (int offset)
        {
            if (offset == 1) return this.value1;
            else return this.value0;
        }

        public override object Argument0Value
        {
            get
            {
                return this.value0;
            }
        }

        public override object Argument1Value
        {
            get
            {
                return this.value1;
            }
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }

        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.Assign (out oldValue, varname, newValue);
            }
            throw new NotImplementedException ();
        }

        public override bool Define (object varname, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return DeepSearch (out value, varname, 0);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.DeepSearch (out value, varname, depth + 1);
            }
#if DEBUG
            foundAtDepth [depth] += 1;
#endif
            value = (offset == 1) ? value1 : value0;
            return false;
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) {
                if (offset == 0) {
                    value = value0;
                    return false;
                }
                else if (offset == 1) {
                    value = value1;
                    return false;
                }
                else
                    throw new NotImplementedException ();
            }
            else
                return this.Closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }

    [Serializable]
    sealed class SmallEnvironment3 : LexicalEnvironment
    {
        readonly object value0;
        readonly object value1;
        readonly object value2;

        internal SmallEnvironment3 (ClosureBase closure, object value0, object value1, object value2)
            : base (closure)
        {
#if DEBUG
            if (value0 is ReferenceTrap) throw new NotImplementedException ();
            if (value1 is ReferenceTrap) throw new NotImplementedException ();
            if (value2 is ReferenceTrap) throw new NotImplementedException ();
#endif
            this.value0 = value0;
            this.value1 = value1;
            this.value2 = value2;
        }

        public override object ArgumentValue (int offset)
        {
            switch (offset) {
                case 0: return this.value0;
                case 1: return this.value1;
                case 2: return this.value2;
                default:
                    throw new NotImplementedException ();
            }
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        public override object Argument0Value
        {
            get
            {
                return this.value0;
            }
        }

        public override object Argument1Value
        {
            get
            {
                return this.value1;
            }
        }

        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.Assign (out oldValue, varname, newValue);
            }
            throw new NotImplementedException ();
        }

        public override bool Define (object varname, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return DeepSearch (out value, varname, 0);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.DeepSearch (out value, varname, depth + 1);
            }
#if DEBUG
            foundAtDepth [depth] += 1;
#endif
            value = (offset == 0) ? value0 :
                    (offset == 1) ? value1 : value2;
            return false;
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip + 1, depth - 1);
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value,  object name, int depth, int offset)
        {
            if (depth == 0) {
                value = ArgumentValue (offset);
                return false;
            }
            else
                return this.closure.Environment.LexicalRef (out value, name, depth - 1, offset);
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }

    [Serializable]
    sealed class SmallEnvironment4 : LexicalEnvironment
    {
        readonly object value0;
        readonly object value1;
        readonly object value2;
        readonly object value3;

        internal SmallEnvironment4 (ClosureBase closure, object value0, object value1, object value2, object value3)
            : base (closure)
        {
#if DEBUG
            if (value0 is ReferenceTrap) throw new NotImplementedException ();
            if (value1 is ReferenceTrap) throw new NotImplementedException ();
            if (value2 is ReferenceTrap) throw new NotImplementedException ();
            if (value3 is ReferenceTrap) throw new NotImplementedException ();
#endif
            this.value0 = value0;
            this.value1 = value1;
            this.value2 = value2;
            this.value3 = value3;
        }

        public override object ArgumentValue (int offset)
        {
#if DEBUG
            SCode.location = "SmallEnvironment4.ArgumentValue";
#endif
            switch (offset) {
                case 0: return this.value0;
                case 1: return this.value1;
                case 2: return this.value2;
                case 3: return this.value3;
                default:
                    throw new NotImplementedException ();
            }
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        public override object Argument0Value
        {
            get
            {
                return this.value0;
            }
        }

        public override object Argument1Value
        {
            get
            {
                return this.value1;
            }
        }

        public override bool Assign (out object oldValue, object varname, object newValue)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.Assign (out oldValue, varname, newValue);
            }
            throw new NotImplementedException ();
        }

        public override bool Define (object varname, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object varname)
        {
            return DeepSearch (out value, varname, 0);
        }

        internal override bool DeepSearch (out object value, object varname, uint depth)
        {
            int offset = this.closure.FormalOffset (varname);
            if (offset == -1) {
                return closure.Environment.DeepSearch (out value, varname, depth + 1);
            }
#if DEBUG
            foundAtDepth [depth] += 1;
#endif
            value = (offset == 0) ? value0 :
                (offset == 1) ? value1 :
                (offset == 2) ? value2 : value3;
            return false;
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            return closure.Environment.DeepSearchSkip (out value, name, skip - 1, 1);
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            return (skip == 0) ? DeepSearch (out value, name, depth) :
                closure.Environment.DeepSearchSkip (out value, name, skip - 1, depth + 1);
        }

        internal override bool DeepSearchType (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object value, object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object varname, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object varname)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            if (depth == 0) {
                value = ArgumentValue (offset);
                return false;
            }
            else
                return this.closure.Environment.LexicalRef (out value, name, depth - 1, offset);

        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            value = this.closure.Environment.ArgumentValue (offset);
            return false;
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }

     //These are magic structures that get stuffed in the
     //closureEnvironment register when unwinding the stack.  They are
     //not actually environments, but need to be of that type.
    abstract class FakeEnvironment : Environment
    {
        protected FakeEnvironment ()
            : base (null)
        { }

        public override object ArgumentValue (int offset)
        {
            throw new NotImplementedException ();
        }

        public override bool Assign (out object oldValue, object name, object newValue)
        {
            throw new NotImplementedException ();
        }

        public override bool Define (object name, object value)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearch (out object value, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearch (out object value, object name, uint depth)
        {
            throw new NotImplementedException ();
        }

        public override bool DeepSearchSkip (out object value, object name, int skip)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchSkip (out object value, object name, int skip, uint depth)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell GetValueCell (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool SetValueCell (object name, ValueCell newCell)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnreferenceable (object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool SafeDeepSearch (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool DeepSearchType (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override bool IsUnbound (object name)
        {
            throw new NotImplementedException ();
        }

        public override object Argument0Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        public override object Argument1Value
        {
            get
            {
                throw new NotImplementedException ();
            }
        }

        internal override Environment GetAncestorEnvironment (int depth)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef (out object value, object name, int depth, int offset)
        {
            throw new NotImplementedException ();
        }

        internal override bool LexicalRef1 (out object value, object name, int offset)
        {
            throw new NotImplementedException ();
        }

        //internal override bool AssignArg (out object oldValue, int offset, object newValue)
        //{
        //    throw new NotImplementedException ();
        //}

        //internal override int GetDepth ()
        //{
        //    throw new NotImplementedException ();
        //}

        internal override bool UnbindVariable (out object answer, object name)
        {
            throw new NotImplementedException ();
        }

        internal override int SearchFormals (object name)
        {
            throw new NotImplementedException ();
        }

        internal override ValueCell SearchIncrementals (object name)
        {
            throw new NotImplementedException ();
        }


        internal override Environment PartialExtend (LambdaBase lamda)
        {
            throw new NotImplementedException ();
        }

        internal override TRet LocateVariable<TRet> (object name, Func<ValueCell, TRet> ifExistingGlobal, Func<GlobalEnvironment, TRet> ifFutureGlobal, Func<int, TRet> ifArgument,
            Func<int, TRet> ifLexical1,
            Func<int, int, TRet> ifLexical)
        {
            throw new NotImplementedException ();
        }
    }

    class WithinControlPoint : FakeEnvironment
    {
        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        ControlPoint controlPoint;

        [DebuggerBrowsable (DebuggerBrowsableState.Never)]
        ClosureBase thunk;

        public WithinControlPoint (ControlPoint controlPoint, ClosureBase thunk)
        {
            this.controlPoint = controlPoint;
            this.thunk = thunk;
        }
    }

    // not really an closureEnvironment at all, but rather
    // a structure that holds the reified stack as we
    // unwind it.
    class UnwinderState : FakeEnvironment
    {
        bool isExit;
        object exitValue;

        public bool IsExit { get { return this.isExit; } }
        public object ExitValue { get { return this.exitValue; } set {this.exitValue = value; this.isExit = true;}}

        /// <summary>
        /// When we get back to the outermost loop, we either want
        /// to reload the continuation we just saved (if we were
        /// performing a call-with-current-continuation) or we want
        /// to blow away the continuation and use a new one (if we
        /// were performing a within-continuation).  If this field
        /// is empty, we use the saved continuation, otherwise we
        /// use this one.
        /// </summary>
        ControlPoint newContinuation;

        /// <summary>
        /// A list of frames that have not yet been fully assembled
        /// into the continuation.  Each frame has saved its own state.
        /// </summary>
        ContinuationFrameList newFrames;

        /// <summary>
        /// A list of frames that already have been assembled into the continuation.
        /// When unloading the stack, we need not unload these frames.
        /// </summary>
        ContinuationFrameList oldFrames;

        Control receiver;

        /// <summary>
        /// Constructor that takes a new continuation to be installed.
        /// Stack is destroyed as we unwind and we reload the new one.
        /// </summary>
        /// <param ratorName="newContinuation"></param>
        /// <param ratorName="receiver"></param>
        internal UnwinderState (ControlPoint newContinuation, Control receiver)
        {
            this.newContinuation = newContinuation;
            this.receiver = receiver;
        }

        /// <summary>
        /// Constructor that does not take a new continuation to be
        /// installed.  Stack is reloaded with the continuation that
        /// has been read.
        /// </summary>
        /// <param ratorName="receiver"></param>
        internal UnwinderState (Control receiver)
        {
            this.receiver = receiver;
        }

        internal ControlPoint NewContinuation
        {
            get
            {
                return this.newContinuation;
            }
        }

        internal Control Receiver
        {
            get
            {
                return this.receiver;
            }
        }

        /// <summary>
        /// Push a newly created heap frame onto the list of frames that need
        /// to be assembled into the continuation.  This should be done in the
        /// handler that protects the initial subroutine call.
        /// </summary>
        internal void AddFrame (ContinuationFrame extension)
        {
            // If we are moving to a new continuation, we don't need
            // the old one.  Just discard it.
            if (this.newContinuation == null) {
                this.newFrames = new ContinuationFrameList (extension, this.newFrames);
            }
        }

        /// <summary>
        /// Append the tail of the current continuation to the exception
        /// object so that the handler can assemble the new frames onto it.
        /// </summary>
        internal void AppendContinuationFrames (ContinuationFrameList oldFrames)
        {
            // if we are moving to a new continuation, discard the
            // old frames.
            if (this.newContinuation == null) {
                // only grab them if we don't know what they are
                // this makes it safe to put this in the reload
                // path without protective logic.
                if (this.oldFrames == null)
                    this.oldFrames = oldFrames;
            }
        }

        /// <summary>
        /// Create or return a control point to be loaded.
        /// </summary>
        /// <returns></returns>
        public ControlPoint ToControlPoint ()
        {
            return this.newContinuation == null
                ? new ControlPoint (newFrames, oldFrames)
                : this.newContinuation;
        }
    }

    // Not an closureEnvironment, but the state needed to restore the
    // continuation.
    class RewindState : FakeEnvironment
    {
        ContinuationFrameList reversedFrames;
        Control receiver;
        ControlPoint cp;

        internal RewindState (ControlPoint cp, Control receiver)
        {
            this.cp = cp;
            this.receiver = receiver;
            this.reversedFrames = ContinuationFrameList.reverse (cp.FrameList);
        }

        internal ControlPoint ControlPoint
        {
            get
            {
                return this.cp;
            }
        }

        internal ContinuationFrameList GetFrameList ()
        {
            return this.reversedFrames;
        }

        internal Control PopFrame ()
        {
            if (reversedFrames == null) {
                return this.receiver;
            }
            else {
                ContinuationFrame frame = reversedFrames.first;
                reversedFrames = reversedFrames.rest;
                return frame;
            }
        }

    }
}