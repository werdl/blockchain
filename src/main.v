module main

import crypto.sha256
import time
import os
import net
import io
import json
import crypto.ed25519 as crypt

struct Block {
	index int
	timestamp string
	data string
	sender string
	pub_key string
	mut: hash string
	prev_hash string
	signature string
}

struct UserBlock {
	username string
	pubk string
	username_encrypted_with_priv_key string
}

fn keystr(hash []u8) string {
	mut out:=""
	for i in hash {
		out+=i.str()+","
	}
	return out
}

fn strkey(str string) []u8 {

	mut splitted:=str.split(",")
	splitted=splitted[..splitted.len-1].clone()
	mut out:=[]u8{}
	for c in splitted {
		out << u8(c.int())
	}
	return out
}

fn (b Block) calchash() string {
	record:=b.index.str()+b.timestamp+b.data+b.prev_hash
	return sha256.hexhash(record)
}
fn (oldblock Block) genblock(data string, sender string, pub_key []u8) Block {
	mut ret:=Block{
		index: oldblock.index+1
		timestamp: time.now().str()
		data: data
		sender: sender
		pub_key: keystr(pub_key)
		prev_hash: oldblock.hash
	}
	ret.hash=ret.calchash()
	return ret
}
fn (b Block) isvalid(oldblock Block) bool {
	if oldblock.index+1!=b.index {
		return false
	} else if oldblock.hash!=b.prev_hash {
		return false
	} else if b.calchash()!=b.hash {
		return false
	} 
	// else if crypt.verify(b.pub_key, ) {
	// }
	else {
		return true
	}
}

fn (u []UserBlock) verify(username string, pubk []u8) bool {
	for user in u {
		if user.username==username {
			if keystr(pubk)==user.pubk {
				return crypt.verify(pubk, username.bytes(), strkey(user.username_encrypted_with_priv_key)) or { panic(err) }
			}
		}
	}
	return false
}

fn (mut u []UserBlock) new(username string, pub_key string, username_encrypted_with_priv_key string) bool {
	for user in u {
		if user.username==username {
			return false
		}
	}
	u << UserBlock{
		username: username
		pubk: pub_key
		username_encrypted_with_priv_key: username_encrypted_with_priv_key
	}
	return true
}

fn replacechain(newblocks []Block) {
	if newblocks.len > blockchain.len {
		blockchain=newblocks.clone()
	}
}
fn genesis() {
	pubk, privk := crypt.generate_key() or { panic(err) } 
	msg:="\"I love deadlines. I love the whooshing noise they make as they go by.\" - Douglas Adams"
	sig:=keystr(privk.sign(msg.bytes()) or { panic(err) })
	enc_u:=keystr(privk.sign("genesis".bytes()) or { panic(err) })
	if !users.new("genesis", keystr(pubk), enc_u) {
		return
	}
	blockchain << Block{
		index: 0
		timestamp: time.now().str()
		data: msg
		prev_hash: ""
		hash: ""
		sender: "genesis"
		pub_key: keystr(pubk)
		signature: sig
	}
}
__global (
	blockchain []Block
	users []UserBlock
)
fn handle_packet(data string, sender string, pub_key string) {
	blockchain << blockchain[blockchain.len-1].genblock(data, sender, pub_key.bytes())
	if blockchain.len>1 {
		if !blockchain[blockchain.len-1].isvalid(blockchain[blockchain.len-2]) {
			blockchain.pop()
			eprintln("Blockchain was rejected")
		}
	}
}
fn write_out() {
	os.write_file("block.dump",json.encode(blockchain)) or { return }
	os.write_file("users.dump",json.encode(user)) or { return }
}
fn main() {


	if !os.is_file("block.dump") {
		genesis()
	} else {
		contents:=os.read_file("block.dump") or { panic(err) }
		blockchain << json.decode([]Block, contents) or { return }

		users:=os.read_file("users.dump") or { panic(err) }
		users << json.decode([]UserBlock, users) or { return }
	}
	println(blockchain)
	println(users)
	

	
	mut server := net.listen_tcp(.ip6, ':4237')!
	laddr := server.addr()!

	eprintln('Listen on ${laddr} ...')
	for {
		mut socket := server.accept()!
		spawn handle_client(mut socket)
	}
	

}
fn handle_client(mut socket net.TcpConn) {
	defer {
		socket.close() or { panic(err) }
	}
	client_addr := socket.peer_addr() or { return }
	eprintln('> new client: ${client_addr}')
	mut reader := io.new_buffered_reader(reader: socket)
	defer {
		unsafe {
			reader.free()
		}
	}
	socket.write_string('Enter your public key: ') or { return }
	recv := reader.read_line() or { return }


	socket.write_string('> ') or { return }
	for {
		received_line := reader.read_line() or { 
			socket.write_string(blockchain.str()) or { return }
			return 
		}
		if received_line == "update" {
			socket.write_string("${blockchain.str()}\n> ") or { return }
		}
		if received_line == '' {
			socket.write_string(blockchain.str()) or { return }
			return 
		}
		handle_packet(received_line, ident, recv)
		println('client ${client_addr}: ${received_line}')
		write_out()
		socket.write_string("${blockchain.str()}\n> ") or { return }
	}
}