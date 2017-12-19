-- Grid-Cell positioning tool, "inspired" by the Compiz grid plugin.
-- It divides the window into a non-uniform 3x3 imaginary grid, where
-- you assign a window to a grid- region. Repeated assignments within
-- a short timeframe will subdivide the cell into a new 3x3 grid and so
-- on.
--
-- ind match number
-- 7(nw) 8(n) 9(ne)
-- 4( w) 5(c) 6( e)
-- 1(sw) 2(s) 3(se)
--
-- time since last activation determine depth so that it can be repeated,
-- an option would be to track allocation here and use that to determine
-- fair split, but then we might aswell re-use the tiling mode and an auto
-- layouter
local function grid_cell_ent(dir, lbl, x1, y1, x2, y2)
	return {
		name = dir,
		label = lbl,
		description = "Fit within a 9-cell grid in the " .. lbl .. " direction",
		kind = "action",
		eval = function()
			return active_display().selected and
				active_display().selected.space.mode == "float";
		end,

-- relevel or dig deeper based on how much time as elapsed or if the window
-- has moved since it was activated
		handler = function()
			local wm = active_display();
			local wnd = active_display().selected;
			local rel = false;

-- keep or drop history based on how much time has elased since last
-- (the timeout is mostly a slight convenience)
			if (wnd.grid_meta and #wnd.grid_meta >= 1) then
				rel = CLOCK - wnd.grid_meta[#wnd.grid_meta].clock < 200;
				if (not rel) then
					wnd.grid_meta = {};
				end
			else
				wnd.grid_meta = {};
			end

			local xp = 0;
			local yp = 0;
			local w = wm.effective_width;
			local h = wm.effective_height;

			if (rel) then
				local ms = wnd.grid_meta[#wnd.grid_meta];
				xp = ms.x;
				yp = ms.y;
				w = ms.w;
				h = ms.h;
			end
			xp = xp + x1 * w;
			yp = yp + y1 * h;
			w = (x2 - x1) * w;
			h = (y2 - y1) * h;

			table.insert(wnd.grid_meta, {
				clock = CLOCK,
				lx = wnd.x,
				ly = wnd.y,
				lw = wnd.width,
				lh = wnd.height,
				x = xp,
				y = yp,
				w = w,
				h = h
			});

			wnd:move(xp, yp, true, true);
			wnd:resize(w, h);
		end
	};
end

return {
	grid_cell_ent("sw", "South-West", 0.00, 0.5, 0.5, 1.00),
	grid_cell_ent("s", "South", 0.0, 0.5, 1.0, 1.00),
	grid_cell_ent("se", "South-East", 0.5, 0.5, 1.00, 1.00),
	grid_cell_ent("w", "West", 0.0, 0.0, 0.5, 1.0),
	grid_cell_ent("c", "Center", 0.0, 0.0, 1.0, 1.0),
	grid_cell_ent("e", "East", 0.5, 0.0, 1.00, 1.00),
	grid_cell_ent("nw", "North-West", 0,00, 0.00, 0.5, 0.5),
	grid_cell_ent("n", "North", 0.0, 0.00, 1.0, 0.5),
	grid_cell_ent("ne", "North-East", 0.5, 0.00, 1.00, 0.5),
	{
		name = "back",
		label = "Back",
		description = "Undo the last grid- fit action",
		kind = "action",
		handler = function()
			local wnd = active_display().selected;
			if (not wnd or not wnd.grid_meta or #wnd.grid_meta < 1) then
				return;
			end
			local last = table.remove(wnd.grid_meta, #wnd.grid_meta);
			wnd:move(last.x, last.y, true, true);
			wnd:resize(last.w, last.h);
		end,
	}
};
