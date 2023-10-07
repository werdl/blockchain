module main

import crypto.sha256
import time
import os
import net
import io
import json

struct Block {
	index int
	timestamp string
	data string
	mut: hash string
	prev_hash string
}


fn (b Block) calchash() string {
	record:=b.index.str()+b.timestamp+b.data+b.prev_hash
	return sha256.hexhash(record)
}
fn (oldblock Block) genblock(data string) Block {
	mut ret:=Block{
		index: oldblock.index+1
		timestamp: time.now().str()
		data: data
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
	} else {
		return true
	}
}

fn replacechain(newblocks []Block) {
	if newblocks.len > blockchain.len {
		blockchain=newblocks.clone()
	}
}
fn genesis() {
	blockchain << Block{
		index: 0
		timestamp: time.now().str()
		data: "\"I love deadlines. I love the whooshing noise they make as they go by.\" - Douglas Adams"
		prev_hash: ""
		hash: ""
	}
}
__global (
	blockchain []Block
)
fn handle_packet(data string) {
	blockchain << blockchain[blockchain.len-1].genblock(data)
	if blockchain.len>1 {
		if !blockchain[blockchain.len-1].isvalid(blockchain[blockchain.len-2]) {
			blockchain.pop()
			eprintln("Blockchain was rejected")
		}
	}
}
fn write_out() {
	os.write_file("block.dump",json.encode(blockchain)) or { return }
}
fn main() {
	if !os.is_file("block.dump") {
		genesis()
	} else {
		contents:=os.read_file("block.dump") or { panic(err) }
		blockchain << json.decode([]Block, contents) or { return }
	}
	println(blockchain)
	

	
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
		handle_packet(received_line)
		println('client ${client_addr}: ${received_line}')
		write_out()
		socket.write_string("${blockchain.str()}\n> ") or { return }
	}
}