-- Ryoku: apenas atalhos pessoais. Nao altera shell, tema, layout ou monitores.
-- Base: Omarchy 4.x com API Lua o.rebind / hl.dsp.
-- As acoes de compositor sao executadas no momento da tecla.
local function dispatch(make)
  return function() return hl.dispatch(make()) end
end
-- Dolphin e o gerenciador de arquivos preferido no Ryoku (nao depende do launcher Nautilus).
o.rebind("SUPER + E", "Arquivos (Dolphin)", { launch = "dolphin" })
o.rebind("SUPER + SHIFT + F", "Arquivos (Dolphin)", { launch = "dolphin" })
o.rebind("SUPER + SPACE", "Aplicativos", "omarchy-shell omarchy.dock apps")
o.rebind("SUPER + ALT + SPACE", "Menu Omarchy", { menu = "root" })
o.rebind("SUPER + Q", "Fechar janela", dispatch(function() return hl.dsp.window.close() end))
o.rebind("SUPER + F", "Tela cheia", dispatch(function() return hl.dsp.window.fullscreen({ mode = "fullscreen" }) end))
o.rebind("SUPER + V", "Alternar janela flutuante", dispatch(function() return hl.dsp.window.float({ action = "toggle" }) end))
o.rebind("SUPER + W", "Escolher wallpaper", { menu = "background" })
o.rebind("SUPER + C", "Historico da area de transferencia", { panel = "omarchy.clipboard" })
o.rebind("SUPER + X", "Menu de energia", { menu = "system" })
o.rebind("SUPER + SHIFT + X", "Bloquear sessao", "omarchy-system-lock")
o.rebind("SUPER + SHIFT + E", "Menu de sessao", { menu = "system" })
o.rebind("SUPER + I", "Configuracoes Omarchy", { menu = "root" })
o.rebind("SUPER + comma", "Configuracoes Omarchy", { menu = "root" })
o.rebind("SUPER + N", "Historico de notificacoes", { ipc = "notifications.showHistory" })
o.rebind("PRINT", "Capturar regiao", "omarchy-capture-screenshot region")
o.rebind("SUPER + PRINT", "Capturar tela inteira", "omarchy-capture-screenshot fullscreen")
-- Estilo Windows: SUPER+L bloqueia a sessao (nao suspende).
-- O layout segue acessivel pelo atalho nativo SUPER+ALT+L (ciclo reverso)
-- e pelo menu Appearance > Workspace Layout.
o.rebind("SUPER + L", "Bloquear sessao", "omarchy-system-lock")
for key, direction in pairs({ H = "l", J = "d", K = "u" }) do
  local d = direction
  o.rebind("SUPER + " .. key, "Mover foco " .. d, dispatch(function() return hl.dsp.focus({ direction = d }) end))
  o.rebind("SUPER + SHIFT + " .. key, "Trocar janela " .. d, dispatch(function() return hl.dsp.window.swap({ direction = d }) end))
end
-- Preserva a troca da janela para direita sem sequestrar SUPER+L.
o.rebind("SUPER + SHIFT + L", "Trocar janela r", dispatch(function() return hl.dsp.window.swap({ direction = "r" }) end))
-- Disponibiliza a ajuda que saiu de SUPER+K sem retirar o atalho do tmux.
o.rebind("SUPER + ALT + SHIFT + K", "Ajuda de atalhos", "omarchy-menu-keybindings")
-- SUPER+RETURN, setas, numericos, mouse e teclas multimidia ficam no upstream.
-- Os workspaces por monitor do Omarchy ficam intactos.
