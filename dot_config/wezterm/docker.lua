-- See https://wezfurlong.org/wezterm/config/lua/ExecDomain.html#example-docker-domains
--
local wezterm = require("wezterm")
local M = {}

M.docker_list = function()
	local docker_list = {}
	local success, stdout, stderr = wezterm.run_child_process({
		"/usr/local/bin/docker",
		"container",
		"ls",
		"--format",
		"{{.ID}}:{{.Names}}",
	})
	for _, line in ipairs(wezterm.split_by_newlines(stdout)) do
		local id, name = line:match("(.-):(.+)")
		if id and name then
			docker_list[id] = name
			-- wezterm.log_info("name: " .. name)
		end
	end
	return docker_list
end

M.make_docker_label_func = function(id)
	return function(name)
		local success, stdout, stderr = wezterm.run_child_process({
			"docker",
			"inspect",
			"--format",
			"{{.State.Running}}",
			id,
		})
		local running = stdout == "true\n"
		local color = running and "Green" or "Red"
		return wezterm.format({
			{ Foreground = { AnsiColor = color } },
			{ Text = "docker container named " .. name },
		})
	end
end

M.make_docker_fixup_func = function(id)
	return function(cmd)
		cmd.args = cmd.args or { "/bin/sh" }
		local wrapped = {
			"docker",
			"exec",
			"-it",
			id,
		}
		for _, arg in ipairs(cmd.args) do
			table.insert(wrapped, arg)
		end

		cmd.args = wrapped
		return cmd
	end
end

M.compute_exec_domains = function()
	local exec_domains = {}
	for id, name in pairs(M.docker_list()) do
		table.insert(
			exec_domains,
			wezterm.exec_domain("docker:" .. name, M.make_docker_fixup_func(id), M.make_docker_label_func(id))
		)
	end
	return exec_domains
end

return M
