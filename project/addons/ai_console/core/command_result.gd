@tool
extends RefCounted
## Uniform result envelope shared by every AI Console command.
## Success: {"ok": true, "result": {...}}
## Failure: {"ok": false, "error": {"code": "...", "message": "...", "details": {...}}}
## Error messages are written for LLM self-correction: they state what went
## wrong AND what valid options exist.


static func ok(result: Dictionary = {}) -> Dictionary:
	return {"ok": true, "result": result}


static func err(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var error := {"code": code, "message": message}
	if not details.is_empty():
		error["details"] = details
	return {"ok": false, "error": error}
