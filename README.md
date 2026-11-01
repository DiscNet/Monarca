# Monarca — Roblox Script Hub

Script Hub em **Luau**, com interface escura, abas Home/Visual/Player/Settings e layout adaptável a telas pequenas. Primeira versão: **0.1.0**.

## Executar

Em um ambiente que ofereça `game:HttpGet` e `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DiscNet/Monarca/main/Monarca.lua"))()
```

**Importante:** este projeto não é uma função oficial do Roblox. A execução por software de terceiros pode violar as regras do Roblox, e a compatibilidade varia por ambiente. Não introduza credenciais, tokens ou dados pessoais no Hub. Execute apenas código confiável.

## Estrutura

- `Monarca.lua` — interface principal, navegação, controles, animações, salvamento e ciclo de vida.
- `assets/monarca-icon.jpg` — imagem oficial roxa do Monarca, adaptada para 128×128 px para a interface.
- `assets/arise-intro.mp3` — efeito sonoro de abertura enviado pelo usuário, em versão MP3 otimizada.
- `manifest.lua` — catálogo de módulos remotos aprovados.
- `modules/fullbright.lua` — iluminação ajustada apenas neste cliente.
- `modules/lowgraphics.lua` — redução local de efeitos visuais pesados.
- `modules/crosshair.lua` — mira roxa visual, apenas na tela local.
- `modules/xray.lua` — contorno roxo dos outros personagens através de paredes.
- `modules/esp.lua` — etiquetas com apelido e distância até outros personagens.
- `modules/timecycle.lua` — ajuste local de horário (Dia/Noite/Padrão).
- `modules/nofog.lua` — remoção local de neblina e névoa atmosférica.

## Funcionalidades

- Janela arrastável (mouse/toque), minimizável e que se ajusta à resolução.
- Animação de inicialização com transição de escala, barra de carregamento, mensagens de progresso e entrada suave do painel após a sincronização inicial.
- Áudio **Arise** reproduzido uma vez ao executar, quando o ambiente oferecer `writefile` e `getcustomasset`/`getsynasset`. Se o executor bloquear áudio local, a interface inicia normalmente sem som; não toca ao reabrir o ícone flutuante.
- Ícone oficial **exclusivamente no botão flutuante**. Quando disponíveis `writefile` e `getcustomasset` ou `getsynasset`, o Hub baixa e guarda automaticamente a imagem do repositório. Sem essas APIs, exibe a letra **M** como alternativa.
- Aba **Visual** com controles organizados por Personagens, Iluminação, Interface e Desempenho.
- **X-Ray**: destaca personagens de outros jogadores através de obstáculos; **ESP**: exibe apelido e distância.
- **Horário**: opções Padrão/Dia/Noite, com restauração ao desligar; Fullbright e Sem neblina são independentes.
- **Mira roxa** e **Gráficos leves**, com ativação local e reversível.
- Controles locais de FOV, velocidade e salto; mudanças podem ser revertidas pelo jogo/servidor.
- Botões, sliders, toggles, menus e notificações de status.
- Preferências salvas em `Monarca/settings.json` apenas se o ambiente possuir `writefile`/`readfile`; caso contrário, valem na sessão.
- Botão **Atualizar** baixa novamente `manifest.lua` e recarrega o catálogo; os módulos são baixados do GitHub sob demanda.

## Adicionar um módulo

1. Crie `modules/meu_modulo.lua`. Ele deve retornar uma tabela com os métodos `enable(self)` e `disable(self)`.
2. Insira no `manifest.lua`: `{ id = "meu_modulo", name = "Nome", description = "Descrição", category = "Visual", group = "Interface" }`.
3. No Hub, abra **Visual → Atualizar**.

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

## Observações visuais

X-Ray e ESP não alteram personagens no servidor. O ESP atualiza distâncias a cada 0,2 s e limita etiquetas a 500 studs. A renderização de Highlight pode ter limites do próprio Roblox. Mapas que sobrescrevem a iluminação ou bloqueiam efeitos podem reduzir a eficácia dos controles. As opções podem ser incompatíveis com as regras de algumas experiências.
