# Monarca — Roblox Script Hub

Script Hub em **Luau**, com interface escura, abas **Home/Alvo/Visual/Player/Emote/666/Settings** e layout adaptável ao Android. Versão atual: **0.6.7**.

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
- `modules/player_fly.lua` — voo local de 5–160 studs/s na direção completa da câmera. Joystick/WASD para avançar, subir e descer conforme o ângulo de visão; rotação corporal com pitch/roll e aceleração suave. Não mostra comandos SUBIR/DESCER.
- `modules/zombie_r6.lua` — emote R6 corrigido: braços à frente, pernas alternadas no plano de caminhada; reprodução FE por animação publicada quando autorizada, ou alternativa local.
- `modules/pose_666.lua` — animação R6 local aprimorada: postura menos inclinada, braços soltos, idle com respiração e oscilação, caminhada com passos mais expressivos e transição idle/walk gradual.
- `modules/headless_local.lua` — controle independente `</>`: oculta apenas `Head` e decals/texturas do rosto no cliente por `LocalTransparencyModifier`, mantendo cabelos/acessórios e restaurando tudo ao desativar.
- `modules/korblox_right_leg.lua` — opção alternável de prévia **local e reversível** da perna direita original do Korblox Deathspeaker (asset Roblox `139607718`). No R15 preserva o **tamanho nativo de cada `MeshPart`** da geometria Korblox (sem esticá-la até as dimensões da perna anterior) e alinha as peças por `RightHipRigAttachment`, `RightKneeRigAttachment` e `RightAnkleRigAttachment`. No R6 mantém `CharacterMesh`. Não concede propriedade do item e depende de o carregamento desse asset ser permitido pela experiência.
- `server/MonarcaRigSwitch.server.lua` — integração **opcional** para experiências próprias; cria um novo personagem R6/R15 no servidor e retorna sucesso/erro ao painel.
- `studio/GenerateZombieR6Animation.lua` — gera no Roblox Studio um `KeyframeSequence` original para publicação como asset de animação.


## Identidade visual

O layout de Monarca v0.3 foi alinhado aos princípios do `kxlynn666/SkyNetApi`, especialmente ao `public/design-system-v15.css`: superfícies quase pretas (`#050506`/`#0b0b0d`), texto claro (`#f4f4f0`), divisórias cinza finas (`#252529`) e acento violeta discreto (`#8e82e8`). A navegação utiliza abas horizontais de texto com indicador inferior para preservar espaço no Android. Os controles de Player e Settings usam linhas separadoras, em vez de caixas repetidas. A curvatura externa de 8 px foi preservada conforme as diretrizes do Monarca.

A tipografia usa Gotham, disponível no Roblox, como aproximação da hierarquia do site, que usa IBM Plex Sans. Não existe dependência entre os dois projetos: a referência é somente visual. A imagem roxa personalizada continua exclusiva do ícone flutuante e a abertura com barra de carregamento permanece.

Na revisão **v0.4.1**, Headsit e Backpack passaram a usar attachments e constraints físicos, a orientação de Headsit foi corrigida e View passou à terceira pessoa, com restauração da câmera original. A interface da aba Alvo foi preservada.

Na revisão **v0.3.1**, linhas finas brancas translúcidas e indicador branco de aba ativa complementam os detalhes roxos. Os botões de ação principal também passam a usar branco. Somente **Visual, Player e Settings** receberam controles tipográficos menores, divisórias leves e mais espaço entre opções e categorias; o layout do **Home permanece inalterado**. A interface geral continua com janela compacta e raio de 8 px.


## Funcionalidades

- Janela arrastável (mouse/toque), minimizável e que se ajusta à resolução.
- Animação de inicialização com transição de escala, barra de carregamento, mensagens de progresso e entrada suave do painel após a sincronização inicial.
- Áudio **Arise** reproduzido uma vez ao executar, quando o ambiente oferecer `writefile` e `getcustomasset`/`getsynasset`. Se o executor bloquear áudio local, a interface inicia normalmente sem som; não toca ao reabrir o ícone flutuante.
- Ícone oficial **exclusivamente no botão flutuante**. Quando disponíveis `writefile` e `getcustomasset` ou `getsynasset`, o Hub baixa e guarda automaticamente a imagem do repositório. Sem essas APIs, exibe a letra **M** como alternativa.
- Aba **Alvo**: pesquisa outros jogadores por **Nick/Username**, **DisplayName/apelido**, prefixos, trechos do nome e aproximação ortográfica; oferece quatro sugestões selecionáveis, avatar compacto, Nick, apelido, ID e distância.
- **Headsit**: acompanha o jogador acima da cabeça, com **mesma direção do rosto** do alvo; **Backpack**: mantém a posição nas costas, voltado para trás. Ambos usam `AlignPosition`/`AlignOrientation` entre attachments e não reposicionam mais o `HumanoidRootPart` manualmente a cada frame. Colisões do personagem local são temporariamente desligadas e restauradas ao desativar.
- **Follow**: movimentação com `Humanoid:MoveTo` atualizada continuamente enquanto estiver habilitada; pode ser impedida por obstáculos.
- **View**: usa `CameraType.Custom` e `CameraSubject` no Humanoid do alvo, com `CameraMode.Classic` e zoom de terceira pessoa entre 7 e 18 studs. Não reproduz a câmera particular do outro jogador; ao desativar, restaura câmera, foco, modo e limites de zoom anteriores.
- **TP**: **ação por clique**, teletransporte pontual para perto do alvo. Não é alternável nem permanece ativo.
- Estados dos botões de Alvo: fundo preto e contorno branco quando desligados; branco com texto preto e halo discreto quando ligados; cantos de 2 px. Headsit/Follow/Backpack são mutuamente exclusivos. Trocar ou perder o alvo desativa os modos e restaura a câmera.
- **Marcar Alvo por toque**: botão na aba Alvo entrega um Tool sem Handle, com **ícone nativo de mira** (`rbxasset://textures/MouseLockedCursor.png`). Ao tocar nele na mochila, o modo de seleção é ativado e a ferramenta é desequipada imediatamente, evitando a pose de segurar um item. Em seguida, toque/clique num personagem visível: um raycast identifica o jogador e o seleciona no menu Alvo. A mira pode ser cancelada tocando o ícone novamente. Gestos de câmera são ignorados por limite de deslocamento. O comportamento pode variar conforme o executor ou mochila personalizada.

- **Limitações físicas**: os novos constraints reduzem a oscilação causada pelo teletransporte a cada frame, mas a replicação do servidor e a latência ainda podem causar correções. O sistema desativa os modos ao trocar o alvo, quando ele sai ou quando o personagem reaparece.
- Aba **Visual** com controles organizados por Personagens, Iluminação, Interface e Desempenho.
- **X-Ray**: destaca personagens de outros jogadores através de obstáculos; **ESP**: exibe apelido e distância.
- **Horário**: opções Padrão/Dia/Noite, com restauração ao desligar; Fullbright e Sem neblina são independentes.
- **Mira roxa** e **Gráficos leves**, com ativação local e reversível.
- **Player**: FOV e controles de velocidade `8–160` (10× o padrão 16) e pulo `25–500` (10× o padrão 50). Painel com menor espaçamento entre sliders.
- **Fly**: velocidade ajustável de 5 a 160, toggle no Player, deslocamento na direção da câmera (com componente vertical) controlado pelo joystick/WASD, inclinação para a frente/trás e lateral, estabilização via `AlignOrientation` e aceleração suave. A direção da câmera substitui os antigos comandos de subir/descer; utiliza `LinearVelocity`, pode ser limitado pelo jogo e é desativado ao entrar em modos de Alvo.
- **R6/R15**: o painel só envia uma solicitação quando a experiência fornece `ReplicatedStorage.MonarcaRigSwitch`. O script `server/MonarcaRigSwitch.server.lua`, instalado em **ServerScriptService de um jogo próprio**, cria o novo modelo R6 ou R15 com `Players:CreateHumanoidModelFromDescriptionAsync`, troca `Player.Character`, destrói o modelo antigo e responde ao cliente com o resultado. Esse processo recria o personagem de verdade, disparando `CharacterAdded`. A implementação precisa ser testada com os scripts e regras de avatar da experiência. Em jogos de terceiros sem essa integração, a troca não funciona. Alterar só `Humanoid.RigType` pode matar o personagem.
- **Aba 666 — ? (v0.6.4)**: idle com braços abaixados ao lado do corpo, torso 9° levemente inclinado para trás, perna direita 21° à frente, esquerda 11° atrás e oscilação suave de distribuição de peso. A caminhada percorre os estágios **Contact → Down → Passing → Up**, com passos alternados mais amplos, elevação dos pés, deslocamento individual dos quadris, braços em contrabalanço, rotação de tronco e movimentos da cabeça. A transição idle/walk conserva suavização exponencial em cada junta e velocidade adaptativa. O Zombie continua mutuamente exclusivo. **Limitante do R6:** cada perna e braço é uma peça rígida, sem joelhos/cotovelos articulados; para dobrar a perna de fato é necessário um rig R15 ou segmentado. `Motor6D.Transform` continua local, não FE.
- **Aba 666 — </>**: novo botão alternável imediatamente abaixo de **?**, independente da animação. Quando ativo, torna somente a cabeça invisível localmente usando `LocalTransparencyModifier = 1`, ocultando também decal/textura do rosto, mas **não** remove cabelo, chapéus, acessórios, `Humanoid` ou juntas. Continua no respawn enquanto ativo; ao desativar ou fechar o Hub, restaura a transparência original. Outros jogadores continuam enxergando a cabeça.
- **Aba 666 — Korblox · Perna direita**: terceiro controle, abaixo de **</>**, com estilo preto/contorno branco (desativado) e branco/texto preto (ativado). O comando tenta usar a **geometria real** do [item Roblox 139607718](https://www.roblox.com/pt/catalog/139607718/Korblox-Deathspeaker-Right-Leg), sem forjar uma réplica. Quando a API do Roblox permite gerar um personagem com essa perna, é criada uma visualização local que acompanha as articulações; ao desligar, as partes originais voltam. **Não é FE** e não oferece desbloqueio/posse do item. Em jogos/executores que bloqueiam `Players:CreateHumanoidModelFromDescriptionAsync` ou não disponibilizam o asset, mostra erro e não afirma que equipou.

- **Navegação responsiva**: com sete abas, a faixa superior pode ser rolada horizontalmente no Android. Cada aba mantém 67 px de largura e o indicador de seleção branco. A rolagem automática procura manter a aba ativa visível.
- **Emote — Zumbi andando R6**: articulações dos ombros e quadris usam o eixo local de pitch correto, detectado pelo `Motor6D.C0/C1`; braços ficam aproximadamente 86° à frente e pernas dão passadas alternadas para frente/trás, com elevação de pés e oscilação sutil. A movimentação depende do personagem estar realmente caminhando e requer um **R6 real**.
- **FE quando permitido**: insira, na aba Emote, o ID de uma animação R6 publicada, autorizada para a experiência. O Hub usa o `Animator` do personagem (criado pelo servidor) e reproduz um `AnimationTrack`. Esse tipo de animação normalmente é replicado a outras pessoas. Sem ID/permissão ou se a animação não carregar, o modo procedural continua disponível, mas é **somente local** — `Motor6D.Transform` não replica.
- **Limite do FE**: publicar código no GitHub **não** publica uma animação na Roblox nem concede acesso a experiências de terceiros. Um asset válido e permissão da experiência são necessários. A animação não precisa ser um pacote de avatar do Marketplace; basta publicar um clipe apropriado para R6.
- Ajustes locais podem ser revertidos pelo jogo/servidor; não há garantia de replicação da movimentação ou emotes em outras máquinas.
- Botões, sliders, toggles, menus e notificações de status.
- Preferências salvas em `Monarca/settings.json` apenas se o ambiente possuir `writefile`/`readfile`; caso contrário, valem na sessão.
- Botão **Atualizar** baixa novamente `manifest.lua` e recarrega o catálogo; os módulos são baixados do GitHub sob demanda.

## Ajustes Fly e marcador de Alvo — v0.6.7

O Fly passa a usar os vetores `Camera.CFrame.LookVector` e `RightVector` para gerar movimento 3D. O ângulo vertical da câmera afeta diretamente a altitude, sem botões separados. A rotação corporal usa `AlignOrientation` com pitch e roll suaves. O marcador do Alvo agora é um atalho de hotbar com ícone de mira e seleção por toque: ele **retorna automaticamente à mochila** quando selecionado, para não manter os braços na pose de ferramenta equipada. Continua sem peça `Handle`.

## Correção da perna Korblox R15 — v0.6.6

Corrigida a prévia local da perna `139607718` na aba **666**. Antes, o módulo fazia `visual.Size = original.Size`, distorcendo a malha Korblox (especialmente espessura e comprimento). Agora cada segmento preserva a dimensão nativa gerada pelo Roblox e seu encaixe acontece pelos `RigAttachment` de quadril, joelho e tornozelo, sem alterar os tamanhos originais ou a física da perna do jogador. O módulo também valida a existência dos três segmentos antes de ocultar qualquer parte original.

O carregador dos módulos agora inclui um parâmetro de versão na URL para evitar reuso da implementação anterior via cache. O resultado depende da escala e do rig da experiência; é necessário avaliar visualmente no Roblox Android. A troca continua **local e reversível**, não FE.

## Referências de animação — revisão v0.6.4

Para o walk de `?`, foram usadas as poses `contact / down / passing / up`, a movimentação oposta dos braços, o eixo de transferência de peso e a oscilação da cabeça/quadris descritos em:
- [Anatomia de um Walk Cycle (Manual Livre de Animação 2D)](https://nafergo.github.io/manual-livre-animacao2d/walkcycle.html)
- [Adobe — What Is an Animated Walk Cycle?](https://www.adobe.com/creativecloud/animation/discover/animation-walk-cycle.html)
- [CAVE Academy — Animating a walk cycle](https://caveacademy.com/wiki/post-production-shots/animation/animation-training/introduction-to-animation-course/animating-a-walk-cycle/)

A pose parada utiliza **contrapposto estilizado**: braços mais baixos, perna direita adiantada, peso apoiado na esquerda e tronco discretamente para trás. Não são copiadas imagens, animações de terceiros ou assets pagos: os movimentos são originais e implementados matematicamente nas juntas R6.

## Preparar o emote FE no Roblox Studio

1. Em uma experiência que você controla, abra o **Roblox Studio**. Execute o conteúdo de [`studio/GenerateZombieR6Animation.lua`](https://github.com/DiscNet/Monarca/blob/main/studio/GenerateZombieR6Animation.lua) na **Command Bar** (modo de edição). Ele cria `ServerStorage/MonarcaZombieR6` como sequência de quadros do R6.
2. Inspecione e teste a animação num rig R6 usando o Editor de Animação. Publique-a no Roblox (menu **Publish to Roblox**, ou a opção de salvar/publicar o `KeyframeSequence` quando disponível). Copie o ID do asset publicado.
3. Conceda à experiência acesso a esse asset em **Creator Dashboard → experiência → Permissions → Assets**, se a propriedade da animação exigir autorização.
4. No Monarca, vá a **Emote**, insira o ID publicado no campo FE e ative **Zumbi andando**. A tela indicará se entrou em modo FE ou local. Seu amigo poderá verificar a reprodução em outra sessão do jogo.

Sem executar a publicação no Roblox, não existe ID real para o emote original. IDs temporários de `KeyframeSequenceProvider:RegisterKeyframeSequence` são apenas para testes locais e não funcionam no jogo publicado.

## Ativar R6/R15 real em experiência própria

Instale [`server/MonarcaRigSwitch.server.lua`](https://github.com/DiscNet/Monarca/blob/main/server/MonarcaRigSwitch.server.lua) como **Script** em `ServerScriptService`. Publique/reinicie a experiência para que o servidor crie o `RemoteEvent`. Quando R6 ou R15 é solicitado no Player, o servidor reconstrói o personagem do próprio jogador, preservando sua descrição de avatar, e envia uma confirmação ou erro. Não é uma funcionalidade que o Script Hub cliente possa ativar por conta própria em jogos de outras pessoas.

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

## Correção de inicialização v0.6.1

O script principal ultrapassou o limite de 200 variáveis locais por função do compilador Luau quando a aba 666 foi adicionada. As inicializações de Home e de Emote/666 passaram a ficar em funções isoladas, reduzindo o número de variáveis locais simultâneas na inicialização sem remover recursos. O workflow agora compila todos os arquivos `.lua` com o compilador oficial do Luau (além da análise de sintaxe), para detectar limites de registradores nas próximas atualizações. A compilação não substitui um teste interativo no Roblox.

## Correção de inicialização v0.6.2

Ao não aparecer nada após executar, a causa pode ser um erro em tempo de execução ou a interface ter sido anexada a um `Parent` vazio. A v0.6.2 monta primeiro no `PlayerGui`, verifica que a interface foi realmente anexada, protege a inicialização com `xpcall`, apresenta um aviso **MonarcaStartupError** na tela com a etapa e o erro, e desbloqueia o painel caso a animação inicial falhe ou demore mais de 9 segundos. Os recursos das sete abas continuam disponíveis, incluindo **666**. A execução visual dentro do Roblox ainda depende de um teste real.

Se estiver testando uma versão em cache, execute com uma consulta diferente a cada tentativa:

```lua
local address = "https://raw.githubusercontent.com/DiscNet/Monarca/main/Monarca.lua"
local source = game:HttpGet(address .. "?v=" .. tostring(os.time()))
local chunk, err = loadstring(source)
assert(chunk, err)
chunk()
```

Se um painel de erro aparecer, envie o conteúdo para identificar a etapa exata da falha.

## Limites e testes

Código-fonte não equivale a teste em Roblox em execução. Verifique em um ambiente de teste antes do uso. A execução de código remoto exige `loadstring` e `game:HttpGet`; o arquivo de configuração exige APIs de arquivos não padronizadas. O projeto não contém recursos para perturbar outros jogadores, contornar anticheat ou acessar dados de terceiros.

## Observações visuais

X-Ray e ESP não alteram personagens no servidor. O ESP atualiza distâncias a cada 0,2 s e limita etiquetas a 500 studs. A renderização de Highlight pode ter limites do próprio Roblox. Mapas que sobrescrevem a iluminação ou bloqueiam efeitos podem reduzir a eficácia dos controles. As opções podem ser incompatíveis com as regras de algumas experiências.
