-- Consulta o cps (cycles per second) atual do Tidal, através do REPL do
-- tidal.nvim, pra converter durações de sample (segundos) em fração de
-- ciclo (ex.: "1/8", "1/2", "2/1").
--
-- IMPORTANTE: tidal.nvim (skmecs) não expõe nenhuma API pública pra
-- "avaliar uma expressão e me devolver o resultado" — só send/send_line
-- (fire-and-forget). Pra capturar a saída do `getcps`, essa função mexe
-- em módulos INTERNOS do tidal.nvim (tidal.core.state, o Repl.buf), que
-- não são API pública/documentada. Se uma atualização futura do
-- tidal.nvim mudar esses internals, isso aqui simplesmente para de
-- funcionar silenciosamente (tudo protegido por pcall) — o resto do
-- plugin nunca depende de conseguir o cps: sempre cai de volta pra
-- mostrar a duração em segundos quando o cps não está disponível.

local M = {}

local last_cps = nil -- cache: último cps conhecido (número decimal, ex.: 0.5625)

--- Consulta o cps atual no GHCi (assíncrono, não bloqueia).
--- @param callback fun(cps: number|nil)? chamado quando a resposta chegar
--- (ou imediatamente com nil se não for possível consultar)
function M.refresh_cps(callback)
	local ok_state, state = pcall(require, "tidal.core.state")
	if not ok_state or not state.ghci then
		if callback then
			callback(nil)
		end
		return
	end

	-- tidal.nvim só cria o buffer de saída quando ":TidalNotification" é
	-- chamado manualmente. Sem ele, a saída do GHCi (onPassthrough) é
	-- descartada. Criamos um buffer escondido (sem abrir janela) só pra
	-- ter onde capturar a resposta.
	if not state.ghci.buf then
		local ok_buf = pcall(function()
			local Buffer = require("tidal.util.buffer")
			state.ghci.buf = Buffer.new({ scratch = true, listed = false })
		end)
		if not ok_buf then
			if callback then
				callback(nil)
			end
			return
		end
	end

	local bufnr = state.ghci.buf and state.ghci.buf.bufnr
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		if callback then
			callback(nil)
		end
		return
	end

	local line_count_before = vim.api.nvim_buf_line_count(bufnr)

	local ok_send = pcall(function()
		state.ghci:send_line("getcps")
	end)
	if not ok_send then
		if callback then
			callback(nil)
		end
		return
	end

	-- Tenta ler a resposta várias vezes ao longo de ~1.65s em vez de uma
	-- checagem única e cedo demais — o GHCi pode demorar bem mais que
	-- 300ms pra responder logo depois de bootar o Tidal, ou se estiver
	-- ocupado avaliando outra coisa.
	local attempts_left = 11 -- 11 * 150ms ≈ 1.65s
	local function try_read()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			if callback then
				callback(nil)
			end
			return
		end
		local new_line_count = vim.api.nvim_buf_line_count(bufnr)
		if new_line_count > line_count_before then
			-- Buffer:append (tidal.nvim) funde o início do texto recebido na
			-- última linha já existente (normalmente vazia); o conteúdo real
			-- pousa nela, não numa linha depois. Por isso lemos a partir de
			-- (line_count_before - 1).
			local lines =
				vim.api.nvim_buf_get_lines(bufnr, math.max(0, line_count_before - 1), new_line_count, false)
			for _, line in ipairs(lines) do
				-- getcps normalmente devolve um Rational via Data.Ratio, tipo "29 % 50"
				local num, den = line:match("(%-?%d+)%s*%%%s*(%-?%d+)")
				if num and den and tonumber(den) ~= 0 then
					last_cps = tonumber(num) / tonumber(den)
					if callback then
						callback(last_cps)
					end
					return
				end
				-- ou, dependendo da versão/config do Tidal, um Double puro, tipo "0.5625"
				local dec = line:match("^%s*(%-?%d+%.%d+)%s*$")
				if dec then
					last_cps = tonumber(dec)
					if callback then
						callback(last_cps)
					end
					return
				end
			end
			line_count_before = new_line_count
		end

		attempts_left = attempts_left - 1
		if attempts_left > 0 then
			vim.defer_fn(try_read, 150)
		else
			if callback then
				callback(nil)
			end
		end
	end

	vim.defer_fn(try_read, 150)
end

--- Último cps conhecido (cache). Pode ser nil se nunca consultado com
--- sucesso ainda. Não dispara nenhuma consulta nova.
function M.get_cached_cps()
	return last_cps
end

--- Igual a refresh_cps, mas narra cada etapa via vim.notify em vez de
--- falhar silenciosamente. Feito pra debugar quando refresh_cps não
--- funciona e não dá pra saber por quê.
function M.debug_refresh_cps()
	local function say(msg, level)
		vim.notify("[tidal_snipgen cps debug] " .. msg, level or vim.log.levels.INFO)
	end

	local ok_state, state = pcall(require, "tidal.core.state")
	if not ok_state then
		say("require('tidal.core.state') falhou: " .. tostring(state), vim.log.levels.ERROR)
		return
	end
	if not state.ghci then
		say("state.ghci é nil — o Tidal REPL está rodando? (tidal.nvim bootado?)", vim.log.levels.ERROR)
		return
	end
	say("state.ghci existe. buf já existia? " .. tostring(state.ghci.buf ~= nil))

	if not state.ghci.buf then
		local ok_buf, err_buf = pcall(function()
			local Buffer = require("tidal.util.buffer")
			state.ghci.buf = Buffer.new({ scratch = true, listed = false })
		end)
		if not ok_buf then
			say("falha ao criar buffer de captura: " .. tostring(err_buf), vim.log.levels.ERROR)
			return
		end
		say("buffer de captura criado, bufnr=" .. tostring(state.ghci.buf.bufnr))
	end

	local bufnr = state.ghci.buf and state.ghci.buf.bufnr
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		say("bufnr inválido: " .. tostring(bufnr), vim.log.levels.ERROR)
		return
	end

	local line_count_before = vim.api.nvim_buf_line_count(bufnr)
	say(string.format("bufnr=%d válido. linhas antes de enviar: %d", bufnr, line_count_before))

	local ok_send, err_send = pcall(function()
		state.ghci:send_line("getcps")
	end)
	if not ok_send then
		say("falha ao enviar 'getcps': " .. tostring(err_send), vim.log.levels.ERROR)
		return
	end
	say("'getcps' enviado. aguardando resposta (até ~3s)...")

	local attempts_left = 20 -- 20 * 150ms = 3s
	local function try_read()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			say("bufnr deixou de ser válido durante a espera", vim.log.levels.ERROR)
			return
		end
		local new_line_count = vim.api.nvim_buf_line_count(bufnr)
		if new_line_count > line_count_before then
			-- Buffer:append (tidal.nvim) funde o início do texto recebido na
			-- última linha já existente (normalmente vazia); o conteúdo real
			-- pousa nela, não numa linha depois. Por isso lemos a partir de
			-- (line_count_before - 1).
			local lines =
				vim.api.nvim_buf_get_lines(bufnr, math.max(0, line_count_before - 1), new_line_count, false)
			say(string.format("chegaram %d linha(s) novas: %s", #lines, vim.inspect(lines)))
			for _, line in ipairs(lines) do
				local num, den = line:match("(%-?%d+)%s*%%%s*(%-?%d+)")
				if num and den and tonumber(den) ~= 0 then
					last_cps = tonumber(num) / tonumber(den)
					say(string.format("cps extraído com sucesso: %.4f (de '%s')", last_cps, line))
					return
				end
				local dec = line:match("^%s*(%-?%d+%.%d+)%s*$")
				if dec then
					last_cps = tonumber(dec)
					say(string.format("cps extraído com sucesso: %.4f (de '%s')", last_cps, line))
					return
				end
			end
			-- Não bateu ainda — não desiste aqui. A resposta pode continuar
			-- chegando em partes (ex.: uma linha vazia antes do valor real).
			line_count_before = new_line_count
		end

		attempts_left = attempts_left - 1
		if attempts_left > 0 then
			vim.defer_fn(try_read, 150)
		else
			say("nenhuma linha nova chegou no buffer depois de ~3s", vim.log.levels.WARN)
		end
	end

	vim.defer_fn(try_read, 150)
end

--- Converte uma duração em segundos pra uma fração aproximada de ciclo,
--- dado um cps. Ex.: dur=0.5, cps=0.25 -> cycles=0.125 -> "1/8".
--- Retorna nil se não houver cps disponível (quem chamar deve então
--- mostrar a duração em segundos).
--- @param duration_seconds number
--- @param cps number|nil (default: último cps conhecido em cache)
--- @return string|nil
function M.duration_to_cycle_fraction(duration_seconds, cps)
	cps = cps or last_cps
	if not cps or cps <= 0 or not duration_seconds or duration_seconds < 0 then
		return nil
	end
	local cycles = duration_seconds * cps

	if cycles <= 0 then
		return "0/1"
	end

	if cycles < 1 then
		-- Sample mais curto que 1 ciclo: mostra como subdivisão "1/D"
		-- (o jeito usual de pensar nisso em livecoding: "esse sample é
		-- um oitavo de ciclo").
		local den = math.floor((1 / cycles) + 0.5)
		den = math.max(1, math.min(den, 32))
		return string.format("1/%d", den)
	end

	-- 1 ciclo ou mais: aproxima pro meio-ciclo mais próximo e mostra como
	-- "N/1" ou "N.5/1" — mais legível de bater o olho do que uma fração
	-- tecnicamente exata mas pouco intuitiva (ex.: prefere "4.5/1" a "9/2").
	local approx = math.floor(cycles * 2 + 0.5) / 2
	if approx == math.floor(approx) then
		return string.format("%d/1", math.floor(approx))
	end
	return string.format("%.1f/1", approx)
end

return M
