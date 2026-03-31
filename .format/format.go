package main

import (
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"strings"
)

func transformIfInit(f *ast.File) {
	ast.Inspect(f, func(n ast.Node) bool {
		block, ok := n.(*ast.BlockStmt)
		if !ok {
			return true
		}
		block.List = transformIfInitStmts(block.List)
		return true
	})
}

func transformIfInitStmts(stmts []ast.Stmt) []ast.Stmt {
	var newStmts []ast.Stmt
	for _, stmt := range stmts {
		ifStmt, ok := stmt.(*ast.IfStmt)
		if !ok || ifStmt.Init == nil {
			newStmts = append(newStmts, stmt)
			continue
		}

		// Keep exceptions as-is
		if isMapExistenceCheck(ifStmt) || isFileExistenceCheck(ifStmt) {
			newStmts = append(newStmts, stmt)
			continue
		}

		// Only transform the error-check pattern: if x, err := fn(); err != nil
		if !isErrorCheckPattern(ifStmt) {
			newStmts = append(newStmts, stmt)
			continue
		}

		assign := ifStmt.Init.(*ast.AssignStmt)
		initStmt := &ast.AssignStmt{
			Lhs:    assign.Lhs,
			TokPos: assign.TokPos,
			Tok:    assign.Tok,
			Rhs:    assign.Rhs,
		}
		ifStmt.Init = nil
		newStmts = append(newStmts, initStmt, ifStmt)
	}
	return newStmts
}

func isErrorCheckPattern(ifStmt *ast.IfStmt) bool {
	assign, ok := ifStmt.Init.(*ast.AssignStmt)
	if !ok || assign.Tok != token.DEFINE || len(assign.Lhs) < 2 {
		return false
	}

	bin, ok := ifStmt.Cond.(*ast.BinaryExpr)
	if !ok || bin.Op != token.NEQ {
		return false
	}

	var errIdent *ast.Ident
	var nilFound bool

	if x, ok := bin.X.(*ast.Ident); ok && x.Name == "nil" {
		nilFound = true
		if y, ok := bin.Y.(*ast.Ident); ok {
			errIdent = y
		}
	} else if x, ok := bin.X.(*ast.Ident); ok {
		errIdent = x
		if y, ok := bin.Y.(*ast.Ident); ok && y.Name == "nil" {
			nilFound = true
		}
	}

	if errIdent == nil || !nilFound {
		return false
	}

	secondLhs, ok := assign.Lhs[1].(*ast.Ident)
	if !ok {
		return false
	}
	return errIdent.Name == secondLhs.Name
}

func isMapExistenceCheck(ifStmt *ast.IfStmt) bool {
	assign, ok := ifStmt.Init.(*ast.AssignStmt)
	if !ok || assign.Tok != token.DEFINE || len(assign.Lhs) != 2 {
		return false
	}
	blank, ok := assign.Lhs[0].(*ast.Ident)
	if !ok || blank.Name != "_" {
		return false
	}
	_, ok = assign.Rhs[0].(*ast.IndexExpr)
	if !ok {
		return false
	}
	cond, ok := ifStmt.Cond.(*ast.Ident)
	if !ok {
		return false
	}
	secondLhs, ok := assign.Lhs[1].(*ast.Ident)
	return ok && cond.Name == secondLhs.Name
}

func isFileExistenceCheck(ifStmt *ast.IfStmt) bool {
	assign, ok := ifStmt.Init.(*ast.AssignStmt)
	if !ok || assign.Tok != token.DEFINE || len(assign.Lhs) != 2 {
		return false
	}
	blank, ok := assign.Lhs[0].(*ast.Ident)
	if !ok || blank.Name != "_" {
		return false
	}
	call, ok := assign.Rhs[0].(*ast.CallExpr)
	if !ok {
		return false
	}
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok || sel.Sel.Name != "Stat" {
		return false
	}
	ident, ok := sel.X.(*ast.Ident)
	if !ok || ident.Name != "os" {
		return false
	}
	condCall, ok := ifStmt.Cond.(*ast.CallExpr)
	if !ok {
		return false
	}
	condSel, ok := condCall.Fun.(*ast.SelectorExpr)
	if !ok || condSel.Sel.Name != "IsNotExist" {
		return false
	}
	condIdent, ok := condSel.X.(*ast.Ident)
	if !ok || condIdent.Name != "os" {
		return false
	}
	if len(condCall.Args) != 1 {
		return false
	}
	argIdent, ok := condCall.Args[0].(*ast.Ident)
	if !ok {
		return false
	}
	secondLhs, ok := assign.Lhs[1].(*ast.Ident)
	return ok && argIdent.Name == secondLhs.Name
}

// ---------------------------------------------------------------------------
// Rule 3: Convert zero-value assignments to var declarations
// ---------------------------------------------------------------------------

func transformAssignmentsToVars(f *ast.File, info *types.Info) {
	ast.Inspect(f, func(n ast.Node) bool {
		block, ok := n.(*ast.BlockStmt)
		if !ok {
			return true
		}
		block.List = transformAssignmentsToVarsStmts(block.List, info)
		return true
	})
}

func transformAssignmentsToVarsStmts(stmts []ast.Stmt, info *types.Info) []ast.Stmt {
	var newStmts []ast.Stmt
	for _, stmt := range stmts {
		assign, ok := stmt.(*ast.AssignStmt)
		if !ok || assign.Tok != token.DEFINE || len(assign.Lhs) != 1 || len(assign.Rhs) != 1 {
			newStmts = append(newStmts, stmt)
			continue
		}

		ident, ok := assign.Lhs[0].(*ast.Ident)
		if !ok {
			newStmts = append(newStmts, stmt)
			continue
		}

		typ := info.TypeOf(ident)
		if typ == nil {
			newStmts = append(newStmts, stmt)
			continue
		}

		if !isZeroValue(assign.Rhs[0], typ) {
			newStmts = append(newStmts, stmt)
			continue
		}

		typExpr := typeToAST(typ)
		decl := &ast.GenDecl{
			Tok: token.VAR,
			Specs: []ast.Spec{
				&ast.ValueSpec{
					Names: []*ast.Ident{ident},
					Type:  typExpr,
				},
			},
		}
		newStmts = append(newStmts, &ast.DeclStmt{Decl: decl})
	}
	return newStmts
}

func isZeroValue(expr ast.Expr, typ types.Type) bool {
	switch t := typ.Underlying().(type) {
	case *types.Basic:
		lit, ok := expr.(*ast.BasicLit)
		if !ok {
			return false
		}
		switch t.Kind() {
		case types.Bool:
			return lit.Value == "false"
		case types.Int, types.Int8, types.Int16, types.Int32, types.Int64,
			types.Uint, types.Uint8, types.Uint16, types.Uint32, types.Uint64,
			types.Uintptr:
			return lit.Value == "0"
		case types.Float32, types.Float64:
			return lit.Value == "0" || lit.Value == "0.0"
		case types.Complex64, types.Complex128:
			return lit.Value == "0" || lit.Value == "0+0i"
		case types.String:
			return lit.Value == `""`
		}
	case *types.Pointer, *types.Slice, *types.Map, *types.Chan, *types.Interface, *types.Signature:
		ident, ok := expr.(*ast.Ident)
		return ok && ident.Name == "nil"
	}
	return false
}

func typeToAST(typ types.Type) ast.Expr {
	// Handle named types first (e.g., time.Duration, mypkg.MyStruct)
	if named, ok := typ.(*types.Named); ok {
		obj := named.Obj()
		if obj.Pkg() == nil {
			return &ast.Ident{Name: obj.Name()}
		}
		return &ast.SelectorExpr{
			X:   &ast.Ident{Name: obj.Pkg().Name()},
			Sel: &ast.Ident{Name: obj.Name()},
		}
	}

	switch t := typ.Underlying().(type) {
	case *types.Basic:
		return &ast.Ident{Name: t.Name()}
	case *types.Pointer:
		return &ast.StarExpr{X: typeToAST(t.Elem())}
	case *types.Slice:
		return &ast.ArrayType{Elt: typeToAST(t.Elem())}
	case *types.Array:
		return &ast.ArrayType{
			Len: &ast.BasicLit{Kind: token.INT, Value: fmt.Sprintf("%d", t.Len())},
			Elt: typeToAST(t.Elem()),
		}
	case *types.Map:
		return &ast.MapType{
			Key:   typeToAST(t.Key()),
			Value: typeToAST(t.Elem()),
		}
	case *types.Chan:
		var dir ast.ChanDir
		switch t.Dir() {
		case types.SendOnly:
			dir = ast.SEND
		case types.RecvOnly:
			dir = ast.RECV
		default:
			dir = 0 // bidirectional
		}
		return &ast.ChanType{Dir: dir, Value: typeToAST(t.Elem())}
	case *types.Signature:
		return &ast.FuncType{
			Params:  fieldListToAST(t.Params()),
			Results: fieldListToAST(t.Results()),
		}
	case *types.Interface:
		return &ast.InterfaceType{Methods: &ast.FieldList{}}
	default:
		// Fallback for complex types like structs
		typeStr := types.TypeString(typ, func(p *types.Package) string { return p.Name() })
		return &ast.Ident{Name: typeStr}
	}
}

func fieldListToAST(tuple *types.Tuple) *ast.FieldList {
	if tuple == nil || tuple.Len() == 0 {
		return &ast.FieldList{}
	}
	var fields []*ast.Field
	for i := 0; i < tuple.Len(); i++ {
		v := tuple.At(i)
		fields = append(fields, &ast.Field{
			Names: []*ast.Ident{ast.NewIdent(v.Name())},
			Type:  typeToAST(v.Type()),
		})
	}
	return &ast.FieldList{List: fields}
}

// ---------------------------------------------------------------------------
// Rule 2: Group consecutive var declarations
// ---------------------------------------------------------------------------

func groupVarDecls(f *ast.File) {
	f.Decls = groupTopLevelVarDecls(f.Decls)
	ast.Inspect(f, func(n ast.Node) bool {
		block, ok := n.(*ast.BlockStmt)
		if !ok {
			return true
		}
		block.List = groupBlockVarDeclsStmts(block.List)
		return true
	})
}

func groupTopLevelVarDecls(decls []ast.Decl) []ast.Decl {
	var newDecls []ast.Decl
	var pendingSpecs []ast.Spec

	flush := func() {
		if len(pendingSpecs) == 0 {
			return
		}
		newDecls = append(newDecls, &ast.GenDecl{Tok: token.VAR, Specs: pendingSpecs})
		pendingSpecs = nil
	}

	for _, decl := range decls {
		genDecl, ok := decl.(*ast.GenDecl)
		if !ok || genDecl.Tok != token.VAR {
			flush()
			newDecls = append(newDecls, decl)
			continue
		}
		pendingSpecs = append(pendingSpecs, genDecl.Specs...)
	}
	flush()
	return newDecls
}

func groupBlockVarDeclsStmts(stmts []ast.Stmt) []ast.Stmt {
	var newStmts []ast.Stmt
	var pendingSpecs []ast.Spec

	flush := func() {
		if len(pendingSpecs) == 0 {
			return
		}
		newStmts = append(newStmts, &ast.DeclStmt{
			Decl: &ast.GenDecl{Tok: token.VAR, Specs: pendingSpecs},
		})
		pendingSpecs = nil
	}

	for _, stmt := range stmts {
		declStmt, ok := stmt.(*ast.DeclStmt)
		if !ok {
			flush()
			newStmts = append(newStmts, stmt)
			continue
		}
		genDecl, ok := declStmt.Decl.(*ast.GenDecl)
		if !ok || genDecl.Tok != token.VAR {
			flush()
			newStmts = append(newStmts, stmt)
			continue
		}
		pendingSpecs = append(pendingSpecs, genDecl.Specs...)
	}
	flush()
	return newStmts
}

// ---------------------------------------------------------------------------
// Rule 4: Spacing around control flow statements
// ---------------------------------------------------------------------------

func applySpacingRules(input string) string {
	lines := strings.Split(input, "\n")
	n := len(lines)

	// Build brace matching map for block-end detection
	closeToOpen := make(map[int]int)
	stack := []int{}

	for i, line := range lines {
		cleaned := removeStringsAndComments(line)
		for _, ch := range cleaned {
			if ch == '{' {
				stack = append(stack, i)
			} else if ch == '}' && len(stack) > 0 {
				open := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				closeToOpen[i] = open
			}
		}
	}

	// Identify lines that start with control flow keywords
	controlFlowKeywords := map[string]bool{
		"switch": true, "for": true, "if": true, "return": true, "select": true,
	}
	controlFlowLines := make(map[int]string)
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		words := strings.Fields(trimmed)
		if len(words) > 0 && controlFlowKeywords[words[0]] {
			controlFlowLines[i] = words[0]
		}
	}

	// Mark closing braces that end a control flow block (need blank line after)
	blockEnds := make(map[int]bool)
	for closeLine, openLine := range closeToOpen {
		if kw, ok := controlFlowLines[openLine]; ok && kw != "return" {
			blockEnds[closeLine] = true
		}
	}

	var result []string
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		indent := getIndent(line)

		// Add blank line before control flow keyword (at same indent level)
		if kw, ok := controlFlowLines[i]; ok && len(result) > 0 {
			prevTrimmed := strings.TrimSpace(result[len(result)-1])
			if prevTrimmed != "" {
				prevIndent := getIndent(result[len(result)-1])
				if indent == prevIndent {
					// Exception: if previous line assigns a variable checked in this if
					if kw == "if" && isRelatedAssignment(prevTrimmed, trimmed) {
						// no blank line
					} else {
						result = append(result, "")
					}
				}
			}
		}

		result = append(result, line)

		// Add blank line after closing brace of a control flow block
		if blockEnds[i] && i+1 < n {
			nextTrimmed := strings.TrimSpace(lines[i+1])
			if nextTrimmed != "" {
				nextIndent := getIndent(lines[i+1])
				if nextIndent == indent {
					result = append(result, "")
				}
			}
		}
	}

	// Deduplicate consecutive blank lines
	var deduped []string
	for i, line := range result {
		if line == "" && i > 0 && result[i-1] == "" {
			continue
		}
		deduped = append(deduped, line)
	}

	return strings.Join(deduped, "\n")
}

func getIndent(line string) int {
	return len(line) - len(strings.TrimLeft(line, " \t"))
}

func removeStringsAndComments(s string) string {
	var result []rune
	runes := []rune(s)
	i := 0
	for i < len(runes) {
		ch := runes[i]
		switch {
		case ch == '/' && i+1 < len(runes) && runes[i+1] == '/':
			// Line comment: skip rest of line
			i = len(runes)
		case ch == '/' && i+1 < len(runes) && runes[i+1] == '*':
			// Block comment: find end
			i += 2
			for i < len(runes)-1 && !(runes[i] == '*' && runes[i+1] == '/') {
				i++
			}
			i += 2
		case ch == '"':
			// Interpreted string
			i++
			for i < len(runes) && runes[i] != '"' {
				if runes[i] == '\\' {
					i++
				}
				i++
			}
			i++
		case ch == '\'':
			// Rune literal
			i++
			for i < len(runes) && runes[i] != '\'' {
				if runes[i] == '\\' {
					i++
				}
				i++
			}
			i++
		case ch == '`':
			// Raw string
			i++
			for i < len(runes) && runes[i] != '`' {
				i++
			}
			i++
		default:
			result = append(result, ch)
			i++
		}
	}
	return string(result)
}

func isRelatedAssignment(prevLine, ifLine string) bool {
	// Extract condition from if line
	cond := strings.TrimPrefix(ifLine, "if ")
	if idx := strings.Index(cond, "{"); idx >= 0 {
		cond = cond[:idx]
	}
	cond = strings.TrimSpace(cond)

	condVars := extractIdentifiers(cond)
	if len(condVars) == 0 {
		return false
	}

	// Extract variables from assignment
	assignVars := extractAssignVariables(prevLine)
	if len(assignVars) == 0 {
		return false
	}

	for _, cv := range condVars {
		for _, av := range assignVars {
			if cv == av {
				return true
			}
		}
	}
	return false
}

func extractIdentifiers(s string) []string {
	var result []string
	parts := strings.FieldsFunc(s, func(r rune) bool {
		return !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_')
	})
	for _, p := range parts {
		if len(p) > 0 && !isGoKeyword(p) && isLetterOrUnderscore(p[0]) {
			result = append(result, p)
		}
	}
	return result
}

func extractAssignVariables(s string) []string {
	idx := strings.Index(s, ":=")
	if idx < 0 {
		return nil
	}
	return extractIdentifiers(s[:idx])
}

func isLetterOrUnderscore(ch byte) bool {
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

func isGoKeyword(s string) bool {
	switch s {
	case "break", "case", "chan", "const", "continue", "default", "defer",
		"else", "fallthrough", "for", "func", "go", "goto", "if",
		"import", "interface", "map", "package", "range", "return",
		"select", "struct", "switch", "type", "var",
		"nil", "true", "false":
		return true
	}
	return false
}
