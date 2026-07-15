package command

import "strings"

var multiValueFlags = map[string]bool{
	"--agent": true, "-a": true,
	"--skill": true, "-s": true,
	"--subagent": true,
}

// normalizeMultiValueFlags preserves skills-sh's `--agent a b` syntax while
// presenting conventional repeated flags to Cobra/pflag.
func normalizeMultiValueFlags(args []string) []string {
	result := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if !multiValueFlags[arg] {
			result = append(result, arg)
			continue
		}
		flag := arg
		consumed := false
		for i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
			i++
			result = append(result, flag+"="+args[i])
			consumed = true
		}
		if !consumed {
			result = append(result, arg)
		}
	}
	return result
}
