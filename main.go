package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/blang/semver/v4"
	_ "github.com/mattn/go-sqlite3"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"k8s.io/apimachinery/pkg/util/sets"
)

type channelEntry struct {
	packageName            string
	channelName            string
	bundleName             string
	depth                  int
	bundleVersion          string
	bundleSkipRange        string
	bundleSkip             string
	replacesBundleName     string
	headOperatorBundleName string
	defaultChannel         string
}

type pkg struct {
	name           string
	bundles        map[string]*bundle
	defaultChannel string
}

type bundle struct {
	name            string
	version         string
	packageName     string
	skips           string
	skipRange       string
	minDepth        int
	channels        sets.String
	replaces        sets.String
	skipRanges      sets.String
	isBundlePresent bool
	channelHeads    sets.String
}

// for pretty-printing Mermaid script
var indent1 = "  "
var indent2 = "    "
var indent3 = "      "

func main() {
	var pkgToGraph string
	root := cobra.Command{
		Use:   "olm-mermaid-graph",
		Short: "Generate the upgrade graphs from an OLM index",
		RunE: func(_ *cobra.Command, args []string) error {
			if len(args) > 0 {
				pkgToGraph = args[0]
			}
			return run(pkgToGraph)
		},
	}

	if err := root.Execute(); err != nil {
		log.Fatal(err)
	}
}

func run(pkgToGraph string) error {
	pkgs, err := loadPackages(pkgToGraph)
	if err != nil {
		return err
	}

	outputMermaidScript(pkgs)
	return nil
}

func loadPackages(pkgToGraph string) (map[string]*pkg, error) {
	pkgs := map[string]*pkg{}

	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		entryRow := scanner.Text()
		var chanEntry channelEntry
		fields := strings.Split(entryRow, string('|'))
		chanEntry.packageName = fields[0]
		chanEntry.channelName = fields[1]
		chanEntry.bundleName = fields[2]
		chanEntry.depth, _ = strconv.Atoi(fields[3])
		chanEntry.bundleVersion = fields[4]
		chanEntry.bundleSkipRange = fields[5]
		chanEntry.bundleSkip = fields[6]
		chanEntry.replacesBundleName = fields[7]
		chanEntry.headOperatorBundleName = fields[8]
		chanEntry.defaultChannel = fields[9]

		if pkgToGraph != "" && chanEntry.packageName != pkgToGraph {
			continue
		}
		// Get or create package
		p, ok := pkgs[chanEntry.packageName]
		if !ok {
			p = &pkg{
				name:           chanEntry.packageName,
				bundles:        make(map[string]*bundle),
				defaultChannel: chanEntry.defaultChannel,
			}
		}
		pkgs[chanEntry.packageName] = p

		// Get or create bundle
		bundl, ok := p.bundles[chanEntry.bundleName]
		if !ok {
			bundl = &bundle{
				name:            chanEntry.bundleName,
				packageName:     chanEntry.packageName,
				minDepth:        chanEntry.depth,
				isBundlePresent: chanEntry.bundleVersion != "",
				skips:           chanEntry.bundleSkip,
				channelHeads:    sets.NewString(),
				channels:        sets.NewString(),
				replaces:        sets.NewString(),
				skipRanges:      sets.NewString(),
			}
			if chanEntry.bundleSkipRange != "" {
				bundl.skipRange = chanEntry.bundleSkipRange
			}
			if chanEntry.bundleVersion != "" {
				bundl.version = chanEntry.bundleVersion
			} else {
				// catch empty version field because empty '()' are a Mermaid syntax error
				bundl.version = "x.y.z"
			}
		}
		bundl.channelHeads.Insert(chanEntry.headOperatorBundleName + chanEntry.channelName)
		p.bundles[chanEntry.bundleName] = bundl

		bundl.channels.Insert(chanEntry.channelName)
		if chanEntry.replacesBundleName != "" {
			bundl.replaces.Insert(chanEntry.replacesBundleName)
		}
		if chanEntry.depth < bundl.minDepth {
			bundl.minDepth = chanEntry.depth
		}
	}
	for _, p := range pkgs {
		for _, pb := range p.bundles {
			if pb.skipRange == "" {
				continue
			}
			pSkipRange, err := semver.ParseRange(pb.skipRange)
			if err != nil {
				fmt.Errorf("invalid range %q for bundle %q: %v", pb.skipRange, pb.name, err)
				continue
			}
			for _, cb := range p.bundles {
				if !cb.isBundlePresent {
					continue
				}
				cVersion, err := semver.Parse(cb.version)
				if err != nil {
					fmt.Errorf("invalid version %q for bundle %q: %v", cb.version, cb.name, err)
					continue
				}
				if pSkipRange(cVersion) {
					pb.skipRanges.Insert(cb.name)
				}
			}
		}
	}

	return pkgs, nil
}

func outputMermaidScript(pkgs map[string]*pkg) {
	graphHeader()
	for _, pkg := range pkgs {
		allBundleChannels := sets.NewString()                     // we want subgraph organized by channel
		fmt.Fprintf(os.Stdout, "\n"+indent1+"subgraph "+pkg.name) // per package graph
		for _, bundle := range pkg.bundles {
			allBundleChannels = bundle.channels.Union(allBundleChannels)
		}
		for _, channel := range allBundleChannels.List() {
			if channel == pkg.defaultChannel {
				fmt.Fprintf(os.Stdout, "\n"+indent2+"subgraph "+channel+" channel - default")
			} else {
				fmt.Fprintf(os.Stdout, "\n"+indent2+"subgraph "+channel+" channel")
			}
			replaceSet := sets.NewString()
			skipRangeReplaceSet := sets.NewString()
			for _, bundle := range pkg.bundles {
				if bundle.channels.Has(channel) {
					// if no replaces edges, just write the node
					if bundle.replaces.Len() == 0 && bundle.skipRanges.Len() == 0 {
						if bundle.channelHeads.Has(bundle.name + channel) {
							replaceSet.Insert(bundle.name + "-" + channel + "(" + bundle.version + "):::head")
						} else {
							replaceSet.Insert(bundle.name + "-" + channel + "(" + bundle.version + ")")
						}
					}
					for _, replace := range bundle.replaces.List() {
						if bundle.skips == "" {
							if bundle.channelHeads.Has(bundle.name + channel) {
								replaceSet.Insert(replace + "-" + channel + "(" +
									pkg.bundles[replace].version + ")" + " --> " + bundle.name + "-" +
									channel + "(" + bundle.version + "):::head")
							} else {
								replaceSet.Insert(replace + "-" + channel + "(" +
									pkg.bundles[replace].version + ")" + " --> " + bundle.name + "-" +
									channel + "(" + bundle.version + ")")
							}
						} else {
							if bundle.channelHeads.Has(bundle.name + channel) {
								replaceSet.Insert(replace + "-" + channel + "(" +
									pkg.bundles[replace].version + ")" + " x--x | " + bundle.skips + " | " + bundle.name + "-" +
									channel + "(" + bundle.version + "):::head")
							} else {
								replaceSet.Insert(replace + "-" + channel + "(" +
									pkg.bundles[replace].version + ")" + " x--x | " + bundle.skips + " | " + bundle.name + "-" +
									channel + "(" + bundle.version + ")")
							}
						}
					} // end bundle replaces edge graphing
					for _, skipRangeReplace := range bundle.skipRanges.List() {
						if bundle.channelHeads.Has(bundle.name + channel) {
							skipRangeReplaceSet.Insert(skipRangeReplace + "-" + channel +
								"(" + pkg.bundles[skipRangeReplace].version + ")" + " o--o | " + bundle.skipRange + " | " +
								bundle.name + "-" + channel + "(" + bundle.version + "):::head")
						} else {
							skipRangeReplaceSet.Insert(skipRangeReplace + "-" + channel +
								"(" + pkg.bundles[skipRangeReplace].version + ")" + " o--o | " + bundle.skipRange + " | " +
								bundle.name + "-" + channel + "(" + bundle.version + ")")
						}
					} // end bundle skipRanges edge graphing
				}
			}
			printReplaceLines(replaceSet)
			printSkipRangeLines(skipRangeReplaceSet)
			fmt.Fprintf(os.Stdout, "\n"+indent2+"end") // end channel graph
		} // end per channel loop
		fmt.Fprintf(os.Stdout, "\n"+indent1+"end") // end pkg graph
	} // end package loop
}

func printSkipRangeLines(skipRangeReplaceSet sets.String) {
	for _, skipRangeReplaceLine := range skipRangeReplaceSet.List() {
		fmt.Fprintf(os.Stdout, "\n"+indent3+skipRangeReplaceLine)
	}
}

func printReplaceLines(replaceSet sets.String) {
	for _, replaceLine := range replaceSet.List() {
		fmt.Fprintf(os.Stdout, "\n"+indent3+replaceLine)
	}
}

func graphHeader() {
	fmt.Fprintln(os.Stdout, "flowchart LR") // Flowchart left-right header
	fmt.Fprintln(os.Stdout, indent1+"classDef head fill:#ffbfcf;")
	fmt.Fprintln(os.Stdout, indent1+"classDef installed fill:#34ebba;")
}
