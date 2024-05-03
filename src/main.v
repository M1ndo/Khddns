module main

import util
import time

// run will start the app
fn run(timeout int, file string) {
	tmp_parsed := time.Duration(timeout * time.second).hours()
	println("Updating Every ${tmp_parsed:.1} hours")
	for {
		subs := util.readsubs(file) or {panic(err); return}
		for sub in subs {
			for n,k in sub {
				println("Updating subdomain ${n} Previous IP ${k.ip}")
				msg := util.update(k.url) or {eprintln("Failed to update ${err}"); continue}
				println(msg)
			}
		}
		time.sleep(timeout * time.second)
	}
}

// printsubs TODO will print all subdomains, ip address, and recent time of update in the subs file.
fn printsubs() {

}

fn main() {
	opts, mut conf := util.parser()!
	if !opts.config.is_blank() {
		conf = util.readconf(opts.config)!
	}
	if opts.time != 3200 {
		run(opts.time, conf.subsfile)
	} else {
		run(conf.time, conf.subsfile)
	}
	// if opts.subs {
		// app.printsubs()
	// }
}
