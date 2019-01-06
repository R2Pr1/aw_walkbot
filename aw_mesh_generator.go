package main

import (
	"fmt"
	"github.com/mrazza/gonav"
	"os"
)

func main() {
	fmt.Print("Enter file name (ex: de_dust2.nav): ")
	var file string
	_, _ = fmt.Scanf("%s\n", &file)
	fmt.Println(file)

	fmt.Print("Enter output file name (ex: de_dust2.lua): ")
	var output_file string
	_, _ = fmt.Scanf("%s\n", &output_file)
	fmt.Println(output_file)

	fmt.Print("Enter map bsp name (ex: de_dust2.bsp): ")
	var bsp_name string
	_, _ = fmt.Scanf("%s\n", &bsp_name)
	fmt.Println(bsp_name)

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

	file2, err := os.Create(output_file)

	if err != nil {
		fmt.Printf("Cannot create file: %v", err)
	}
	defer file2.Close()

	_, _ = fmt.Fprintf(file2, "['%v'] = {['edges']={", bsp_name)
	for _, area := range mesh.Areas {
		_, _ = fmt.Fprintf(file2, "[%v]={", area.ID)
		for i, currConnection := range area.Connections {
			var comma = ""
			if int(i) < (len(area.Connections) - 1) {
				comma = ","
			}
			_, _ = fmt.Fprintf(file2, "%v%v", currConnection.TargetAreaID, comma);
		}
		_, _ = fmt.Fprint(file2, "},")
	}

	_, _ = fmt.Fprint(file2, "},['nodes']={")
	var i = 0
	for _, area := range mesh.Areas {
		center := area.GetCenter()
		var comma = ""
		if i < (len(mesh.Areas) - 1) {
			comma = ","
		}
		_, _ = fmt.Fprintf(file2, "{id=%v,x=%v,y=%v,z=%v}%v", area.ID, center.X, center.Y, center.Z, comma)

		i++
	}
	_, _ = fmt.Fprint(file2, "}},")

	fmt.Println("Output generated")
}