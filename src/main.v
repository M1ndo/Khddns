module main

import util
import time

// run will start the app
fn run(app &util.App) {
	timeout := if app.opts.time != 3200 {app.opts.time} else {app.config.time}
	tmp_parsed := time.Duration(timeout * time.second).hours()
	println("${util.green} Updating Every ${tmp_parsed:.1} hours")
	if app.config.cloudflare {
		check_tok := app.check_token() or {eprintln(err); return}
		if !check_tok.success {
			eprintln("${util.red} Error, Token not active Or Some error occured")
		}
	}
	for {
		subs := app.readsubs(app.config.subsfile) or {panic(err); return}
		for sub in subs {
			for n,k in sub {
				println("${util.blue} Updating subdomain ${n} Previous IP ${k.ip}")
				msg := app.update(k.url) or {eprintln("Failed to update ${err}"); continue}
				println(msg)
			}
		}
		app.cf_update() or {eprintln(err); continue}
		time.sleep(timeout * time.second)
	}
}

// printsubs TODO will print all subdomains, ip address, and recent time of update in the subs file.
fn printsubs() {

}

fn main() {
	mut app := util.App{}
	app.parser()!
	if !app.opts.config.is_blank() {
		app.readconf(app.opts.config)!
	}
	run(app)
	// if opts.subs {
		// app.printsubs()
	// }
}
