package main

import (
	"bytes"
	"fmt"
	"go/format"
	"go/token"
	"os"

	"golang.org/x/tools/go/packages"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "usage: gofmt-custom <file.go>\n")
		os.Exit(1)
	}

	fset := token.NewFileSet()
	cfg := &packages.Config{
		Mode: packages.NeedName | packages.NeedTypes | packages.NeedTypesInfo | packages.NeedSyntax,
		Fset: fset,
	}
	pkgs, err := packages.Load(cfg, "file="+os.Args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "load error: %v\n", err)
		os.Exit(1)
	}
	if len(pkgs) == 0 {
		fmt.Fprintf(os.Stderr, "no packages loaded\n")
		os.Exit(1)
	}
	if len(pkgs[0].Errors) > 0 {
		fmt.Fprintf(os.Stderr, "package errors: %v\n", pkgs[0].Errors)
		os.Exit(1)
	}

	f := pkgs[0].Syntax[0]
	info := pkgs[0].TypesInfo

	// Apply AST-level transformations in order
	transformIfInit(f)
	transformAssignmentsToVars(f, info)
	groupVarDecls(f)

	// Format with standard gofmt
	var buf bytes.Buffer
	if err := format.Node(&buf, fset, f); err != nil {
		fmt.Fprintf(os.Stderr, "format error: %v\n", err)
		os.Exit(1)
	}

	// Apply text-level spacing rules
	result := applySpacingRules(buf.String())
	fmt.Print(result)
}
