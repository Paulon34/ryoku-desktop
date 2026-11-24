# Dolphin Sweet Ambar Blue — perfil opcional Ryoku

Este é o visual do Dolphin aprovado no notebook de desenvolvimento: fundo escuro/translúcido, texto branco, seleção azul e pastas **Papirus-Dark**. Os atalhos **Super+E** e **Super+Shift+F** já estão no arquivo `omarchy/bindings.lua` (integrado na [PR #2](https://github.com/Paulon34/ryoku-desktop/pull/2)) e iniciam o Dolphin com **Qt6ct/Kvantum** sem alterar o tema global do Omarchy.

**Licenças e segurança:** os arquivos Sweet e Papirus são de terceiros, **não são distribuídos** pelo Ryoku. Obtenha-os da fonte original, revise a licença de cada projeto e mantenha suas configurações privadas localmente.

## Instalar os arquivos do tema em nível de usuário

Requer Git e os pacotes Dolphin, Kvantum e qt6ct da sua instalação Omarchy/Arch. A partir de um terminal:

```bash
temp_dir="$(mktemp -d)"
git clone --depth 1 --branch Ambar-Blue \
  https://github.com/EliverLara/Sweet.git "$temp_dir/Sweet"

mkdir -p "$HOME/.config/Kvantum/Sweet-Ambar-Blue" \
  "$HOME/.local/share/color-schemes"

cp "$temp_dir/Sweet/kde/kvantum/Sweet-Ambar-Blue/"* \
  "$HOME/.config/Kvantum/Sweet-Ambar-Blue/"

cp "$temp_dir/Sweet/kde/colorschemes/SweetAmbarBlue.colors" \
  "$HOME/.local/share/color-schemes/"

rm -rf -- "$temp_dir"
```

Atenção: se você já personalizou esses dois destinos, **faça backup antes do `cp`**. Os comandos só instalam arquivos no diretório pessoal; não selecionam o tema para todo o Omarchy.

## Escolher o estilo

1. Abra `kvantummanager`, selecione **Sweet-Ambar-Blue** como tema ativo.
2. Abra `QT_QPA_PLATFORMTHEME=qt6ct qt6ct` e configure **Kvantum**, esquema de cores Sweet Ambar Blue e os ícones **Papirus-Dark**, se disponíveis. Essas preferências do Qt6ct/Kvantum podem alcançar **outros apps Qt que usem Qt6ct**, embora os atalhos Ryoku só imponham o ambiente ao Dolphin.
3. Se necessário, no KDE/Dolphin, selecione o esquema Sweet Ambar Blue. Na instalação testada, foi usado `kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme SweetAmbarBlue`, após backup do `~/.config/dolphinrc`.
4. Teste isoladamente:

```bash
QT_QPA_PLATFORMTHEME=qt6ct QT_STYLE_OVERRIDE=kvantum /usr/bin/dolphin --new-window
```

Depois de validar, instale ou atualize os atalhos Ryoku com `python3 manage-bindings.py apply && hyprctl reload` **a partir da pasta `omarchy/`**, feche janelas antigas e abra com **Super+E**. O efeito de blur/transparência depende do Kvantum e compositor.

## Reversão

Para retirar somente os atalhos Ryoku: `python3 manage-bindings.py remove && hyprctl reload` (na pasta `omarchy/`). Isso remove **todos os atalhos gerenciados pelo bloco Ryoku**, não apenas o Dolphin. Para voltar atrás apenas na aparência do Dolphin, use os backups dos arquivos `dolphinrc`, `qt6ct.conf`, `kvantum.kvconfig` e os próprios ajustes no Qt6ct/Kvantum.

Não publique seus dotfiles inteiros, chaves nem perfis pessoais. Nenhuma modificação de SDDM, GPU, PAM ou login é feita aqui.
