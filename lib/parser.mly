%{
open Ast 
open Env 

type declarator =
| DeclPtr of declarator
| DeclIdent of string
| DeclArr of declarator * expr
| DeclFun of declarator * decl list

let make_decl ty d = 
  let name = ref "" in
  let rec aux ty = function
  | DeclPtr d -> aux (TPtr ty) d 
  | DeclIdent n -> name := n; ty 
  | DeclArr(d,sz) -> aux (TArr(ty,sz)) d 
  | DeclFun(d,dl) -> aux (TFun(ty,dl)) d
  in (!name, aux ty d)

let make_decls ty dl =
  List.map (fun d -> make_decl ty d) dl

let make_decls_with_init ty init_decl_list =
  List.map (function 
    | (d,Some init) -> push_def (VarDef(make_decl ty d,init))
    | (d,None) -> push_def (Decl (make_decl ty d))
  ) init_decl_list

let conv_ident = function
  | Some s -> s 
  | None -> ""
%}
%token LPAREN "(" RPAREN ")" LBRACKET "[" RBRACKET "]" LBRACE "{" RBRACE "}" DOT "." COMMA ","
%token AND "&" STAR "*" PLUS "+" MINUS "-" NOT "~" BANG "!" DIV "/" MOD "%" LT "<" GT ">" HAT "^" OR "|" 
%token COLON ":" QUESTION "?" SEMI ";" EQ "=" INLINE NORETURN
%token SIZEOF EOF
%token ARROW "->" INC "++" DEC "--" LSHIFT "<<" RSHIFT ">>" LE "<=" GE ">=" EQEQ "==" NE "!=" ELLIPSIS "..."
%token ANDAND "&&" OROR "||" MUL_EQ "*=" DIV_EQ "/=" MOD_EQ "%=" ADD_EQ "+="
%token SUB_EQ "-=" LSHIFT_EQ "<<=" RSHIFT_EQ ">>=" AND_EQ "&="
%token XOR_EQ "^=" OR_EQ "|="
%token TYPEDEF EXTERN STATIC AUTO REGISTER
%token TCHAR TSHORT TINT TLONG TSIGNED TUNSIGNED TFLOAT TDOUBLE CONST VOLATILE TVOID
%token STRUCT UNION ENUM 
%token CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%token <string> CHAR INT
%token <string> FLOAT
%token<string> STR
%token<string> ID TYPE_ID

%nonassoc NO_ELSE
%nonassoc ELSE 

%type<id list> translation_unit
%start translation_unit
%%

translation_unit:
| list(external_decl) EOF                     { List.flatten $1 }

ident:
| ID                                          { $1 }
| TYPE_ID                                     { $1 }


primary_expr:
| ID                                          { EVar ( lookup_var $1) }
| CHAR                                        { EConst (VInt $1) }
| INT                                         { EConst (VInt $1) }
| FLOAT                                       { EConst (VFloat $1) }
| STR                                         { EConst ( VStr $1) }
| "(" expr ")"                                { $2 }

postfix_expr:
| primary_expr                                { $1 }
| postfix_expr "[" expr "]"                   { EPostfix($1,PIdx $3) }
| postfix_expr "(" argument_expr_list? ")"    { match $3 with
                                                | Some l -> EPostfix( $1,PCall l)
                                                | None -> EPostfix( $1,PCall []) }
| postfix_expr "." ident                      { EPostfix( $1,PDot $3) }
| postfix_expr "->" ident                     { EPostfix( $1,PArrow $3) }
| postfix_expr "++"                           { EPostfix($1,PInc) }
| postfix_expr "--"                           { EPostfix($1,PDec) }
| "(" type_name ")" "{" init_list ","? "}"    { ECompoundLit( $2,IVect $5) }

argument_expr_list:
| assignment_expr                             { [$1] }
| argument_expr_list "," assignment_expr      { $1@[$3] }

unary_expr:
| postfix_expr                                { $1 }
| "++" unary_expr                             { EUnary(Plus, $2) }
| "--" unary_expr                             { EUnary(Minus, $2) }
| "&" cast_expr                               { EUnary( Ref, $2) }
| "*" cast_expr                               { EUnary( Deref, $2) }
| "+" cast_expr                               { EUnary( Plus, $2) }
| "-" cast_expr                               { EUnary( Minus, $2) }
| "~" cast_expr                               { EUnary( BitNot, $2) }
| "!" cast_expr                               { EUnary( LogNot, $2) }
| SIZEOF unary_expr                           { EUnary( Sizeof, $2) }
| SIZEOF "(" type_name ")"                    { ETyUnary(Sizeof,$3) }


cast_expr:
| unary_expr                                  { $1 }
| "(" type_name ")" cast_expr                 { ECast( $2,$4) }

multiplicative_expr:
| cast_expr                                   { $1 }
| multiplicative_expr "*" cast_expr           { EBinary( Mul,$1,$3) }
| multiplicative_expr "/" cast_expr           { EBinary( Div,$1,$3) }
| multiplicative_expr "%" cast_expr           { EBinary( Mod,$1,$3) }

additive_expr:
| multiplicative_expr                         { $1 }
| additive_expr "+" multiplicative_expr       { EBinary( Add,$1,$3) }
| additive_expr "-" multiplicative_expr       { EBinary( Sub,$1,$3) }

shift_expr:
| additive_expr                               { $1 }
| shift_expr "<<" additive_expr               { EBinary( LShift,$1,$3) }
| shift_expr ">>" additive_expr               { EBinary( RShift,$1,$3) }

relational_expr:
| shift_expr                                  { $1 }
| relational_expr "<" shift_expr              { EBinary( Lt,$1,$3) }
| relational_expr ">" shift_expr              { EBinary( Gt,$1,$3) }
| relational_expr "<=" shift_expr             { EBinary( Le,$1,$3) }
| relational_expr ">=" shift_expr             { EBinary( Ge,$1,$3) }

equality_expr:
| relational_expr                             { $1 }
| equality_expr "==" relational_expr          { EBinary( Eq,$1,$3) }
| equality_expr "!=" relational_expr          { EBinary( Ne,$1,$3) }

and_expr:
| equality_expr                               { $1 }
| and_expr "&" equality_expr                  { EBinary( BitAnd,$1,$3) }

exclusive_or_expr:
| and_expr                                    { $1 }
| exclusive_or_expr "^" and_expr              { EBinary( BitXor,$1,$3) }

inclusive_or_expr:
| exclusive_or_expr                           { $1 }
| inclusive_or_expr "|" exclusive_or_expr     { EBinary( BitOr,$1,$3) }

logical_and_expr:
| inclusive_or_expr                           { $1 }
| logical_and_expr "&&" inclusive_or_expr     { EBinary( LogAnd,$1,$3) }

logical_or_expr:
| logical_and_expr                            { $1 }
| logical_or_expr "||" logical_and_expr       { EBinary( LogOr,$1,$3) }

conditional_expr:
| logical_or_expr                             { $1 }
| logical_or_expr "?" expr ":" conditional_expr
                                              { ECond( $1,$3,$5) }

assignment_expr:
| conditional_expr                            { $1 }
| unary_expr "=" assignment_expr              { EAssign( $1,$3) }
| unary_expr "*=" assignment_expr             { EAssign( $1,EBinary( Mul,$1,$3)) }
| unary_expr "/=" assignment_expr             { EAssign( $1,EBinary( Div,$1,$3)) }
| unary_expr "%=" assignment_expr             { EAssign( $1,EBinary( Mod,$1,$3)) }
| unary_expr "+=" assignment_expr             { EAssign( $1,EBinary( Add,$1,$3)) }
| unary_expr "-=" assignment_expr             { EAssign( $1,EBinary( Sub,$1,$3)) }
| unary_expr "<<=" assignment_expr            { EAssign( $1,EBinary( LShift,$1,$3)) }
| unary_expr ">>=" assignment_expr            { EAssign( $1,EBinary( RShift,$1,$3)) }
| unary_expr "&=" assignment_expr             { EAssign( $1,EBinary( BitAnd,$1,$3)) }
| unary_expr "^=" assignment_expr             { EAssign( $1,EBinary( BitXor,$1,$3)) }
| unary_expr "|=" assignment_expr             { EAssign( $1,EBinary( BitOr,$1,$3)) }

expr:
| assignment_expr                             { $1 }
| expr "," assignment_expr                    { EBinary( Comma,$1,$3) }

constant_expr:
| conditional_expr                            { $1 }


decl:
| decl_specs ";"                              { [] }
| decl_specs init_declarator_list ";"         { make_decls_with_init $1 $2 }

decl_spec:
| storage_class_spec                          { [$1] }
| type_qual                                   { [$1] }
| function_spec                               { [$1] }
| type_spec                                   { [$1] }

decl_specs:
| decl_specs_sub                              { TDeclSpec $1 }

decl_specs_sub:
| decl_spec                                   { $1 }
| decl_specs_sub decl_spec                    { $1 @ $2 }

init_declarator_list:
| init_declarator                             { [$1] }
| init_declarator_list "," init_declarator    { $1 @ [$3] }

init_declarator:
| declarator                                  { ($1,None) }
| declarator "=" init                         { ($1,Some $3) }

storage_class_spec:
| TYPEDEF                                     { ScsTypedef }
| EXTERN                                      { ScsExtern }
| STATIC                                      { ScsStatic }
| AUTO                                        { ScsAuto }
| REGISTER                                    { ScsRegister }

type_spec:
| TVOID                                       { TsVoid }
| TCHAR                                       { TsChar }
| TSHORT                                      { TsShort}
| TINT                                        { TsInt }
| TLONG                                       { TsLong }
| TFLOAT                                      { TsFloat }
| TDOUBLE                                     { TsDouble }
| TSIGNED                                     { TsSigned }
| TUNSIGNED                                   { TsUnsigned }
| struct_or_union_spec                        { $1 }
| enum_spec                                   { TsInt }
| TYPE_ID                                     { TsInt }

spec_qual_list:
| spec_qual_list_sub                          { $1 }

spec_qual_list_sub:
| type_spec                                   { $1::[] }
| type_spec spec_qual_list_sub                { $1::$2 }
| type_qual spec_qual_list_sub                { $1::$2 }

type_qual:
| CONST                                       { TqConst }
| VOLATILE                                    { TqVolatile }

function_spec:
| INLINE                                      { FsInline }
| NORETURN                                    { FsNoreturn }


struct_or_union_spec:
| STRUCT ident? "{" list(struct_decl) "}"     { make_structdef (conv_ident $2) (List.flatten $4) }
| STRUCT ident                                { make_structdecl $2 } 
| UNION ident? "{" list(struct_decl) "}"      { make_uniondef (conv_ident $2) (List.flatten $4) }
| UNION ident                                 { make_uniondecl $2 }

struct_decl:
| spec_qual_list struct_declarator_list? ";"  { match $2 with
                                                | Some dl -> make_decls (TDeclSpec $1) dl
                                                | None -> failwith "not impl" }
struct_declarator_list:
| struct_declarator                           { [$1] }
| struct_declarator_list "," struct_declarator
                                              { $1 @ [$3] }

struct_declarator:
| declarator                                  { $1 }

enum_spec:
| ENUM ident? "{" enum_list ","? "}"          { }
| ENUM ident                                  { }

enum_list:
| enum                                        { }
| enum_list "," enum                          { }

enum:
| enum_const                                  { }
| enum_const "=" constant_expr                { }

enum_const:
| ident                                       { }

declarator:
| pointer declarator                          { DeclPtr $2 }
| direct_declarator                           { $1 }

direct_declarator:
| ID                                          { DeclIdent $1 }
| "(" declarator ")"                          { $2 }
| direct_declarator "[" constant_expr "]"     { DeclArr($1, $3) }
| direct_declarator "(" parameter_type_list ")"
                                              { DeclFun($1,$3) }

pointer:
| "*" list(type_qual)                         { }

parameter_type_list:
|                                             { [] }
| parameter_list option("," "..." {})         { $1 }

parameter_list:
| parameter_decl                              { $1 }
| parameter_list "," parameter_decl           { $1 @ $3 }

parameter_decl:
| decl_specs declarator                       { [make_decl $1 $2] }
| decl_specs abstract_declarator?             { match $2 with
                                                | Some d -> [make_decl $1 d]
                                                | None -> [make_decl $1 (DeclIdent "")] }

abstract_declarator:
| pointer                                     { DeclPtr(DeclIdent "") }
| pointer abstract_declarator                 { DeclPtr $2 }
| direct_abstract_declarator                  { $1 }

direct_abstract_declarator:
| "(" abstract_declarator ")"                 { $2 }
| "[" constant_expr "]"                       { DeclArr(DeclIdent "",$2) }
| "(" parameter_type_list ")"                 { DeclFun(DeclIdent "",$2) }
| direct_abstract_declarator "[" constant_expr "]"
                                              { DeclArr($1,$3) }
| direct_abstract_declarator "(" parameter_type_list ")"
                                              { DeclFun($1,$3) }



type_name:
| spec_qual_list                              { TDeclSpec $1 }
| spec_qual_list abstract_declarator          { TDeclSpec [] }

init:
| assignment_expr                             { IScal $1 }
| "{" init_list ","? "}"                      { IVect $2 }

init_list:
| init                                        { [(Dnone,$1)] }
| desig init                                  { [($1,$2)] }
| init_list "," init                          { $1 @ [(Dnone,$3)] }
| init_list "," desig init                    { $1 @ [($3,$4)] }

desig:
| designator_list "="                         { $1 }

designator_list:
| "[" constant_expr "]"                       { DIdx($2,Dnone) }
| "." ident                                   { DField($2,Dnone) }
| "[" constant_expr "]" designator_list       { DIdx($2, $4) } 
| "." ident designator_list                   { DField($2, $3) }

enter_scope:                                  { enter_scope () }

leave_scope:                                  { leave_scope () }

item:
| decl                                        { SDef($1) }
| stmt                                        { $1 }

stmt:
| labeled_stmt                                { $1 }
| compound_stmt                               { $1 }
| expr? ";"                                   { SExpr $1 }
| selection_stmt_1                            { $1 }
| selection_stmt_2                            { $1 }
| iteration_stmt                              { $1 }
| jump_stmt                                   { $1 }

labeled_stmt:
| ident ":" item                              { SLabel($1,$3) }

case_or_default:
| CASE conditional_expr ":" list(item)        { SCase ($2, $4) }
| DEFAULT ":" list(item)                      { SDefault ( $3) }


compound_stmt:
| enter_scope "{" list(item) "}" leave_scope  { SStmts($3) }

selection_stmt_1:
| IF "(" expr ")" stmt %prec NO_ELSE          { SIfElse($3,$5,SStmts []) }
| IF "(" expr ")" stmt ELSE stmt              { SIfElse($3,$5,$7) }

selection_stmt_2:
| SWITCH "(" expr ")" enter_scope "{" list(case_or_default) "}" leave_scope
                                              { SSwitch($3,$7) }


iteration_stmt:
| WHILE "(" expr ")" stmt                     { SWhile($3,$5) }
| DO stmt WHILE "(" expr ")"                  { SDoWhile($2,$5) }
| FOR "(" expr? ";" expr? ";" expr? ")" stmt  { SFor($3,$5,$7,$9) }

jump_stmt:
| GOTO ident ";"                              { SGoto $2 }
| CONTINUE ";"                                { SContinue }
| BREAK ";"                                   { SBreak }
| RETURN expr? ";"                            { SReturn $2 }

external_decl:
| function_def                                { [push_def $1] }
| decl                                        { $1 }

function_def:
| decl_specs declarator compound_stmt         { FunctionDef(make_decl $1 $2,$3) }
