--
-- Advanced float handler
-- This is a "silent" plugin which extends float management
-- with controls over window placement etc.
--
-- Kept here as a means to start removing policy from tiler.lua
-- and letting more parts of the codebase be "opt out"
--

-- this hook isn't "safe", someone who calls attach is expecting
-- that the window will have a compliant state afterwards, but we
-- can hide
gconfig_register("advfloat_spawn", "auto");
gconfig_register("advfloat_hide", "statusbar");

local cactions = system_load("tools/advfloat/cactions.lua")();

local mode = gconfig_get("advfloat_spawn");
local pending, pending_vid;

local function setup_cursor_pick(wm, wnd)
	wnd:hide();
	pending = wnd;
	local w = math.ceil(wm.width * 0.15);
	local h = math.ceil(wm.height * 0.15);
	pending_vid = null_surface(w, h);
	link_image(pending_vid, mouse_state().cursor);
	image_sharestorage(wnd.canvas, pending_vid);
	blend_image(pending_vid, 1.0, 10);
	image_inherit_order(pending_vid, true);
	order_image(pending_vid, -1);
	nudge_image(pending_vid,
	mouse_state().size[1] * 0.75, mouse_state().size[2] * 0.75);
	shader_setup(pending_vid, "ui", "regmark", "active");
end

local function activate_pending(mx, my)
	if (not mx) then
		mx, my = mouse_xy();
	end

	if (pending.move) then
		pending:move(mx, my, false, true, true);
		pending:show();
	end
	delete_image(pending_vid);
	pending = nil;
end

local function wnd_attach(wm, wnd)
	wnd:ws_attach(true);
	if (wnd.wm.active_space.mode ~= "float") then
		return;
	end

	if (pending) then
		activate_pending();
		if (DURDEN_REGIONSEL_TRIGGER) then
			suppl_region_stop();
		end
	end

	if (mode == "cursor") then
		setup_cursor_pick(wm, wnd);
		iostatem_save();
		local col = null_surface(1, 1);
		mouse_select_begin(col);
		dispatch_meta_reset();
		dispatch_symbol_lock();
		durden_input = durden_regionsel_input;

-- the region setup and accept/fail is really ugly, but reworking it
-- right now is not really an option
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		DURDEN_REGIONSEL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
	elseif (mode == "draw") then
		setup_cursor_pick(wm, wnd);
		DURDEN_REGIONFAIL_TRIGGER = function()
			activate_pending();
			DURDEN_REGIONFAIL_TRIGGER = nil;
		end
		suppl_region_select(200, 198, 36, function(x1, y1, x2, y2)
			activate_pending(x1, y1);
			local w = x2 - x1;
			local h = y2 - y1;
			if (w > 64 and h > 64) then
				wnd:resize(w, h);
			end
		end);
	end
end

-- hook displays so we can decide spawn mode between things like
-- spawn hidden, cursor-click to position, draw to spawn
display_add_listener(
function(event, name, tiler, id)
	if (event == "added" and tiler) then
		tiler.attach_hook = wnd_attach;
	end
end
);

local function do_hide(wnd, tgt)
	if (tgt == "statusbar-left" or tgt == "statusbar-right") then
		local old_show = wnd.show;
		local btn;

-- deal with window being destroyed while we're hidden
		local on_destroy = function()
			if (btn) then
				btn:destroy();
			end
		end;

		local wm = wnd.wm;
		local pad = gconfig_get("sbar_tpad") * wm.scalef;
		local str = string.sub(tgt, 11);

-- actual button:
-- click: migrate+reveal
-- rclick: not-yet: select+popup
		btn = wm.statusbar:add_button(str, "sbar_item_bg",
			"sbar_item", wnd:get_name(), pad, wm.font_resfn, nil, nil,
			{
				click = function()
					local props = image_surface_resolve(btn.bg);
					wnd.show = old_show;
					wnd:drop_handler("destroy", on_destroy);
					btn:destroy();
					wnd.wm:switch_ws(wnd.space);
					wnd:select();
					if (#wm.on_wnd_hide > 0) then
						for k,v in ipairs(wm.on_wnd_hide) do
							v(wm, wnd, props.x, props.y, props.width, props.height, false);
						end
					else
						wnd:show();
					end
				end
			}
		);

-- out of VIDs
		if (not btn) then
			warning("hide-to-button: creation failed");
			return;
		end

-- safeguard against show being called from somewhere else
		wnd.show = function(wnd)
			if (btn.bg) then
				btn:click();
			else
				wnd.show = old_show;
				old_show(wnd);
			end
		end;

-- safeguard against window being destroyed while hidden
		wnd:add_handler("destroy", on_destroy);
		wnd:deselect();

-- event handler registered? (flair tool)
		if (#wm.on_wnd_hide > 0) then
			local props = image_surface_resolve(btn.bg);
			for k,v in ipairs(wm.on_wnd_hide) do
				v(wm, wnd, props.x, props.y, props.width, props.height, true);
			end
		else
			wnd:hide();
		end
	else
		warning("unknown hide target: " .. tgt);
	end
end

-- all_spaces_iter

shared_menu_register("window",
{
	kind = "action",
	name = "hide",
	label = "Hide",
	kind = "action",
	eval = function()
		return
			gconfig_get("advfloat_hide") ~= "disabled" and
				active_display().selected.space.mode == "float";
	end,
	handler = function()
		local wnd = active_display().selected;
		if (not wnd.hide) then
			return;
		end
		local tgt = gconfig_get("advfloat_hide");
		do_hide(wnd, tgt);
	end
});

global_menu_register("settings/wspaces/float",
{
	kind = "value",
	name = "spawn_action",
	initial = gconfig_get("advfloat_spawn"),
	label = "Spawn Method",
-- missing (split/share selected) or join selected
	set = {"click", "cursor", "draw", "auto"},
	handler = function(ctx, val)
		mode = val;
		gconfig_set("advfloat_spawn", val);
	end
});

global_menu_register("settings/wspaces/float",
{
	name = "action_region",
	kind = "action",
	submenu = true,
	label = "Action Region",
	handler = action_submenu
});

global_menu_register("settings/wspaces/float",
{
	kind = "value",
	name = "hide_target";
	initial = gconfig_get("advfloat_hide"),
	label = "Hide Target",
	set = {"disabled", "statusbar-left", "statusbar-right"},
	handler = function(ctx, val)
		gconfig_set("advfloat_hide", val);
	end
});

global_menu_register("settings/wspaces/float",
{
	kind = "value",
	name = "icons",
	label = "Icons",
	eval = function() return false; end,
	set = {"disabled", "global", "workspace"},
	initial = gconfig_get("advfloat_icon"),
	handler = function(ctx, val)
		gconfig_set("advfloat_icon", val);
	end
});
