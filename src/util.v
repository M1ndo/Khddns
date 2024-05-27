module util

import prantlf.cargs { scan, parse_scanned_to, Input }
import prantlf.config { find_config_file, read_config, error_msg_full}
import prantlf.json as prjson
import x.json2 as js
import readline
import os
import net.http
import term

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
	cloudflare_api string
	cloudflare bool
	zoneid string
}

// AfraidConf Contains Original IP address and update url.
struct AfraidConf {
	pub mut:
	ip string
	url string
}

struct Message {
	code int
	message string
	// typed string @[json: "type"]
}

struct CheckToken {
pub mut:
	result struct {id string status string}
	success bool
	errors []string
	messages []Message
}

struct Cloudflare {
	mut:
	headers http.Header
	record CfPatch
	old_ip string
}

struct CfPatch {
	content string
	name string
	id string
	record_type string  @[json: "type"]
}

struct ResultCfPatch {
	result CfPatch
}

pub struct App {
	pub mut:
	config Config
	opts Opts
	cf Cloudflare
}

pub const (
	green = "${term.green('[')}${term.bold('+')}${term.green(']')}"
	red = "${term.red('[')}${term.bold('!')}${term.red(']')}"
	blue = "${term.blue('[')}${term.bold('-')}${term.blue(']')}"
)

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

// new_config will create a new configuration file.
pub fn (app &App) new_config()! {
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
    println("${red} File doesn't exists!\nPlease enter a valid subdomains file path.")
  }

  for {
    time := r.read_line("Update Interval (default 3600 '1hour'): ")!
	  if time.is_blank() {
		  conf.time = 3600; break
	  }
	  if !time.is_int() {
		  println("${red} Please enter a valid update interval.")
		  continue
	  }
  }
	serialized_json := prjson.marshal(conf)
	output_file := os.expand_tilde_to_home("~/.khddns.json")
	mut f := os.open_file( output_file, "w", 0o755) or {eprintln(err); return}
	defer { f.close() }
	f.write_string(serialized_json) or {eprintln(err); return}
}

pub fn (mut app App) readconf(file string)! {
	if os.is_file(file) {
		if conf := config.read_config[Config](file) {
			app.config = conf
		} else {
			eprintln(error_msg_full(err))
		}
	}
	return error("${red} No such file found")
	// println(conf.subsfile)
}

// Parse command-line options and arguments.
pub fn (mut app App) parser()! {
  input := Input{ version: '0.0.1' }
  scanned := scan(usage, input)!
	mut opts := Opts{ time: 3600 }
	mut conf := &Config{}
	_ := parse_scanned_to[Opts](scanned, input, mut opts)!
	if opts.config.is_blank() {
		if config_file := find_config_file(".", ['.khddns.json'], 1, true) {
			conf = read_config[Config](config_file)!
		} else {
			app.new_config()!
		}
	}
	app.config = conf
	app.opts = &opts
	app.cf_headers()!
}

// readsubs will read the subs file and return update url
pub fn (app &App) readsubs(file string)! []map[string]AfraidConf {
	println("${blue} Reading file ${file}")
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
pub fn (app &App) update(url string)! string {
	mut client := http.new_request(http.Method.get, url, "")
	resp := client.do()!
	return resp.body.trim_right("\n")
}

fn (mut app App) cf_headers()! {
	if !app.config.cloudflare {return}
	app.cf = Cloudflare{}
	mut headers := http.Header{}
	key := if app.config.cloudflare_api != "" {app.config.cloudflare_api} else {return error("${red} No Token available")}
	headers.add(http.CommonHeader.authorization, "Bearer ${key}")
	headers.add(http.CommonHeader.content_type, "application/json")
	app.cf.headers = headers
	app.cf_get() or {eprintln(err); return}
}

// cf_get list current domain dns records.
pub fn (mut app App) cf_get()! {
	mut new_request := http.new_request(http.Method.get,"https://api.cloudflare.com/client/v4/zones/${app.config.zoneid}/dns_records", "")
	new_request.header = app.cf.headers
	resp := new_request.do()!
	body_dec := js.raw_decode(resp.body)!
	map_results := body_dec.as_map()
	results := map_results['result'] or {return}
	domain_root := results.as_map()["0"] or {return}
	content_root := domain_root.as_map()
	ip := content_root['content'] or {""}
	name := content_root['name'] or {""}
	id := content_root['id'] or {""}
	record_type := content_root['type'] or {""}
	new_ip := app.get_ip()!
	app.cf.old_ip = ip.str()
	app.cf.record = CfPatch{content: new_ip, name: name.str(), id: id.str(), record_type: record_type.str()}
}

// cf_update Updates current domain dns records
pub fn (app &App) cf_update()! {
	data_request := js.encode[CfPatch](app.cf.record)
	mut update_request := http.new_request(http.Method.patch, "https://api.cloudflare.com/client/v4/zones/${app.config.zoneid}/dns_records/${app.cf.record.id}",data_request)
	update_request.header = app.cf.headers
	resp := update_request.do()!
	decoded_resp := js.decode[ResultCfPatch](resp.body)!
	match decoded_resp.result.content{
	app.cf.old_ip {println("${blue} ${decoded_resp.result.name} remains with the same ip ${decoded_resp.result.content}")}
	else {println("${green} Updated ${decoded_resp.result.name} with ${decoded_resp.result.content}")}
	}
}

// get_ip gets the current ip address
fn (app &App) get_ip()! string {
	resp:= http.get("https://myip.wtf/text")!
	return resp.body
}

pub fn (app &App) check_token()! CheckToken {
	mut new_request := http.new_request(http.Method.get, "https://api.cloudflare.com/client/v4/user/tokens/verify", "")
	new_request.header = app.cf.headers
	resp := new_request.do()!
	check_tok := js.decode[CheckToken](resp.body)!
	return check_tok
}
