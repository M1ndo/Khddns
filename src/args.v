module args

import prantlf.cargs { scan, parse_scanned_to, Input }

// Describe usage of the command-line tool.
const usage := 'Afraid.org Dynamic DNS Client.

Usage: Khdns [optional-options]

  <yaml-file>         read the YAML input from a file

Options:
  -t|--time    <time-in-seconds>  write the JSON output to a file
  -s|--subs                       print subdomains and their ips.
  -V|--version                    print the version of the executable and exit
  -h|--help                       print the usage information and exit

By default It will update every 3600 seconds (1hour).

Examples:
  $ Khdns &
  $ Khdns -t 1800 # Half an hour
'

// Declare a structure with all command-line options.
struct Opts {
  time int
  subs bool
  pretty bool
}

// Parse command-line options and arguments.
pub fn parser()! {
  usage_opts = Input{version: '0.0.1'}
  input := Input{ version: '0.0.1' }
  scanned := scan(usage, input)!
  // ...
  //   mut opts := Opts{ output: 'out.json' }
  // args := parse_scanned_to[Opts](scanned, input, mut opts)!
  // opts, argss := parse[Opts](usage, Input{ version: '0.0.1' })!
  if argss.len > 0 {
    // Process file names from the args array.
    return error("No Arguments specified!")
  } else {
    // Read from the standard input.
    println(argss)
  }
}
