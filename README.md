# Monarca — Roblox Script Hub

Script Hub em **Luau**, com interface escura, abas Home/Scripts/Player/Settings e layout adaptável a telas pequenas. Primeira versão: **0.1.0**.

## Executar

Em um ambiente que ofereça `game:HttpGet` e `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DiscNet/Monarca/main/Monarca.lua"))()
```

**Importante:** este projeto não é uma função oficial do Roblox. A execução por software de terceiros pode violar as regras do Roblox, e a compatibilidade varia por ambiente. Não introduza credenciais, tokens ou dados pessoais no Hub. Execute apenas código confiável.

## Estrutura

- `Monarca.lua` — interface principal, navegação, controles, animações, salvamento e ciclo de vida.
- `manifest.lua` — catálogo de módulos remotos aprovados.
- `modules/fullbright.lua` — iluminação ajustada apenas neste cliente.
- `modules/lowgraphics.lua` — redução local de efeitos visuais pesados.
- `modules/crosshair.lua` — mira visual, apenas na tela local.

## Funcionalidades

- Janela arrastável (mouse/toque), minimizável e que se ajusta à resolução.
- Busca e filtro de scripts, com ativação e desativação dos módulos.
- Controles locais de FOV, velocidade e salto; mudanças podem ser revertidas pelo jogo/servidor.
- Botões, sliders, toggles, menus e notificações de status.
- Preferências salvas em `Monarca/settings.json` apenas se o ambiente possuir `writefile`/`readfile`; caso contrário, valem na sessão.
- Botão **Atualizar catálogo** baixa novamente `manifest.lua` e recarrega o catálogo; os módulos são baixados do GitHub sob demanda.

## Adicionar um módulo

1. Crie `modules/meu_modulo.lua`. Ele deve retornar uma tabela com os métodos `enable(self)` e `disable(self)`.
2. Insira no `manifest.lua`: `{ id = "meu_modulo", name = "Nome", description = "Descrição", category = "Utilidades" }`.
3. No Hub, abra **Scripts → Atualizar**.

Os IDs de módulos são limitados a letras minúsculas, números, `_` e `-`; nenhum endereço externo é aceito pelo manifesto. O Hub só carrega `modules/<id>.lua` deste repositório.

Exemplo:

```lua
local M = {}
function M:enable()
    -- Aplicar efeito apenas neste cliente
end
function M:disable()
    -- Reverter alterações e desconectar eventos
end
return M
```

Módulos atualizados entram em vigor depois de desligar/ligar o módulo ou atualizar o catálogo. O botão de atualização desliga os módulos antes de carregar suas novas versões.

## Limites e testes

Código-fonte não equivale a teste em Roblox em execução. Verifique em um ambiente de teste antes do uso. A execução de código remoto exige `loadstring` e `game:HttpGet`; o arquivo de configuração exige APIs de arquivos não padronizadas. O projeto não contém recursos para perturbar outros jogadores, contornar anticheat ou acessar dados de terceiros.
