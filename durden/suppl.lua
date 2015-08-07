-- Copyright: None claimed, Public Domain
-- Description: Cookbook- style functions for the normal tedium
-- (string and table manipulation, mostly plucked from the AWB
-- project)

function string.split(instr, delim)
	local res = {};
	local strt = 1;
	local delim_pos, delim_stp = string.find(instr, delim, strt);

	while delim_pos do
		table.insert(res, string.sub(instr, strt, delim_pos-1));
		strt = delim_stp + 1;
		delim_pos, delim_stp = string.find(instr, delim, strt);
	end

	table.insert(res, string.sub(instr, strt));
	return res;
end

function string.utf8back(src, ofs)
	if (ofs > 1 and string.len(src)+1 >= ofs) then
		ofs = ofs - 1;
		while (ofs > 1 and utf8kind(string.byte(src,ofs) ) == 2) do
			ofs = ofs - 1;
		end
	end

	return ofs;
end

function string.utf8forward(src, ofs)
	if (ofs <= string.len(src)) then
		repeat
			ofs = ofs + 1;
		until (ofs > string.len(src) or
			utf8kind( string.byte(src, ofs) ) < 2);
	end

	return ofs;
end

function string.utf8lalign(src, ofs)
	while (ofs > 1 and utf8kind(string.byte(src, ofs)) == 2) do
		ofs = ofs - 1;
	end
	return ofs;
end

function string.utf8ralign(src, ofs)
	while (ofs <= string.len(src) and string.byte(src, ofs)
		and utf8kind(string.byte(src, ofs)) == 2) do
		ofs = ofs + 1;
	end
	return ofs;
end

function string.translateofs(src, ofs, beg)
	local i = beg;
	local eos = string.len(src);

	-- scan for corresponding UTF-8 position
	while ofs > 1 and i <= eos do
		local kind = utf8kind( string.byte(src, i) );
		if (kind < 2) then
			ofs = ofs - 1;
		end

		i = i + 1;
	end

	return i;
end

function string.utf8len(src, ofs)
	local i = 0;
	local rawlen = string.len(src);
	ofs = ofs < 1 and 1 or ofs

	while (ofs <= rawlen) do
		local kind = utf8kind( string.byte(src, ofs) );
		if (kind < 2) then
			i = i + 1;
		end

		ofs = ofs + 1;
	end

	return i;
end

function string.insert(src, msg, ofs, limit)
	local xlofs = src:translateofs(ofs, 1);
	if (limit == nil) then
		limit = string.len(msg) + ofs;
	end

	if ofs + string.len(msg) > limit then
		msg = string.sub(msg, 1, limit - ofs);

-- align to the last possible UTF8 char..

		while (string.len(msg) > 0 and
			utf8kind( string.byte(msg, string.len(msg))) == 2) do
			msg = string.sub(msg, 1, string.len(msg) - 1);
		end
	end

	return string.sub(src, 1, xlofs - 1) .. msg ..
		string.sub(src, xlofs, string.len(src)), string.len(msg);
end

function string.delete_at(src, ofs)
	local fwd = string.utf8forward(src, ofs);
	if (fwd ~= ofs) then
		return string.sub(src, 1, ofs - 1) .. string.sub(src, fwd, string.len(src));
	end

	return src;
end

function string.trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function string.utf8back(src, ofs)
	if (ofs > 1 and string.len(src)+1 >= ofs) then
		ofs = ofs - 1;
		while (ofs > 1 and utf8kind(string.byte(src,ofs) ) == 2) do
			ofs = ofs - 1;
		end
	end

	return ofs;
end


function table.remove_match(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in ipairs(tbl) do
		if (v == match) then
			table.remove(tbl, k);
			return v;
		end
	end

	return nil;
end

function table.remove_vmatch(tbl, match)
	if (tbl == nil) then
		return;
	end

	for k,v in pairs(tbl) do
		if (v == match) then
			tbl[k] = nil;
			return v;
		end
	end

	return nil;
end

-- will return ctx (initialized if nil in the first call), to track state
-- between calls iotbl matches the format from _input(iotbl) and sym should be
-- the symbol table lookup. The redraw(ctx, caret_only) will be called when
-- the caller should update whatever UI component this is used in
function text_input(ctx, iotbl, sym, redraw, opts)
	ctx = ctx == nil and {
		caretpos = 1,
		limit = -1,
		chofs = 1,
		ulim = VRESW,
		msg = "",
		caret_left   = SYSTEM_KEYS["caret_left"],
		caret_right  = SYSTEM_KEYS["caret_right"],
		caret_down   = SYSTEM_KEYS["caret_down"],
		caret_home   = SYSTEM_KEYS["caret_home"],
		caret_end    = SYSTEM_KEYS["caret_end"],
		caret_delete = SYSTEM_KEYS["caret_delete"],
		caret_erase  = SYSTEM_KEYS["caret_erase"]
	} or ctx;

	local caretofs = function()
		if (ctx.caretpos - ctx.chofs + 1 > ctx.ulim) then
				ctx.chofs = string.utf8lalign(ctx.msg, ctx.caretpos - ctx.ulim);
		end
	end

	if (iotbl.active == false) then
		return ctx;
	end

	if (sym == ctx.caret_home) then
		ctx.caretpos = 1;
		ctx.chofs    = 1;
		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_end) then
		ctx.caretpos = string.len( ctx.msg ) + 1;
		ctx.chofs = ctx.caretpos - ctx.ulim;
		ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
		ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);

		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_left) then
		ctx.caretpos = string.utf8back(ctx.msg, ctx.caretpos);

		if (ctx.caretpos < ctx.chofs) then
			ctx.chofs = ctx.chofs - ctx.ulim;
			ctx.chofs = ctx.chofs < 1 and 1 or ctx.chofs;
			ctx.chofs = string.utf8lalign(ctx.msg, ctx.chofs);
		end

		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_right) then
		ctx.caretpos = string.utf8forward(ctx.msg, ctx.caretpos);
		if (ctx.chofs + ctx.ulim <= ctx.caretpos) then
			ctx.chofs = ctx.chofs + 1;
			caretofs();
			redraw(ctx);
		else
			caretofs();
			redraw(ctx, caret);
		end

	elseif (sym == ctx.caret_delete) then
		ctx.msg = string.delete_at(ctx.msg, ctx.caretpos);
		caretofs();
		redraw(ctx);

	elseif (sym == ctx.caret_erase) then
		if (ctx.caretpos > 1) then
			ctx.caretpos = string.utf8back(ctx.msg, ctx.caretpos);
			if (ctx.caretpos <= ctx.chofs) then
				ctx.chofs = ctx.caretpos - ctx.ulim;
				ctx.chofs = ctx.chofs < 0 and 1 or ctx.chofs;
			end

			ctx.msg = string.delete_at(ctx.msg, ctx.caretpos);
			caretofs();
			redraw(ctx);
		end

	else
		local keych = iotbl.utf8;
		if (keych == nil or keych == '') then
			return ctx;
		end

		ctx.msg, nch = string.insert(ctx.msg,
			keych, ctx.caretpos, ctx.nchars);
		ctx.caretpos = ctx.caretpos + nch;
		caretofs();
		redraw(ctx);
	end

	return ctx;
end

-- add m2 to m1, overwrite on collision
function merge_menu(m1, m2)
	local kt = {};
	local res = {};
	if (m2 == nil) then
		return m1;
	end

	if (m1 == nil) then
		return m2;
	end

	for k,v in ipairs(m1) do
		kt[v.name] = k;
		table.insert(res, v);
	end

	for k,v in ipairs(m2) do
		if (kt[v.name]) then
			res[kt[v.name]] = v;
		else
			table.insert(res, v);
		end
	end
	return res;
end

local menu_hook = nil;
local path = nil;
local function lbar_fun(ctx, instr, done, lastv)
	if (done) then
		local tgt = nil;
		for k,v in ipairs(ctx.list) do
			if (v.label == instr) then
				tgt = v;
			end
		end
		if (tgt == nil) then
			return;
		end

		if (tgt.validator) then
			if (not tgt.validator(ctx, instr)) then
				return false;
			end
		end

-- a little odd combination, used to manually build a path to a specific menu
-- item for shortcuts. handler_hook needs to be set and either meta+submenu or
-- just non-submenu for the hook to be called instead of the default handler
		if (tgt.kind == "action") then
			path = path and (path .. "/" .. tgt.name) or tgt.name;
			local m1, m2 = dispatch_meta();

			if (menu_hook and
				(tgt.submenu and m1 or not tgt.submenu)) then
					menu_hook(path);
					menu_hook = nil;
					path = "";
					return;
			elseif (tgt.handler) then
				return tgt.handler(ctx.handler, instr, ctx);
			end
		end
		return;
	end

	local res = {};
	local mlbl = gconfig_get("lbar_menulblstr");
	local msellbl = gconfig_get("lbar_menulblselstr");

-- match empty or case-insensitive
	for i,v in ipairs(ctx.list) do
		if (instr == nil or string.len(instr) == 0 or
			string.lower(string.sub(v.label, 1, string.len(instr))) ==
			string.lower(instr)) then
			if ((v.eval == nil or v.eval(ctx, instr)) and
				(ctx.show_invisible or not v.invisible)) then
				if (v.submenu) then
					table.insert(res, {mlbl, msellbl, v.label});
				else
					table.insert(res, v.label);
				end
			end
		end
	end

	return {set = res, valid = false};
end

--
-- ctx is expected to contain:
--  list [# of {name, label, kind, validator, handler}]
--  + any data the handler might need
--
function launch_menu(wm, ctx, fcomp, label, opts)
	if (ctx == nil or ctx.list == nil or #ctx.list == 0) then
		return;
	end

	opts = opts and opts or {};
	opts.force_completion = fcomp;
	opts.label = label;

	local bar = wm:lbar(lbar_fun, ctx, opts);
	return bar;
end

-- set a temporary hook that will override menu navigation
-- and instead send the path to the specified function one time
function launch_menu_hook(fun)
	menu_hook = fun;
	path = nil;
end

--
-- navigate a tree of submenus to reach a specific function without performing
-- the visual / input triggers needed, used to provide the same interface for
-- keybinding as for setup. gfunc should be a menu spawning function.
--
function launch_menu_path(wm, gfunc, pathdescr)
	local elems = string.split(pathdescr, "/");
	local cl = ctx;
	local old_launch = launch_menu;
	launch_menu = function(wm, ctx, fcomp, label)
		cl = ctx;
	end

	gfunc();

	for i,v in ipairs(elems) do
		local found = false;

		for m,n in ipairs(cl.list) do
			if (n.name == v) then
				found = n;
				break;
			end
		end
		if (not found) then
			warning(string.format(
				"run_menu_path(%s) failed at index %d", pathdescr, i));
			launch_menu = old_launch;
			return;
		else
			if (found.handler == nil) then
				warning("missing handler for: " .. found.name);
			elseif (found.submenu) then
				launch_menu = i == #elems and old_launch or launch_menu;
				found.handler(); -- will call launch_menu that will update cl
			else
				launch_menu = old_launch;
				found.handler(cl.handler, "", cl); -- is reserved for when we support vals
				return;
			end
		end
	end

	launch_menu = old_launch;
end
