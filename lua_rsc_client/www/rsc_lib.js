function rsc_lib(base_url) {
	let make_cmd_xhr = (cmd) => {
		let req = new XMLHttpRequest()
		req.open("POST", base_url + (new URLSearchParams(cmd)).toString(), true)
		req.send(null)
		let resp = JSON.parse(req.responseText);
		if (req.status === 200) {
			return resp
		} else {
			throw new Error("API returned error: " + resp.err)
		}
	}
	this.set_block = (block_id, x,y,z) => {
		return make_cmd_xhr({command: "set_block", x:x, y:y, z:z, block_id:block_id})
	}
	this.get_block = (x,y,z) => {
		return make_cmd_xhr({command: "get_block", x:x, y:y, z:z})
	}
	this.observe_block = (x,y,z) => {
		return make_cmd_xhr({command: "observe_block", x:x, y:y, z:z})
	}
	this.update_block = (x,y,z) => {
		return make_cmd_xhr({command: "update_block", x:x, y:y, z:z})
	}
	this.freeze = () => {
		return make_cmd_xhr({command: "freeze"})
	}
	this.unfreeze = () => {
		return make_cmd_xhr({command: "unfreeze"})
	}
	this.step = (n) => {
		return make_cmd_xhr({command: "step", n:n})
	}
}
