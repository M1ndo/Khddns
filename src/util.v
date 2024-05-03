module util

import prantlf.cargs { scan, parse_scanned_to, Input }
import prantlf.config { find_config_file, read_config, error_msg_full}
import prantlf.json { marshal }
import readline
import os
import net.http

// Describe usage of the command-line tool.
const usage := 'Afraid.org Dynamic DNS Client.

Usage: Khdns [optional-options]

Options:
  -t|--time    <time-in-seconds>  write the JSON output to a file
  -s|--subs                       print subdomains and their ips.
  -c|--config  <config-file>      Load a configuration (Path)
  -v|--version                    print the version of the executable and exit
  -h|--help                       print the usage information and exit

By default It will update every 3600 seconds (1hour).

Examples:
  $ Khdns &
  $ Khdns -t 1800 # Half an hour
  $ Khdns -c custom_config.json # Load a custom configuration (config created by default in ~/.khddns.json).
'

// Declare a structure with all command-line options.
struct Opts {
pub:
  time int
	config string
  subs bool
}

// Declare Configuration options.
pub struct Config {
pub mut:
  subsfile string
  time int
}

// AfraidConf Contains Original IP address and update url.
struct AfraidConf {
pub mut:
	ip string
	url string
}

// new_config will create a new configuration file.
pub fn new_config()! {
  mut r := readline.Readline{}
	mut conf := Config{}

  for {
    conf.subsfile = r.read_line("Enter subdomains file (sub,ip,url): ")!
    if !conf.subsfile.is_blank(){
	    if conf.subsfile.starts_with("~") {
		    conf.subsfile = os.expand_tilde_to_home(conf.subsfile); break
	    } else {
		    if os.is_file(conf.subsfile) { conf.subsfile = os.abs_path(conf.subsfile); break }
	    }
    }
    println("File doesn't exists!\nPlease enter a valid subdomains file path.")
  }

  for {
    time := r.read_line("Update Interval (default 3600 '1hour'): ")!
	  if time.is_blank() {
		  conf.time = 3600; break
	  }
	  if !time.is_int() {
		  println("Please enter a valid update interval.")
		  continue
	  }
  }
	serialized_json := marshal(conf)
	output_file := os.expand_tilde_to_home("~/.khddns.json")
	mut f := os.open_file( output_file, "w", 0o755) or {eprintln(err); return}
	defer { f.close() }
	f.write_string(serialized_json) or {eprintln(err); return}
}

pub fn readconf(file string)! &Config {
	if os.is_file(file) {
		if conf := config.read_config[Config](file) {
			return conf
		} else {
			eprintln(error_msg_full(err))
		}
	}
	return error("No such file found")
	// println(conf.subsfile)
}

// Parse command-line options and arguments.
pub fn parser() !(&Opts, &Config) {
  input := Input{ version: '0.0.1' }
  scanned := scan(usage, input)!
	mut opts := Opts{ time: 3600 }
	mut conf := &Config{}
	_ := parse_scanned_to[Opts](scanned, input, mut opts)!
	if opts.config.is_blank() {
		if config_file := find_config_file(".", ['.khddns.json'], 1, true) {
			conf = read_config[Config](config_file)!
		} else {
			new_config()!
		}
	}
	return &opts, conf
}

// readsubs will read the subs file and return update url
pub fn readsubs(file string)! []map[string]AfraidConf {
	println("Reading file ${file}")
	mut subs := []map[string]AfraidConf{}
	lines := os.read_lines(file)!
	for line in lines {
		conf := line.split("|")
		mut newsub := map[string]AfraidConf{}
		new_conf := AfraidConf{ip: conf[1], url: conf[2]}
		newsub[conf[0]] = new_conf
		subs << newsub
	}
	return subs
}

// update will the ip address on the subdomains
pub fn update(url string)! string {
	mut client := http.new_request(http.Method.get, url, "")
	resp := client.do()!
	return resp.body.trim_right("\n")
}
