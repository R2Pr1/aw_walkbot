package main

import (
	"fmt"
	"github.com/mrazza/gonav"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	var files []string

	root := "."
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if filepath.Ext(path) == ".nav" {
			files = append(files, path)
		}
		return nil
	})

	output_file, err := os.Create("walkbot_mesh.lua")

	if err != nil {
		fmt.Printf("Cannot create file: %v", err)
	}
	defer output_file.Close()

	_, _ = fmt.Fprint(output_file, "maps = {")

	for _, file := range files {
		f, ok := os.Open(file) // Open the file

		if ok != nil {
			fmt.Printf("Failed to open file: %v\n", ok)
			return
		}

		defer f.Close()
		parser := gonav.Parser{Reader: f}
		mesh, nerr := parser.Parse() // Parse the file
		if nerr != nil {
			fmt.Printf("Failed to parse: %v\n", nerr)
			return
		}

		_, _ = fmt.Fprintf(output_file, "['%v'] = {['edges']={", file[:strings.IndexByte(file, '.')])
		for _, area := range mesh.Areas {
			_, _ = fmt.Fprintf(output_file, "[%v]={", area.ID)
			for i, currConnection := range area.Connections {
				var comma= ""
				if int(i) < (len(area.Connections) - 1) {
					comma = ","
				}
				_, _ = fmt.Fprintf(output_file, "%v%v", currConnection.TargetAreaID, comma);
			}
			_, _ = fmt.Fprint(output_file, "},")
		}

		_, _ = fmt.Fprint(output_file, "},['nodes']={")
		var i= 0
		for _, area := range mesh.Areas {
			center := area.GetCenter()
			var comma= ""
			if i < (len(mesh.Areas) - 1) {
				comma = ","
			}
			_, _ = fmt.Fprintf(output_file, "{id=%v,x=%v,y=%v,z=%v}%v", area.ID, center.X, center.Y, center.Z, comma)

			i++
		}
		_, _ = fmt.Fprint(output_file, "}},")
	}
	_, _ = fmt.Fprint(output_file, "}")
	fmt.Println("Output generated")
}