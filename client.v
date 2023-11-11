module main

import crypto.ed25519

fn main() {
	println(ed25519.generate_key() or { panic(err) })
}