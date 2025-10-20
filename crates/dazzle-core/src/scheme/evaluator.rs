//! Scheme evaluator (eval loop)
//!
//! Ported from OpenJade's `Interpreter.cxx` (~2,000 lines).
//!
//! ## Core Responsibilities
//!
//! 1. **Evaluate expressions** - Transform Values into results
//! 2. **Special forms** - Handle if, let, define, lambda, quote, etc.
//! 3. **Function application** - Call procedures with arguments
//! 4. **Tail call optimization** - Prevent stack overflow in recursive functions
//!
//! ## OpenJade Correspondence
//!
//! | Dazzle          | OpenJade                  | Purpose                    |
//! |-----------------|---------------------------|----------------------------|
//! | `Evaluator`     | `Interpreter`             | Main evaluator state       |
//! | `eval()`        | `Interpreter::eval()`     | Core eval loop             |
//! | `apply()`       | `Interpreter::apply()`    | Function application       |
//! | `eval_special()`| `Interpreter::evalXXX()`  | Special form handlers      |
//!
//! ## Evaluation Rules (R4RS)
//!
//! - **Self-evaluating**: Numbers, strings, booleans, characters → return as-is
//! - **Symbols**: Look up in environment
//! - **Lists**: First element determines behavior:
//!   - Special form keyword → handle specially
//!   - Otherwise → evaluate all elements, apply first to rest

use crate::scheme::environment::Environment;
use crate::scheme::value::{Procedure, Value};
use crate::grove::{Grove, Node};
use crate::fot::FotBuilder;
use gc::Gc;
use std::rc::Rc;
use std::cell::RefCell;

// Thread-local evaluator context for primitives
//
// Similar to OpenJade's approach, we use thread-local storage to give
// primitives access to the evaluator state (current node, grove, etc.)
// without changing all primitive signatures.
//
// This is safe because:
// 1. Scheme evaluation is single-threaded in our implementation
// 2. The context is set/cleared around each eval call
// 3. Primitives only run during evaluation
thread_local! {
    static EVALUATOR_CONTEXT: RefCell<Option<EvaluatorContext>> = RefCell::new(None);
}

/// Context available to primitives during evaluation
#[derive(Clone)]
pub struct EvaluatorContext {
    pub grove: Option<Rc<dyn Grove>>,
    pub current_node: Option<Rc<Box<dyn Node>>>,
    pub backend: Option<Rc<RefCell<dyn FotBuilder>>>,
}

/// Get the current evaluator context (for use in primitives)
pub fn get_evaluator_context() -> Option<EvaluatorContext> {
    EVALUATOR_CONTEXT.with(|ctx| ctx.borrow().clone())
}

/// Set the evaluator context (called by evaluator before eval)
fn set_evaluator_context(ctx: EvaluatorContext) {
    EVALUATOR_CONTEXT.with(|c| *c.borrow_mut() = Some(ctx));
}

/// Clear the evaluator context (called by evaluator after eval)
fn clear_evaluator_context() {
    EVALUATOR_CONTEXT.with(|c| *c.borrow_mut() = None);
}

// =============================================================================
// Evaluation Error
// =============================================================================

/// Evaluation error
#[derive(Debug, Clone)]
pub struct EvalError {
    pub message: String,
}

impl EvalError {
    pub fn new(message: String) -> Self {
        EvalError { message }
    }
}

impl std::fmt::Display for EvalError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Eval error: {}", self.message)
    }
}

impl std::error::Error for EvalError {}

pub type EvalResult = Result<Value, EvalError>;

// =============================================================================
// DSSSL Processing Mode (OpenJade ProcessingMode.h/ProcessingMode.cxx)
// =============================================================================

/// Construction rule for DSSSL processing
///
/// Corresponds to OpenJade's `ElementRule` + `Rule` + `Action`.
/// Stores the pattern (element name) and action (expression to evaluate).
#[derive(Clone)]
pub struct ConstructionRule {
    /// Element name pattern (GI)
    pub element_name: String,

    /// Construction expression (returns sosofo when evaluated)
    pub expr: Value,
}

/// Processing mode containing construction rules
///
/// Corresponds to OpenJade's `ProcessingMode` class.
/// Stores all element construction rules defined in the template.
pub struct ProcessingMode {
    /// Construction rules indexed by element name
    /// In OpenJade, rules are stored in intrusive linked lists and indexed lazily.
    /// We use a simple Vec for now - can optimize later with HashMap if needed.
    pub rules: Vec<ConstructionRule>,
}

impl ProcessingMode {
    /// Create a new empty processing mode
    pub fn new() -> Self {
        ProcessingMode {
            rules: Vec::new(),
        }
    }

    /// Add a construction rule
    pub fn add_rule(&mut self, element_name: String, expr: Value) {
        self.rules.push(ConstructionRule { element_name, expr });
    }

    /// Find matching rule for an element
    ///
    /// Corresponds to OpenJade's `ProcessingMode::findMatch()`.
    /// Returns the first rule matching the given element name.
    pub fn find_match(&self, gi: &str) -> Option<&ConstructionRule> {
        self.rules.iter().find(|rule| rule.element_name == gi)
    }
}

// =============================================================================
// Evaluator
// =============================================================================

/// Scheme evaluator
///
/// Corresponds to OpenJade's `Interpreter` class.
///
/// ## Usage
///
/// ```ignore
/// let mut evaluator = Evaluator::new();
/// let result = evaluator.eval(expr, env)?;
/// ```
pub struct Evaluator {
    /// The document grove (for element-with-id, etc.)
    grove: Option<Rc<dyn Grove>>,

    /// Current node context (for current-node primitive)
    ///
    /// This changes dynamically as we process the document tree.
    /// When evaluating a template, this starts as the root node.
    /// When processing children, it changes to each child node.
    current_node: Option<Rc<Box<dyn Node>>>,

    /// Processing mode containing construction rules
    ///
    /// Corresponds to OpenJade's `Interpreter::initialProcessingMode_`.
    /// Rules are stored here during template loading, then used during processing.
    processing_mode: ProcessingMode,

    /// Backend for output generation (FotBuilder)
    ///
    /// This is used by the `make` special form to write flow objects to output.
    /// Wrapped in Rc<RefCell<>> to allow shared mutable access.
    backend: Option<Rc<RefCell<dyn FotBuilder>>>,
}

impl Evaluator {
    /// Create a new evaluator without a grove
    pub fn new() -> Self {
        Evaluator {
            grove: None,
            current_node: None,
            processing_mode: ProcessingMode::new(),
            backend: None,
        }
    }

    /// Create a new evaluator with a grove
    pub fn with_grove(grove: Rc<dyn Grove>) -> Self {
        Evaluator {
            grove: Some(grove),
            current_node: None,
            processing_mode: ProcessingMode::new(),
            backend: None,
        }
    }

    /// Set the backend
    pub fn set_backend(&mut self, backend: Rc<RefCell<dyn FotBuilder>>) {
        self.backend = Some(backend);
    }

    /// Set the grove
    pub fn set_grove(&mut self, grove: Rc<dyn Grove>) {
        self.grove = Some(grove);
    }

    /// Get the grove
    pub fn grove(&self) -> Option<&Rc<dyn Grove>> {
        self.grove.as_ref()
    }

    /// Set the current node
    pub fn set_current_node(&mut self, node: Box<dyn Node>) {
        self.current_node = Some(Rc::new(node));
    }

    /// Get the current node
    pub fn current_node(&self) -> Option<Rc<Box<dyn Node>>> {
        self.current_node.clone()
    }

    /// Clear the current node
    pub fn clear_current_node(&mut self) {
        self.current_node = None;
    }

    // =========================================================================
    // DSSSL Processing (OpenJade ProcessContext.cxx)
    // =========================================================================

    /// Start DSSSL processing from the root node
    ///
    /// Corresponds to OpenJade's `ProcessContext::process()`.
    /// After template loading, this triggers automatic tree processing.
    pub fn process_root(&mut self, env: Gc<Environment>) -> EvalResult {
        // Get the root node from the grove
        let root_node = match &self.grove {
            Some(grove) => grove.root(),
            None => return Err(EvalError::new("No grove set".to_string())),
        };

        // Set as current node and start processing
        self.current_node = Some(Rc::new(root_node));
        self.process_node(env)
    }

    /// Process the current node
    ///
    /// Corresponds to OpenJade's `ProcessContext::processNode()`.
    ///
    /// ## Algorithm (from OpenJade):
    /// 1. If character data node, output directly
    /// 2. If element node:
    ///    a. Find matching construction rule by GI
    ///    b. If rule found, evaluate it (returns sosofo)
    ///    c. If no rule, default behavior: process-children
    pub fn process_node(&mut self, env: Gc<Environment>) -> EvalResult {
        let node = match &self.current_node {
            Some(n) => n.clone(),
            None => return Err(EvalError::new("No current node".to_string())),
        };

        // Get element name (GI)
        let gi = match node.gi() {
            Some(gi) => gi,
            None => {
                // Not an element (e.g., text node, comment, etc.)
                // For code generation, we typically ignore non-elements
                return Ok(Value::Unspecified);
            }
        };

        // Find matching construction rule
        let rule = self.processing_mode.find_match(&gi);

        if let Some(rule) = rule {
            // Rule found - evaluate the construction expression
            // The expression should return a sosofo (in practice, it evaluates to a string or calls primitives)
            self.eval(rule.expr.clone(), env)
        } else {
            // No rule found - default behavior is to process children
            // This is implemented by the process-children primitive
            // For now, return Unspecified (template should call process-children explicitly)
            Ok(Value::Unspecified)
        }
    }

    /// Evaluate an expression in an environment
    ///
    /// Corresponds to OpenJade's `Interpreter::eval()`.
    ///
    /// ## Evaluation Rules
    ///
    /// 1. **Self-evaluating**: Numbers, strings, bools, chars → return as-is
    /// 2. **Symbols**: Variable lookup in environment
    /// 3. **Lists**: Check first element for special forms, otherwise apply
    pub fn eval(&mut self, expr: Value, env: Gc<Environment>) -> EvalResult {
        // Set evaluator context for primitives
        set_evaluator_context(EvaluatorContext {
            grove: self.grove.clone(),
            current_node: self.current_node.clone(),
            backend: self.backend.clone(),
        });

        // Evaluate (and ensure context is cleared on return or error)
        let result = self.eval_inner(expr, env);

        // Clear context (important for nested evals)
        clear_evaluator_context();

        result
    }

    /// Inner eval implementation (separated to ensure context cleanup)
    fn eval_inner(&mut self, expr: Value, env: Gc<Environment>) -> EvalResult {
        match expr {
            // Self-evaluating literals
            Value::Nil => Ok(Value::Nil),
            Value::Bool(_) => Ok(expr),
            Value::Integer(_) => Ok(expr),
            Value::Real(_) => Ok(expr),
            Value::Char(_) => Ok(expr),
            Value::String(_) => Ok(expr),
            Value::Procedure(_) => Ok(expr),
            Value::Vector(_) => Ok(expr), // Vectors are self-evaluating in R4RS
            Value::Unspecified => Ok(expr),
            Value::Error => Ok(expr),

            // DSSSL types (self-evaluating for now)
            Value::Node(_) => Ok(expr),
            Value::NodeList(_) => Ok(expr),
            Value::Sosofo => Ok(expr),

            // Symbols: variable lookup
            Value::Symbol(ref name) => env
                .lookup(name)
                .ok_or_else(|| EvalError::new(format!("Undefined variable: {}", name))),

            // Keywords are self-evaluating
            Value::Keyword(_) => Ok(expr),

            // Lists: special forms or function application
            Value::Pair(_) => self.eval_list(expr, env),
        }
    }

    /// Evaluate a list (special form or function call)
    fn eval_list(&mut self, expr: Value, env: Gc<Environment>) -> EvalResult {
        // Extract the operator (first element)
        let (operator, args) = self.list_car_cdr(&expr)?;

        // Check if operator is a symbol (special form keyword)
        if let Value::Symbol(ref sym) = operator {
            match &**sym {
                "quote" => self.eval_quote(args),
                "if" => self.eval_if(args, env),
                "define" => self.eval_define(args, env),
                "set!" => self.eval_set(args, env),
                "lambda" => self.eval_lambda(args, env),
                "let" => self.eval_let(args, env),
                "let*" => self.eval_let_star(args, env),
                "letrec" => self.eval_letrec(args, env),
                "begin" => self.eval_begin(args, env),
                "cond" => self.eval_cond(args, env),
                "case" => self.eval_case(args, env),
                "and" => self.eval_and(args, env),
                "or" => self.eval_or(args, env),
                "apply" => self.eval_apply(args, env),
                "map" => self.eval_map(args, env),
                "for-each" => self.eval_for_each(args, env),
                "node-list-filter" => self.eval_node_list_filter(args, env),
                "load" => self.eval_load(args, env),

                // DSSSL special forms
                "define-language" => self.eval_define_language(args, env),
                "declare-flow-object-class" => self.eval_declare_flow_object_class(args, env),
                "declare-characteristic" => self.eval_declare_characteristic(args, env),
                "element" => self.eval_element(args, env),
                "process-children" => self.eval_process_children(env),
                "make" => self.eval_make(args, env),

                // Not a special form - evaluate as function call
                _ => self.eval_application(operator, args, env),
            }
        } else {
            // Operator is not a symbol - evaluate and apply
            self.eval_application(operator, args, env)
        }
    }

    /// Extract car and cdr from a list
    fn list_car_cdr(&self, list: &Value) -> Result<(Value, Value), EvalError> {
        if let Value::Pair(ref p) = list {
            let pair = p.borrow();
            Ok((pair.car.clone(), pair.cdr.clone()))
        } else {
            Err(EvalError::new("Expected list".to_string()))
        }
    }

    /// Convert a Vec to a list
    fn vec_to_list(&self, vec: Vec<Value>) -> Value {
        let mut result = Value::Nil;
        for val in vec.iter().rev() {
            result = Value::cons(val.clone(), result);
        }
        result
    }

    /// Convert a list to a Vec of elements
    fn list_to_vec(&self, list: Value) -> Result<Vec<Value>, EvalError> {
        let mut result = Vec::new();
        let mut current = list;

        loop {
            match current {
                Value::Nil => break,
                Value::Pair(ref p) => {
                    let pair = p.borrow();
                    result.push(pair.car.clone());
                    let cdr = pair.cdr.clone();
                    drop(pair); // Explicitly drop borrow before reassigning
                    current = cdr;
                }
                _ => return Err(EvalError::new("Improper list".to_string())),
            }
        }

        Ok(result)
    }

    // =========================================================================
    // Special Forms
    // =========================================================================

    /// (quote expr) → expr
    fn eval_quote(&mut self, args: Value) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() != 1 {
            return Err(EvalError::new("quote requires exactly 1 argument".to_string()));
        }
        Ok(args_vec[0].clone())
    }

    /// (if test consequent [alternate])
    fn eval_if(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 || args_vec.len() > 3 {
            return Err(EvalError::new(
                "if requires 2 or 3 arguments".to_string(),
            ));
        }

        let test = self.eval_inner(args_vec[0].clone(), env.clone())?;

        if test.is_true() {
            self.eval_inner(args_vec[1].clone(), env)
        } else if args_vec.len() == 3 {
            self.eval_inner(args_vec[2].clone(), env)
        } else {
            Ok(Value::Unspecified)
        }
    }

    /// (define name value) or (define (name params...) body...)
    fn eval_define(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "define requires at least 2 arguments".to_string(),
            ));
        }

        // Check if first arg is a symbol or a list
        match &args_vec[0] {
            Value::Symbol(ref name) => {
                // Simple variable definition: (define x value)
                if args_vec.len() != 2 {
                    return Err(EvalError::new(
                        "define with symbol requires exactly 2 arguments".to_string(),
                    ));
                }
                let value = self.eval_inner(args_vec[1].clone(), env.clone())?;
                env.define(name, value);
                Ok(Value::Unspecified)
            }

            Value::Pair(_) => {
                // Function definition: (define (name params...) body...)
                // This is syntactic sugar for: (define name (lambda (params...) body...))
                let (name_val, params) = self.list_car_cdr(&args_vec[0])?;

                if let Value::Symbol(ref name) = name_val {
                    // Build lambda: (lambda params body...)
                    let lambda_body = args_vec[1..].to_vec();
                    let mut body_list = Value::Nil;
                    for expr in lambda_body.into_iter().rev() {
                        body_list = Value::cons(expr, body_list);
                    }
                    let lambda_expr = Value::cons(
                        Value::symbol("lambda"),
                        Value::cons(params, body_list),
                    );

                    let lambda_value = self.eval_inner(lambda_expr, env.clone())?;
                    env.define(name, lambda_value);
                    Ok(Value::Unspecified)
                } else {
                    Err(EvalError::new(
                        "First element of define must be a symbol".to_string(),
                    ))
                }
            }

            _ => Err(EvalError::new(
                "First argument to define must be symbol or list".to_string(),
            )),
        }
    }

    /// Evaluate (define-language name props...)
    /// DSSSL language definition - defines the language name as a symbol
    fn eval_define_language(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        if args_vec.is_empty() {
            return Err(EvalError::new(
                "define-language requires at least 1 argument".to_string(),
            ));
        }

        // First argument must be a symbol (language name)
        if let Value::Symbol(ref name) = args_vec[0] {
            // Define the language name as a symbol bound to itself
            // This allows it to be used in (declare-default-language name)
            env.define(name, args_vec[0].clone());
            Ok(Value::Unspecified)
        } else {
            Err(EvalError::new(
                "First argument to define-language must be a symbol".to_string(),
            ))
        }
    }

    /// Evaluate (declare-flow-object-class name public-id)
    /// DSSSL flow object class declaration - defines the class name as a symbol
    fn eval_declare_flow_object_class(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        if args_vec.is_empty() {
            return Err(EvalError::new(
                "declare-flow-object-class requires at least 1 argument".to_string(),
            ));
        }

        // First argument must be a symbol (flow object class name)
        if let Value::Symbol(ref name) = args_vec[0] {
            // Define the class name as a symbol bound to itself
            // This allows it to be used in (make name ...) constructs
            env.define(name, args_vec[0].clone());
            Ok(Value::Unspecified)
        } else {
            Err(EvalError::new(
                "First argument to declare-flow-object-class must be a symbol".to_string(),
            ))
        }
    }

    /// Evaluate (declare-characteristic name public-id default-value)
    /// DSSSL characteristic declaration - defines the characteristic with its default value
    fn eval_declare_characteristic(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        if args_vec.len() < 3 {
            return Err(EvalError::new(
                "declare-characteristic requires at least 3 arguments (name, public-id, default-value)".to_string(),
            ));
        }

        // First argument must be a symbol (characteristic name)
        if let Value::Symbol(ref name) = args_vec[0] {
            // Third argument is the default value - evaluate it
            let default_value = self.eval(args_vec[2].clone(), env.clone())?;

            // Define the characteristic name as a variable with its default value
            env.define(name, default_value);
            Ok(Value::Unspecified)
        } else {
            Err(EvalError::new(
                "First argument to declare-characteristic must be a symbol".to_string(),
            ))
        }
    }

    /// DSSSL element construction rule (OpenJade SchemeParser::doElement)
    /// Syntax: (element element-name construction-expression)
    ///
    /// Stores the rule in processing mode WITHOUT evaluating the body.
    /// The body will be evaluated later during tree processing when a matching element is found.
    fn eval_element(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "element requires at least 2 arguments (element-name and construction-expression)".to_string(),
            ));
        }

        // First argument is the element name (symbol)
        let element_name = if let Value::Symbol(ref name) = args_vec[0] {
            name.clone()
        } else {
            return Err(EvalError::new(
                "First argument to element must be a symbol".to_string(),
            ));
        };

        // Second argument is the construction expression (NOT evaluated yet!)
        // Store it for later evaluation during processing
        self.processing_mode.add_rule(element_name.to_string(), args_vec[1].clone());

        Ok(Value::Unspecified)
    }

    /// DSSSL process-children (OpenJade ProcessContext::processChildren)
    /// Syntax: (process-children)
    ///
    /// Processes all children of the current node.
    /// For each child, matches construction rules and evaluates them.
    fn eval_process_children(&mut self, env: Gc<Environment>) -> EvalResult {
        // Get current node
        let current_node = match &self.current_node {
            Some(node) => node.clone(),
            None => return Err(EvalError::new("No current node".to_string())),
        };

        // Get children
        let mut children = current_node.children();

        // Process each child (using DSSSL node-list iteration pattern)
        let mut result = Value::Unspecified;
        while !children.is_empty() {
            // Get first child
            if let Some(child_node) = children.first() {
                // Save current node
                let saved_node = self.current_node.clone();

                // Set child as current node
                self.current_node = Some(Rc::new(child_node));

                // Process the child node
                result = self.process_node(env.clone())?;

                // Restore current node
                self.current_node = saved_node;
            }

            // Move to rest of children
            children = children.rest();
        }

        Ok(result)
    }

    /// DSSSL make flow object (OpenJade FotBuilder)
    /// Syntax: (make flow-object-type keyword: value ... body-sosofo)
    ///
    /// Creates flow objects and writes them to the backend.
    /// Supports: entity, formatting-instruction
    fn eval_make(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        if args_vec.is_empty() {
            return Err(EvalError::new(
                "make requires at least a flow object type".to_string(),
            ));
        }

        // First argument is the flow object type (symbol)
        let fo_type = match &args_vec[0] {
            Value::Symbol(s) => s.as_ref(),
            _ => return Err(EvalError::new(
                "make: first argument must be a flow object type symbol".to_string(),
            )),
        };

        // Parse keyword arguments and body
        let mut i = 1;
        let mut system_id = None;
        let mut data = None;

        while i < args_vec.len() {
            match &args_vec[i] {
                Value::Keyword(kw) => {
                    // Next argument is the keyword value
                    if i + 1 >= args_vec.len() {
                        return Err(EvalError::new(
                            format!("make: keyword {} requires a value", kw),
                        ));
                    }
                    let value = self.eval(args_vec[i + 1].clone(), env.clone())?;

                    match kw.as_ref() {
                        "system-id" => {
                            if let Value::String(s) = value {
                                system_id = Some(s);
                            } else {
                                return Err(EvalError::new(
                                    "make: system-id must be a string".to_string(),
                                ));
                            }
                        }
                        "data" => {
                            if let Value::String(s) = value {
                                data = Some(s);
                            } else {
                                return Err(EvalError::new(
                                    "make: data must be a string".to_string(),
                                ));
                            }
                        }
                        _ => {
                            // Ignore unknown keywords for now
                        }
                    }
                    i += 2;
                }
                _ => {
                    // Non-keyword argument - evaluate as body sosofo
                    // Nested make calls will append to backend buffer
                    let _result = self.eval(args_vec[i].clone(), env.clone())?;
                    i += 1;
                }
            }
        }

        // Call backend method based on flow object type
        match self.backend {
            Some(ref backend) => {
                match fo_type {
                    "entity" => {
                        if let Some(sid) = system_id {
                            // Get current buffer content and write to file
                            let content = backend.borrow().current_output().to_string();
                            backend.borrow_mut().entity(&sid, &content)
                                .map_err(|e| EvalError::new(format!("Backend error: {}", e)))?;
                            // Clear buffer after writing file
                            backend.borrow_mut().clear_buffer();
                        } else {
                            return Err(EvalError::new(
                                "make entity requires system-id: keyword".to_string(),
                            ));
                        }
                    }
                    "formatting-instruction" => {
                        if let Some(d) = data {
                            // Append to current buffer
                            backend.borrow_mut().formatting_instruction(&d)
                                .map_err(|e| EvalError::new(format!("Backend error: {}", e)))?;
                        } else {
                            return Err(EvalError::new(
                                "make formatting-instruction requires data: keyword".to_string(),
                            ));
                        }
                    }
                    "literal" => {
                        // literal is typically called as (literal "text") not (make literal ...)
                        // but we support both forms for completeness
                        if let Some(d) = data {
                            backend.borrow_mut().formatting_instruction(&d)
                                .map_err(|e| EvalError::new(format!("Backend error: {}", e)))?;
                        } else {
                            return Err(EvalError::new(
                                "make literal requires data: keyword or a string body".to_string(),
                            ));
                        }
                    }
                    _ => {
                        // Unknown flow object type - just return unspecified for now
                        return Ok(Value::Unspecified);
                    }
                }
            }
            None => {
                return Err(EvalError::new(
                    "make: no backend available".to_string(),
                ));
            }
        }

        Ok(Value::Unspecified)
    }

    /// (set! name value)
    fn eval_set(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() != 2 {
            return Err(EvalError::new(
                "set! requires exactly 2 arguments".to_string(),
            ));
        }

        if let Value::Symbol(ref name) = args_vec[0] {
            let value = self.eval(args_vec[1].clone(), env.clone())?;
            env.set(name, value)
                .map_err(|e| EvalError::new(e))?;
            Ok(Value::Unspecified)
        } else {
            Err(EvalError::new(
                "First argument to set! must be a symbol".to_string(),
            ))
        }
    }

    /// (lambda (params...) body...)
    fn eval_lambda(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "lambda requires at least 2 arguments (params and body)".to_string(),
            ));
        }

        // Extract parameter list
        let params_list = &args_vec[0];
        let params_vec = if params_list.is_nil() {
            // No parameters: (lambda () body)
            Vec::new()
        } else {
            self.list_to_vec(params_list.clone())?
        };

        // Convert parameter values to strings
        let mut param_names = Vec::new();
        for param in params_vec {
            if let Value::Symbol(ref name) = param {
                param_names.push(name.to_string());
            } else {
                return Err(EvalError::new(format!(
                    "Lambda parameter must be a symbol, got: {:?}",
                    param
                )));
            }
        }

        // Extract body (one or more expressions)
        let body = if args_vec.len() == 2 {
            // Single body expression
            args_vec[1].clone()
        } else {
            // Multiple body expressions - wrap in (begin ...)
            let mut body_list = Value::Nil;
            for expr in args_vec[1..].iter().rev() {
                body_list = Value::cons(expr.clone(), body_list);
            }
            Value::cons(Value::symbol("begin"), body_list)
        };

        // Create lambda closure capturing current environment
        Ok(Value::lambda(param_names, body, env))
    }

    /// (let ((var val)...) body...)
    fn eval_let(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "let requires at least 2 arguments".to_string(),
            ));
        }

        // Check if this is named let: (let name ((var val)...) body...)
        if let Value::Symbol(ref loop_name) = args_vec[0] {
            if args_vec.len() < 3 {
                return Err(EvalError::new(
                    "named let requires at least 3 arguments".to_string(),
                ));
            }

            // Named let: transform to (letrec ((name (lambda (vars...) body...))) (name vals...))
            let bindings_list = &args_vec[1];
            let bindings = self.list_to_vec(bindings_list.clone())?;
            let body = &args_vec[2..];

            // Extract variable names and initial values
            let mut var_names = Vec::new();
            let mut init_values = Vec::new();
            for binding in &bindings {
                let binding_vec = self.list_to_vec(binding.clone())?;
                if binding_vec.len() != 2 {
                    return Err(EvalError::new(
                        "named let binding must have exactly 2 elements".to_string(),
                    ));
                }
                var_names.push(binding_vec[0].clone());
                init_values.push(binding_vec[1].clone());
            }

            // Create lambda: (lambda (vars...) body...)
            let lambda_params = self.vec_to_list(var_names);
            let mut lambda_body = vec![Value::symbol("lambda"), lambda_params];
            lambda_body.extend_from_slice(body);
            let lambda_expr = self.vec_to_list(lambda_body);

            // Create letrec binding: ((name (lambda ...)))
            let letrec_binding = Value::cons(
                Value::symbol(loop_name),
                Value::cons(lambda_expr, Value::Nil),
            );
            let letrec_bindings = Value::cons(letrec_binding, Value::Nil);

            // Create function call: (name vals...)
            let mut call_expr = vec![Value::symbol(loop_name)];
            call_expr.extend_from_slice(&init_values);
            let call = self.vec_to_list(call_expr);

            // Evaluate: (letrec ((name (lambda ...))) (name vals...))
            return self.eval_letrec(self.vec_to_list(vec![letrec_bindings, call]), env);
        }

        // Standard let: (let ((var val)...) body...)
        let bindings_list = &args_vec[0];
        let bindings = self.list_to_vec(bindings_list.clone())?;

        // Create new environment extending current
        let new_env = Environment::extend(env.clone());

        // Evaluate bindings in OLD environment, define in NEW environment
        for binding in bindings {
            let binding_vec = self.list_to_vec(binding)?;
            if binding_vec.len() != 2 {
                return Err(EvalError::new(
                    "let binding must have exactly 2 elements".to_string(),
                ));
            }

            if let Value::Symbol(ref name) = binding_vec[0] {
                let value = self.eval_inner(binding_vec[1].clone(), env.clone())?;
                new_env.define(name, value);
            } else {
                return Err(EvalError::new(
                    "Binding variable must be a symbol".to_string(),
                ));
            }
        }

        // Evaluate body in new environment
        let body = &args_vec[1..];
        self.eval_sequence(body, new_env)
    }

    /// (let* ((var val)...) body...)
    fn eval_let_star(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "let* requires at least 2 arguments".to_string(),
            ));
        }

        // Parse bindings
        let bindings_list = &args_vec[0];
        let bindings = self.list_to_vec(bindings_list.clone())?;

        // Create new environment
        let current_env = Environment::extend(env);

        // Evaluate bindings sequentially in CURRENT environment
        for binding in bindings {
            let binding_vec = self.list_to_vec(binding)?;
            if binding_vec.len() != 2 {
                return Err(EvalError::new(
                    "let* binding must have exactly 2 elements".to_string(),
                ));
            }

            if let Value::Symbol(ref name) = binding_vec[0] {
                let value = self.eval_inner(binding_vec[1].clone(), current_env.clone())?;
                current_env.define(name, value);
            } else {
                return Err(EvalError::new(
                    "Binding variable must be a symbol".to_string(),
                ));
            }
        }

        // Evaluate body
        let body = &args_vec[1..];
        self.eval_sequence(body, current_env)
    }

    /// (letrec ((var val)...) body...)
    ///
    /// letrec allows recursive definitions - all bindings can refer to each other.
    /// Implementation:
    /// 1. Create new environment
    /// 2. Bind all variables to Unspecified first
    /// 3. Evaluate all values in the new environment
    /// 4. Update bindings with evaluated values
    /// 5. Evaluate body in the new environment
    fn eval_letrec(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "letrec requires at least 2 arguments".to_string(),
            ));
        }

        // Parse bindings
        let bindings_list = &args_vec[0];
        let bindings = self.list_to_vec(bindings_list.clone())?;

        // Create new environment extending current
        let new_env = Environment::extend(env);

        // First pass: bind all variables to Unspecified
        let mut var_names = Vec::new();
        for binding in &bindings {
            let binding_vec = self.list_to_vec(binding.clone())?;
            if binding_vec.len() != 2 {
                return Err(EvalError::new(
                    "letrec binding must have exactly 2 elements".to_string(),
                ));
            }

            if let Value::Symbol(ref name) = binding_vec[0] {
                var_names.push(name.to_string());
                new_env.define(name, Value::Unspecified);
            } else {
                return Err(EvalError::new(
                    "Binding variable must be a symbol".to_string(),
                ));
            }
        }

        // Second pass: evaluate all values in the new environment and update bindings
        for (i, binding) in bindings.iter().enumerate() {
            let binding_vec = self.list_to_vec(binding.clone())?;
            let value = self.eval_inner(binding_vec[1].clone(), new_env.clone())?;

            // Update the binding (set! will work since we already defined it)
            new_env.set(&var_names[i], value)
                .map_err(|e| EvalError::new(e))?;
        }

        // Evaluate body in new environment
        let body = &args_vec[1..];
        self.eval_sequence(body, new_env)
    }

    /// (begin expr...)
    fn eval_begin(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        self.eval_sequence(&args_vec, env)
    }

    /// (cond (test expr...)...)
    fn eval_cond(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let clauses = self.list_to_vec(args)?;

        for clause in clauses {
            let clause_vec = self.list_to_vec(clause)?;
            if clause_vec.is_empty() {
                return Err(EvalError::new("Empty cond clause".to_string()));
            }

            // Check for else clause
            if let Value::Symbol(ref sym) = clause_vec[0] {
                if &**sym == "else" {
                    return self.eval_sequence(&clause_vec[1..], env);
                }
            }

            // Evaluate test
            let test = self.eval_inner(clause_vec[0].clone(), env.clone())?;
            if test.is_true() {
                if clause_vec.len() == 1 {
                    return Ok(test);
                } else {
                    return self.eval_sequence(&clause_vec[1..], env);
                }
            }
        }

        Ok(Value::Unspecified)
    }

    /// (case key ((datum...) expr...)...)
    ///
    /// R4RS case statement:
    /// ```scheme
    /// (case expr
    ///   ((datum1 datum2 ...) result1 result2 ...)
    ///   ((datum3 datum4 ...) result3 result4 ...)
    ///   ...
    ///   [else resultN ...])
    /// ```
    ///
    /// The key expression is evaluated and compared with each datum using eqv?.
    /// The datums are NOT evaluated (they are literal constants).
    fn eval_case(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.is_empty() {
            return Err(EvalError::new("case requires at least 1 argument".to_string()));
        }

        // Evaluate the key expression
        let key = self.eval_inner(args_vec[0].clone(), env.clone())?;

        // Iterate through clauses
        for clause in &args_vec[1..] {
            let clause_vec = self.list_to_vec(clause.clone())?;
            if clause_vec.is_empty() {
                return Err(EvalError::new("Empty case clause".to_string()));
            }

            // Check for else clause
            if let Value::Symbol(ref sym) = clause_vec[0] {
                if &**sym == "else" {
                    return self.eval_sequence(&clause_vec[1..], env);
                }
            }

            // First element should be a list of datums
            let datums = self.list_to_vec(clause_vec[0].clone())?;

            // Check if key matches any datum using eqv?
            for datum in datums {
                if key.eqv(&datum) {
                    // Match found - evaluate body expressions
                    if clause_vec.len() == 1 {
                        // No expressions in clause - return unspecified
                        return Ok(Value::Unspecified);
                    } else {
                        return self.eval_sequence(&clause_vec[1..], env);
                    }
                }
            }
        }

        // No match found
        Ok(Value::Unspecified)
    }

    /// (and expr...)
    fn eval_and(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        if args_vec.is_empty() {
            return Ok(Value::bool(true));
        }

        let mut result = Value::bool(true);
        for expr in args_vec {
            result = self.eval_inner(expr, env.clone())?;
            if !result.is_true() {
                return Ok(Value::bool(false));
            }
        }

        Ok(result)
    }

    /// (or expr...)
    fn eval_or(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;

        for expr in args_vec {
            let result = self.eval_inner(expr, env.clone())?;
            if result.is_true() {
                return Ok(result);
            }
        }

        Ok(Value::bool(false))
    }

    /// Evaluate a sequence of expressions, return last result
    fn eval_sequence(&mut self, exprs: &[Value], env: Gc<Environment>) -> EvalResult {
        if exprs.is_empty() {
            return Ok(Value::Unspecified);
        }

        let mut result = Value::Unspecified;
        for expr in exprs {
            result = self.eval_inner(expr.clone(), env.clone())?;
        }

        Ok(result)
    }

    /// (apply proc args)
    ///
    /// Apply a procedure to a list of arguments.
    /// Example: (apply + '(1 2 3)) → 6
    fn eval_apply(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() != 2 {
            return Err(EvalError::new(
                "apply requires exactly 2 arguments".to_string(),
            ));
        }

        // Evaluate the procedure
        let proc = self.eval_inner(args_vec[0].clone(), env.clone())?;

        // Evaluate the argument list
        let arg_list = self.eval_inner(args_vec[1].clone(), env)?;

        // Convert argument list to vector
        let arg_values = self.list_to_vec(arg_list)?;

        // Apply the procedure
        self.apply(proc, arg_values)
    }

    /// (map proc list)
    ///
    /// Apply procedure to each element of list, return list of results.
    /// Example: (map (lambda (x) (* x 2)) '(1 2 3)) → '(2 4 6)
    /// (map proc list1 list2 ...)
    ///
    /// R4RS: Apply procedure to corresponding elements of lists.
    /// All lists must have the same length.
    /// Returns a list of results.
    ///
    /// Examples:
    /// - (map + '(1 2 3) '(4 5 6)) => (5 7 9)
    /// - (map list '(1 2) '(a b) '(x y)) => ((1 a x) (2 b y))
    fn eval_map(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new("map requires at least 2 arguments".to_string()));
        }

        // Evaluate the procedure
        let proc = self.eval_inner(args_vec[0].clone(), env.clone())?;

        // Evaluate all lists
        let mut lists = Vec::new();
        for i in 1..args_vec.len() {
            let list = self.eval_inner(args_vec[i].clone(), env.clone())?;
            let list_vec = self.list_to_vec(list)?;
            lists.push(list_vec);
        }

        // Check all lists have the same length
        if lists.is_empty() {
            return Ok(Value::Nil);
        }

        let length = lists[0].len();
        for list in &lists[1..] {
            if list.len() != length {
                return Err(EvalError::new(
                    "map: all lists must have the same length".to_string(),
                ));
            }
        }

        // Apply procedure to corresponding elements
        let mut result_vec = Vec::new();
        for i in 0..length {
            // Gather i-th element from each list
            let mut proc_args = Vec::new();
            for list in &lists {
                proc_args.push(list[i].clone());
            }

            // Apply procedure
            let result = self.apply(proc.clone(), proc_args)?;
            result_vec.push(result);
        }

        // Convert result vector back to list
        let mut result_list = Value::Nil;
        for elem in result_vec.into_iter().rev() {
            result_list = Value::cons(elem, result_list);
        }

        Ok(result_list)
    }

    /// (for-each proc list1 list2 ...)
    ///
    /// R4RS: Apply procedure to corresponding elements of lists for side effects.
    /// All lists must have the same length.
    /// Returns unspecified.
    ///
    /// Example: (for-each display '("a" "b" "c"))
    fn eval_for_each(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() < 2 {
            return Err(EvalError::new(
                "for-each requires at least 2 arguments".to_string(),
            ));
        }

        // Evaluate the procedure
        let proc = self.eval_inner(args_vec[0].clone(), env.clone())?;

        // Evaluate all lists
        let mut lists = Vec::new();
        for i in 1..args_vec.len() {
            let list = self.eval_inner(args_vec[i].clone(), env.clone())?;
            let list_vec = self.list_to_vec(list)?;
            lists.push(list_vec);
        }

        // Check all lists have the same length
        if lists.is_empty() {
            return Ok(Value::Unspecified);
        }

        let length = lists[0].len();
        for list in &lists[1..] {
            if list.len() != length {
                return Err(EvalError::new(
                    "for-each: all lists must have the same length".to_string(),
                ));
            }
        }

        // Apply procedure to corresponding elements (for side effects)
        for i in 0..length {
            // Gather i-th element from each list
            let mut proc_args = Vec::new();
            for list in &lists {
                proc_args.push(list[i].clone());
            }

            // Apply procedure for side effects
            self.apply(proc.clone(), proc_args)?;
        }

        Ok(Value::Unspecified)
    }

    /// (node-list-filter predicate node-list)
    ///
    /// Returns a node-list containing only nodes for which predicate returns #t.
    /// DSSSL: Filter a node-list based on a predicate function.
    fn eval_node_list_filter(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() != 2 {
            return Err(EvalError::new("node-list-filter requires exactly 2 arguments".to_string()));
        }

        // Evaluate the predicate
        let pred = self.eval_inner(args_vec[0].clone(), env.clone())?;

        // Evaluate the node-list
        let node_list_val = self.eval_inner(args_vec[1].clone(), env.clone())?;

        match node_list_val {
            Value::NodeList(ref nl) => {
                let mut filtered_nodes = Vec::new();

                // Iterate through the node-list
                let mut index = 0;
                loop {
                    if let Some(node) = nl.get(index) {
                        // Apply predicate to this node
                        let node_val = Value::node(node);
                        let result = self.apply(pred.clone(), vec![node_val.clone()])?;

                        // If predicate returns #t, include this node
                        if let Value::Bool(true) = result {
                            // Need to get the node again since we consumed it
                            if let Value::Node(n) = node_val {
                                filtered_nodes.push(n.as_ref().clone_node());
                            }
                        }

                        index += 1;
                    } else {
                        break;
                    }
                }

                Ok(Value::node_list(Box::new(crate::grove::VecNodeList::new(filtered_nodes))))
            }
            _ => Err(EvalError::new(format!("node-list-filter: second argument not a node-list: {:?}", node_list_val))),
        }
    }

    /// (load filename)
    ///
    /// Load and evaluate Scheme code from a file.
    /// Returns the result of the last expression in the file.
    fn eval_load(&mut self, args: Value, env: Gc<Environment>) -> EvalResult {
        let args_vec = self.list_to_vec(args)?;
        if args_vec.len() != 1 {
            return Err(EvalError::new(
                "load requires exactly 1 argument".to_string(),
            ));
        }

        // Evaluate the filename argument
        let filename_val = self.eval_inner(args_vec[0].clone(), env.clone())?;

        let filename = match filename_val {
            Value::String(s) => s.to_string(),
            _ => return Err(EvalError::new(
                format!("load: filename must be a string, got {:?}", filename_val)
            )),
        };

        // Read the file
        let contents = std::fs::read_to_string(&filename)
            .map_err(|e| EvalError::new(format!("load: cannot read file '{}': {}", filename, e)))?;

        // Parse the file contents
        let mut parser = crate::scheme::parser::Parser::new(&contents);
        let mut result = Value::Unspecified;

        // Evaluate each expression in sequence
        loop {
            match parser.parse() {
                Ok(expr) => {
                    result = self.eval_inner(expr, env.clone())?;
                }
                Err(e) => {
                    // Check if we've reached end of input (not an error)
                    let error_msg = e.to_string();
                    if error_msg.contains("Unexpected end of input")
                        || error_msg.contains("Expected")
                        || error_msg.contains("EOF") {
                        break;
                    }
                    return Err(EvalError::new(
                        format!("load: parse error in '{}': {}", filename, e)
                    ));
                }
            }
        }

        Ok(result)
    }

    // =========================================================================
    // Function Application
    // =========================================================================

    /// Apply a function to arguments
    fn eval_application(
        &mut self,
        operator: Value,
        args: Value,
        env: Gc<Environment>,
    ) -> EvalResult {
        // Evaluate operator
        let proc = self.eval_inner(operator, env.clone())?;

        // Evaluate arguments
        let args_vec = self.list_to_vec(args)?;
        let mut evaled_args = Vec::new();
        for arg in args_vec {
            evaled_args.push(self.eval_inner(arg, env.clone())?);
        }

        // Apply procedure
        self.apply(proc, evaled_args)
    }

    /// Apply a procedure to evaluated arguments
    fn apply(&mut self, proc: Value, args: Vec<Value>) -> EvalResult {
        if let Value::Procedure(ref p) = proc {
            match &**p {
                Procedure::Primitive { func, .. } => {
                    func(&args).map_err(|e| EvalError::new(e))
                }
                Procedure::Lambda { params, body, env } => {
                    // Check argument count
                    if args.len() != params.len() {
                        return Err(EvalError::new(format!(
                            "Lambda expects {} arguments, got {}",
                            params.len(),
                            args.len()
                        )));
                    }

                    // Create new environment extending the closure environment
                    let lambda_env = Environment::extend(env.clone());

                    // Bind parameters to arguments
                    for (param_name, arg_value) in params.iter().zip(args.iter()) {
                        lambda_env.define(param_name, arg_value.clone());
                    }

                    // Evaluate body in the new environment
                    self.eval_inner((**body).clone(), lambda_env)
                }
            }
        } else {
            Err(EvalError::new(format!(
                "Not a procedure: {:?}",
                proc
            )))
        }
    }
}

impl Default for Evaluator {
    fn default() -> Self {
        Self::new()
    }
}

// =============================================================================
// Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn make_env() -> Gc<Environment> {
        Environment::new_global()
    }

    #[test]
    fn test_eval_self_evaluating() {
        let mut eval = Evaluator::new();
        let env = make_env();

        assert!(eval.eval(Value::integer(42), env.clone()).unwrap().is_integer());
        assert!(eval.eval(Value::bool(true), env.clone()).unwrap().is_bool());
        assert!(eval.eval(Value::string("hello".to_string()), env).unwrap().is_string());
    }

    #[test]
    fn test_eval_quote() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (quote (1 2 3))
        let expr = Value::cons(
            Value::symbol("quote"),
            Value::cons(
                Value::cons(
                    Value::integer(1),
                    Value::cons(Value::integer(2), Value::cons(Value::integer(3), Value::Nil)),
                ),
                Value::Nil,
            ),
        );

        let result = eval.eval(expr, env).unwrap();
        assert!(result.is_list());
    }

    #[test]
    fn test_eval_if_true() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (if #t 1 2)
        let expr = Value::cons(
            Value::symbol("if"),
            Value::cons(
                Value::bool(true),
                Value::cons(Value::integer(1), Value::cons(Value::integer(2), Value::Nil)),
            ),
        );

        let result = eval.eval(expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 1);
        } else {
            panic!("Expected integer 1");
        }
    }

    #[test]
    fn test_eval_if_false() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (if #f 1 2)
        let expr = Value::cons(
            Value::symbol("if"),
            Value::cons(
                Value::bool(false),
                Value::cons(Value::integer(1), Value::cons(Value::integer(2), Value::Nil)),
            ),
        );

        let result = eval.eval(expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 2);
        } else {
            panic!("Expected integer 2");
        }
    }

    #[test]
    fn test_eval_define() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (define x 42)
        let expr = Value::cons(
            Value::symbol("define"),
            Value::cons(Value::symbol("x"), Value::cons(Value::integer(42), Value::Nil)),
        );

        eval.eval(expr, env.clone()).unwrap();

        // Check that x is defined
        assert!(env.is_defined("x"));
        if let Value::Integer(n) = env.lookup("x").unwrap() {
            assert_eq!(n, 42);
        }
    }

    #[test]
    fn test_eval_symbol_lookup() {
        let mut eval = Evaluator::new();
        let env = make_env();

        env.define("x", Value::integer(99));

        let result = eval.eval(Value::symbol("x"), env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 99);
        } else {
            panic!("Expected integer 99");
        }
    }

    #[test]
    fn test_eval_and() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (and #t #t)
        let expr = Value::cons(
            Value::symbol("and"),
            Value::cons(Value::bool(true), Value::cons(Value::bool(true), Value::Nil)),
        );

        let result = eval.eval(expr, env.clone()).unwrap();
        assert!(result.is_true());

        // (and #t #f)
        let expr = Value::cons(
            Value::symbol("and"),
            Value::cons(Value::bool(true), Value::cons(Value::bool(false), Value::Nil)),
        );

        let result = eval.eval(expr, env).unwrap();
        assert!(!result.is_true());
    }

    #[test]
    fn test_eval_or() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (or #f #t)
        let expr = Value::cons(
            Value::symbol("or"),
            Value::cons(Value::bool(false), Value::cons(Value::bool(true), Value::Nil)),
        );

        let result = eval.eval(expr, env.clone()).unwrap();
        assert!(result.is_true());

        // (or #f #f)
        let expr = Value::cons(
            Value::symbol("or"),
            Value::cons(Value::bool(false), Value::cons(Value::bool(false), Value::Nil)),
        );

        let result = eval.eval(expr, env).unwrap();
        assert!(!result.is_true());
    }

    #[test]
    fn test_eval_lambda_creation() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (lambda (x) x)
        let expr = Value::cons(
            Value::symbol("lambda"),
            Value::cons(
                Value::cons(Value::symbol("x"), Value::Nil),
                Value::cons(Value::symbol("x"), Value::Nil),
            ),
        );

        let result = eval.eval(expr, env).unwrap();
        assert!(result.is_procedure());
    }

    #[test]
    fn test_eval_lambda_application() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // ((lambda (x) x) 42)
        let lambda_expr = Value::cons(
            Value::symbol("lambda"),
            Value::cons(
                Value::cons(Value::symbol("x"), Value::Nil),
                Value::cons(Value::symbol("x"), Value::Nil),
            ),
        );

        let app_expr = Value::cons(lambda_expr, Value::cons(Value::integer(42), Value::Nil));

        let result = eval.eval(app_expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 42);
        } else {
            panic!("Expected integer 42");
        }
    }

    #[test]
    fn test_eval_lambda_multiple_params() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // ((lambda (x y) x) 1 2) - Just return first param
        let params = Value::cons(Value::symbol("x"), Value::cons(Value::symbol("y"), Value::Nil));
        let body = Value::symbol("x");

        let lambda_expr = Value::cons(Value::symbol("lambda"), Value::cons(params, Value::cons(body, Value::Nil)));

        let app_expr = Value::cons(
            lambda_expr,
            Value::cons(Value::integer(1), Value::cons(Value::integer(2), Value::Nil)),
        );

        let result = eval.eval(app_expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 1);
        } else {
            panic!("Expected integer 1");
        }
    }

    #[test]
    fn test_eval_lambda_wrong_arg_count() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // ((lambda (x) x) 1 2) - wrong argument count
        let lambda_expr = Value::cons(
            Value::symbol("lambda"),
            Value::cons(
                Value::cons(Value::symbol("x"), Value::Nil),
                Value::cons(Value::symbol("x"), Value::Nil),
            ),
        );

        let app_expr = Value::cons(
            lambda_expr,
            Value::cons(Value::integer(1), Value::cons(Value::integer(2), Value::Nil)),
        );

        let result = eval.eval(app_expr, env);
        assert!(result.is_err());
    }

    #[test]
    fn test_eval_lambda_closure() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // (define x 10)
        env.define("x", Value::integer(10));

        // ((lambda (y) x) 20)
        // Should capture x from outer environment and ignore y
        let lambda_expr = Value::cons(
            Value::symbol("lambda"),
            Value::cons(
                Value::cons(Value::symbol("y"), Value::Nil),
                Value::cons(Value::symbol("x"), Value::Nil),
            ),
        );

        let app_expr = Value::cons(lambda_expr, Value::cons(Value::integer(20), Value::Nil));

        let result = eval.eval(app_expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 10); // Should get x from outer environment
        } else {
            panic!("Expected integer 10 from closure");
        }
    }

    #[test]
    fn test_eval_lambda_no_params() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // ((lambda () 42))
        let lambda_expr = Value::cons(
            Value::symbol("lambda"),
            Value::cons(Value::Nil, Value::cons(Value::integer(42), Value::Nil)),
        );

        let app_expr = Value::cons(lambda_expr, Value::Nil);

        let result = eval.eval(app_expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 42);
        } else {
            panic!("Expected integer 42");
        }
    }

    #[test]
    fn test_eval_lambda_multiple_body_expressions() {
        let mut eval = Evaluator::new();
        let env = make_env();

        // ((lambda (x) 1 2 x) 99)
        // Should return x (last expression)
        let params = Value::cons(Value::symbol("x"), Value::Nil);
        let body1 = Value::integer(1);
        let body2 = Value::integer(2);
        let body3 = Value::symbol("x");

        let lambda_expr = Value::cons(
            Value::symbol("lambda"),
            Value::cons(
                params,
                Value::cons(body1, Value::cons(body2, Value::cons(body3, Value::Nil))),
            ),
        );

        let app_expr = Value::cons(lambda_expr, Value::cons(Value::integer(99), Value::Nil));

        let result = eval.eval(app_expr, env).unwrap();
        if let Value::Integer(n) = result {
            assert_eq!(n, 99);
        } else {
            panic!("Expected integer 99");
        }
    }
}
