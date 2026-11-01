# Monarca — Roblox Script Hub

Script Hub em **Luau**, com interface escura, abas **Home/Alvo/Visual/X?/Player/Emote/Anim/666/Settings** e layout adaptável ao Android. Versão atual: **0.8.5**.

## Aba 666 — Fling em servidores públicos e privados (v0.8.5)

A aba **666** agora traz os controles **Fling** e **Aceitar Fling**. Em uma experiência Roblox sob seu controle, instale `server/MonarcaTouchBounce.server.lua` em `ServerScriptService`. Sem essa instalação, o botão sinaliza que a integração está ausente; o script cliente não consegue arremessar outros jogadores sozinho.

Em **servidores públicos ou privados de uma experiência com a integração instalada**, ativar **Fling** permite empurrar peças soltas e leves ao encostar. A exigência de sessão privada foi removida. Para tocar e empurrar outro jogador, ele precisa ativar **Aceitar Fling** no próprio Monarca. Essa preferência é individual e inicialmente desligada. NPCs precisam receber o atributo `MonarcaBounceTarget = true` no Model para participar. Peças ancoradas e partes pesadas são ignoradas.

O servidor valida contatos e proximidade antes de aplicar impulso limitado e intervalo por alvo, sem causar dano diretamente. O estado pode continuar após respawn. Fechar o Monarca desativa Fling e a autorização de receber impactos. **Não funciona como exploit FE universal em servidores de terceiros**: exige integração instalada pelo desenvolvedor e não interfere em usuários que não autorizaram a brincadeira.

## Aba 666 — Antifling: proteção local contra arremessos (v0.8.3)

O botão **Antifling** da aba **666** ativa um módulo independente em `modules/antifling.lua`. Quando ligado, o cliente torna **não colidíveis localmente** as peças de outros personagens (jogadores e NPCs com `Humanoid`) e as peças **não ancoradas** do mapa, reduzindo arremessos físicos provocados por jogadores e objetos soltos.

**Preservação do movimento:** as peças do próprio avatar, seu `HumanoidRootPart`, o `Terrain`, o chão e as paredes **ancorados** não são alterados. O módulo observa novas peças/avatares, detecta peças que se tornam soltas perto do personagem e reaplica as mudanças se outro script trocar `CanCollide`. Utiliza uma varredura inicial fatiada e rechecagens limitadas para reduzir carga em celulares. Permanece ligado após respawn, e **OFF**, fechar o hub e desativar o módulo restauram as propriedades armazenadas das peças alteradas.

**Limitação técnica:** isso só atua no cliente; decisões físicas autoritativas do servidor, scripts que teleportam o personagem ou forças aplicadas diretamente ao avatar podem continuar provocando arremessos. A função não é uma proteção universal ou anti-cheat, nem modifica a simulação dos outros jogadores. Verifique no Roblox real, especialmente em experiências que alteram `CanCollide` com frequência.

## Animações independentes por movimento R15 — v0.8.2

A aba **Anim** agora permite misturar animações dos **18 pacotes já disponíveis** sem substituir o pacote inteiro. É possível combinar, por exemplo, **Idle = Elder** com **Walk = Cartoony**, enquanto **Run = Vampire** ou qualquer outro pacote. Os controles disponíveis são **Idle, Walk, Run, Jump, Fall, Climb, Swim e Swim Idle**. O seletor de **Idle** atualiza tanto `idle.Animation1` como `idle.Animation2`, preservando as duas variações de repouso do pacote escolhido.

**Como usar:** na parte superior da aba, escolha um pacote base (ou **Padrão do mapa**); em **Personalizar movimentos**, toque no seletor de cada movimento, procure o pacote desejado e confirme. **Herdar pacote base** remove a substituição individual, enquanto **Padrão do mapa** usa a animação original apenas daquele movimento. Ao terminar, selecione **APLICAR MISTURA**. O botão **APLICAR** superior continua aplicando o pacote completo e limpa os campos de mistura; **RESTAURAR** devolve as animações originais; **LIMPAR CAMPOS** apenas limpa as opções do editor até a próxima aplicação.

A API Luau expõe `AnimPacks:enableMixed(basePreset, {idle = "elder", walk = "cartoony"})` e mantém `AnimPacks:enable("vampire")` para pacotes completos. As configurações ativas são reaplicadas ao renascer, com restauração dos IDs originais ao desativar. Não são criados clones nem `Animator` locais. A reprodução para outros jogadores **não é garantida em todos os mapas**; depende de como o jogo gerencia `Animate`, o `Animator` e o acesso aos assets.

## Ampliação da aba Anim: 18 pacotes R15 — v0.8.1

A lista de pacotes foi ampliada de um para **18**, mantendo o Vampire existente. Os **17 pacotes documentados no Roblox Creator Hub** são: Astronaut, Bubbly, Cartoony, Elder, Knight, Levitation, Mage, Ninja, Pirate, Robot, Rthro, Stylish, Superhero, Toy, Vampire, Werewolf e Zombie. **Oldschool** foi incluído separadamente com os nove IDs encontrados e conferidos em tabelas comunitárias. Todos têm as nove referências esperadas pelo `Animate` tradicional: Idle1, Idle2, Walk, Run, Jump, Fall, Climb, Swim e SwimIdle.

A nova seleção na aba **Anim** abre uma lista com altura limitada e rolagem interna, campo **Buscar pacote**, botões pequenos e o pacote selecionado no painel. O painel principal não aumenta verticalmente para mostrar 18 opções simultâneas. A pesquisa filtra os nomes sem nova requisição e a lista mantém o estado. Ao escolher **Padrão do mapa** e clicar em Aplicar, restaura o pacote anterior; **Restaurar** faz o mesmo a qualquer momento.

`modules/anim_packs.lua` mantém o mesmo uso do `Animator` original do avatar R15, sem criar controladores locais. Corrigimos um detalhe da versão anterior: a parada de tracks e a restauração deixaram de estar fixas no Vampire; agora usam o último pacote realmente ativo, inclusive ao alternar de Vampire para Ninja ou outro.

A expansão está limitada aos **18 conjuntos clássicos cujos IDs foram conferidos**. Não anuncia cobertura de todos os pacotes promocionais recentes (Bold, adidas, Glow Motion, KATSEYE etc.), que possuem requisitos de acesso e IDs ainda não auditados para esta versão. A replicação FE permanece dependente do `Animator` e do acesso a cada asset, devendo ser testada com outro jogador.

Fontes: https://create.roblox.com/docs/animation/using ; https://github.com/Eazvy/Public-Scripts/blob/main/Universal_Animations_Emotes.lua

## Aba Anim: pacote Vampire R15 — v0.8.0

Nova aba **Anim** no menu, posicionada entre **Emote** e **666**. A primeira ferramenta é um seletor compacto de pacotes com duas opções: **Vampire Animation Pack** e **Padrão do mapa**. A opção Vampire aplica nove slots de movimento do catálogo oficial ao **Animate existente** no personagem R15, e **Restaurar** recupera os IDs anteriores sem alterar os scripts do jogo permanentemente.

Pacote Vampire (Roblox bundle 33): **Idle1 1083445855**, **Idle2 1083450166**, **Walk 1083473930**, **Run 1083462077**, **Jump 1083455352**, **Fall 1083443587**, **Climb 1083439238**, **Swim 1083464683**, **SwimIdle 1083467779**. A documentação Roblox lista também o Idle alternativo 1088037547, não aplicado porque o `Animate` padrão geralmente possui somente dois slots de Idle.

Implementação: `modules/anim_packs.lua` verifica `Humanoid.RigType == R15`, a presença de `Animate` compatível e a presença de um **Animator já existente**, no avatar real do usuário. Não cria `Animator` local, nem usa `Motor6D.Transform` nem clone local para reprodução FE. Desativa temporariamente `Animate`, substitui os IDs dos nove `Animation` filhos e reativa o script no estado anterior. Faz nova aplicação após respawn e restaura os IDs originais ao desligar/fechar o Hub.

**FE:** segundo `Animator:LoadAnimation` da documentação oficial, `AnimationTrack` iniciado no cliente de seu próprio personagem pode ser replicado aos demais clientes quando o `Animator` já foi criado no servidor e replicado. A modificação dos slots locais faz com que o `Animate` nativo solicite e reproduza os clips no `Animator`; **não comprova FE no jogo real**, pois jogos podem substituir `Animate`, bloquear assets ou aplicar outro controlador. Verifique com outra conta no servidor. Não funciona com rig R6 nem enquanto o controle estiver em um clone local.

Fontes:
- Roblox Animation Using: https://create.roblox.com/docs/animation/using
- Roblox Animator API: https://create.roblox.com/docs/reference/engine/classes/Animator/LoadAnimation
- Vampire bundle: https://www.roblox.com/pt/bundles/33/Vampire-Animation-Pack

## Invisibilidade experimental mais estável — v0.7.9

A aba **X?** mantém a técnica de `RealCharacter` / `FakeCharacter`, mas corrige fontes de *jitter* quando o avatar entra ou sai da invisibilidade:

- O corpo real distante deixa de receber `Humanoid:Move()` e `Humanoid.Jump` repetidamente. Reposiciona apenas quando há desvio acima de 4 studs, em vez de teletransportar em todo ciclo de atualização.
- O corpo estacionado tem colisões locais desativadas temporariamente e usa uma força gravitacional compensatória quando a API permite. As propriedades originais são restauradas ao desligar. Essas alterações não garantem que o servidor manterá o corpo distante.
- O clone conserva a velocidade linear atual na ativação. Na desativação o `HumanoidRootPart` do corpo real é alinhado ao do clone, com velocidade zerada para evitar deslocamentos verticais.
- A câmera conserva posição/orientação por cinco atualizações de renderização durante a troca de `CameraSubject`, para permitir que o controlador de câmera seja religado sem rotação brusca.
- A restauração desativa a colisão do clone antes de sobrepor os dois corpos, recupera o item previamente equipado e evita devolver o controle a um corpo real já morto quando ocorreu respawn.
- Falhas no uso de `BindToRenderStep` não devem mais abortar toda a ativação. Se o retorno ao personagem real falhar, o sistema preserva o proxy para uma tentativa posterior em vez de apagá-lo à força.

**Limitações:** o servidor pode reconciliar posições e estados; nenhum teste real no cliente Android foi efetuado. O método baseado em corpo remoto não equivale a uma funcionalidade de invisibilidade de servidor garantida.

**Sobre animações R15 FE:** o `Animator` já replicado dentro do `Humanoid` do próprio personagem permite que `AnimationTrack:Play()` iniciado localmente replique para servidor e outros clientes, conforme documentação oficial Roblox. O `Animator` de um clone criado apenas no cliente não oferece a mesma garantia. Para animações FE, é preferível trabalhar com o `Animator` do avatar original e IDs de animação acessíveis, e confirmar com outra conta.

## Correção do limite de registradores — v0.7.8

A captura de erro no Roblox Android mostrou: `Out of local registers when trying to allocate dragStart: exceeded limit 200` na linha **3495** do antigo núcleo. O compilador do executor possui limite de registradores locais simultâneos para cada função. Dividir `Monarca.lua` em um carregador curto e `hub_core.lua` **não resolveu por si só**, pois a função `bootMonarca()` dentro do núcleo ainda mantinha muitas referências de interface vivas até o fim.

Nesta correção, `hub_core.lua` separa a construção de **Player/Emote/666**, **Settings/Visual** e **eventos de arrastar** em blocos lexicais `do ... end` independentes. São preservadas somente as referências necessárias fora deles, como `applyPlayer`, os pintores de sliders, `refresh` e `disableAll`. O compilador pode reciclar os registradores das variáveis temporárias após cada bloco, reduzindo o pico de variáveis vivas no trecho que antes falhava. Mantivemos o botão do Reverse, invisibilidade experimental, HUD e as demais abas.

O carregador `Monarca.lua` continua pequeno, mostra erros de download/compilação/execução na tela e tenta `hub_core.lua?v=0.7.8-...`, evitando reaproveitar acidentalmente a versão anterior. As verificações automatizadas validam a sintaxe e compilação Luau, mas **a execução no executor Android precisa de teste real**.

## Executar

Em um ambiente que ofereça `game:HttpGet` e `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DiscNet/Monarca/main/Monarca.lua"))()
```

**Importante:** este projeto não é uma função oficial do Roblox. A execução por software de terceiros pode violar as regras do Roblox, e a compatibilidade varia por ambiente. Não introduza credenciais, tokens ou dados pessoais no Hub. Execute apenas código confiável.

## Estrutura

- `Monarca.lua` — carregador de ~7 KB com diagnóstico visível, tentativas de download e botão de repetir em caso de erro.
- `hub_core.lua` — interface principal completa, navegação, controles, animações, salvamento e ciclo de vida; carregado apenas após a tela de diagnóstico já estar visível.
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
- `modules/player_fly.lua` — voo local de 5–160 studs/s na direção completa da câmera. Joystick/WASD para avançar, subir e descer conforme a visão; agora o personagem também acompanha a inclinação vertical da câmera **parado no ar**, mantendo pitch/roll suaves. Não mostra comandos SUBIR/DESCER.
- `modules/player_reverse.lua` — Reverse/Flashback baseado no código original enviado (posição/rotação, velocidade, estado do Humanoid, PlatformStand e ferramenta equipada). Histórico circular de até 60 s a 30 amostras por segundo para reduzir custo no Android, tecla E para segurar, botões `start()/stop()` para o HUD, parada segura em morte ou respawn. É uma rebobinagem local do personagem, não do servidor.
- `modules/zombie_r6.lua` — emote R6 corrigido: braços à frente, pernas alternadas no plano de caminhada; reprodução FE por animação publicada quando autorizada, ou alternativa local.
- `modules/pose_666.lua` — animação R6 local aprimorada: postura menos inclinada, braços soltos, idle com respiração e oscilação, caminhada com passos mais expressivos e transição idle/walk gradual.
- `modules/headless_local.lua` — controle independente `</>`: oculta apenas `Head` e decals/texturas do rosto no cliente por `LocalTransparencyModifier`, mantendo cabelos/acessórios e restaurando tudo ao desativar.
- `modules/korblox_right_leg.lua` — opção alternável de prévia **local e reversível** da perna direita original do Korblox Deathspeaker (asset Roblox `139607718`). No R15 preserva o **tamanho nativo de cada `MeshPart`** da geometria Korblox (sem esticá-la até as dimensões da perna anterior) e alinha as peças por `RightHipRigAttachment`, `RightKneeRigAttachment` e `RightAnkleRigAttachment`. No R6 mantém `CharacterMesh`. Não concede propriedade do item e depende de o carregamento desse asset ser permitido pela experiência.
- `modules/owner_tag.lua` — tag exclusiva projetada via `WorldToViewportPoint`, com `UIScale` controlado pela altura aparente do avatar: quando o personagem diminui na tela ao afastar a câmera, a tag também diminui, evitando o aparente crescimento desproporcional. RGB ONDA suave (~5,6 segundos por ciclo). Restrição visual/cliente ao username `samulucas7419`, não é whitelist segura de servidor.
- `modules/radioactive_trail.lua` — rastro verde radioativo (cliente) redesenhado: tenta tingir o **bloco tocado**, não apenas a superfície, em peças ancoradas de até 230 studs de largura; manchas direcionais mais contínuas, partículas e luz limitada, que encolhem tanto no comprimento quanto na largura conforme desvanecem. Até 90 trechos efêmeros, amostragem a cada 0,075 s. Bases gigantes e Terrain usam projeção local em vez de mudar o chão inteiro.
- `modules/server_invisibility.lua` — botão da aba **X?** que solicita invisibilidade com resposta explícita do servidor. Não mente sobre FE quando o RemoteEvent não existe.
- `modules/clone_invisibility.lua` — **protótipo experimental local**, separado do modo de servidor: clona o avatar local, alterna `LocalPlayer.Character` e `CameraSubject` para o clone semitransparente e reposiciona repetidamente o personagem real em uma posição distante, restaurando-o ao desligar. Depende do comportamento de simulação e replicação da experiência. **Não garante invisibilidade FE** nem compatibilidade com anticheat; pode provocar desync, falhas de câmera, interrupções ou respawn. Requer verificação com uma segunda conta.
- `server/MonarcaInvisibility.server.lua` — integração opcional para jogo **próprio**: restringe a solicitação no servidor ao username `samulucas7419`, esconde partes, decals e acessórios do próprio jogador para os demais clientes e restaura os valores anteriores ao desligar. Instalação manual no `ServerScriptService`.
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

## Carregador de diagnóstico — v0.7.7

A execução continua usando **o mesmo comando**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DiscNet/Monarca/main/Monarca.lua"))()
```

**Mudança estrutural:** `Monarca.lua` não contém mais a interface gigante (~155 KB), e sim um carregador enxuto (~7 KB) que monta uma tela **antes** de buscar `hub_core.lua`. O núcleo contém toda a UI e retorna `ok, failure` ao carregador. Qualquer problema no download, no `loadstring` do núcleo ou na inicialização é mostrado diretamente no HUD, com um botão **TENTAR NOVAMENTE**. Uma verificação de demora após 10 segundos também exibe a opção de repetir. Tentativas antigas que terminarem após uma nova solicitação não executam duplicadas.

**Por quê:** as versões anteriores podiam falhar antes de desenhar a interface, deixando a impressão de que nenhuma execução havia acontecido. A aprovação do CI confirma que o Lua/Luau compila, mas não substitui um teste dentro do executor mobile. O novo caminho permite identificar o estágio de falha em vez de mascarar o erro.

O Reverse continua inicializado em paralelo, assim que o núcleo do Monarca começa a executar. As configurações, tabs e visual do Hub permanecem no `hub_core.lua`.

## Correção de inicialização — v0.7.6

- **Correção de travamento na abertura:** a v0.7.5 iniciava uma chamada síncrona a `game:HttpGet` para carregar o módulo Reverse *antes de montar o ScreenGui*. Se o executor demorasse ou interrompesse a requisição, o usuário veria "nada acontece", sem o painel e sem o aviso de erro. A inicialização do Reverse agora é disparada imediatamente em uma tarefa separada via `task.spawn`. Assim o histórico começa tão cedo quanto o módulo é carregado, mas a abertura do painel não espera pela rede.
- **Carregamento serializado:** a abertura automática e o toque rápido do botão Reverse não podem iniciar duas cópias do módulo e registrar listeners duplicados. Quando há carregamento em curso, a segunda solicitação espera o mesmo resultado.
- **Isolamento de falhas:** se a construção da aba X? falhar por incompatibilidade da API gráfica, essa falha não deve interromper a criação das outras abas. A advertência fica no console/rodapé.
- **Verificação pendente:** execução no Roblox Android ainda precisa ser confirmada; compilação Luau valida sintaxe e bytecode, mas não simula a interface, o executor ou requisições HTTP.

## Câmera estável, HUD menor e histórico imediato — v0.7.5

- **Invisibilidade X? experimental:** a transição entre personagem real e proxy agora salva `Camera.CFrame` e `Camera.Focus` antes da troca de `CameraSubject`. Aplica `CameraType.Scriptable` durante a mudança e restaura o tipo original, com duas atualizações curtas após o script padrão da câmera, tentando manter a orientação e o zoom em vez de girar na direção do avatar. A solução é uma mitigação local e depende do comportamento da câmera da experiência.
- **Posição do personagem:** a transferência do corpo real passou a alinhar `HumanoidRootPart.CFrame` exatamente com a raiz do proxy, em vez de alinhar os pivôs dos modelos. Isso evita diferenças de deslocamento/altura entre os dois. Na volta, zera a velocidade linear/angular residual do corpo real, reduzindo o pulo, queda ou `fling` causados pelo posicionamento distante. O servidor ainda pode corrigir posições.
- **Botão Invisível do HUD:** o controle anterior de 94×38 px e texto `INVIS ON/OFF` virou botão compacto **48×48 px**, alinhado ao Reverse, com ícone de olho desenhado com elementos vetoriais. Quando ativo, aparece um traço diagonal sobre o olho. Mantém borda branca, acabamento físico, mudança de cor e posição fixa no canto direito (38% da altura), sem texto no botão.
- **Reverse automático:** `modules/player_reverse.lua` é carregado e habilitado durante o início da execução do `Monarca.lua`, **antes do painel e animação de entrada serem construídos**. O histórico não precisa de primeiro toque no botão e grava até 60 segundos. A opção **Reverse no HUD** agora apenas mostra ou esconde o botão, sem interromper a gravação nem apagar os frames já registrados. O histórico é limpo por segurança em morte/troca do personagem, ou ao encerrar o Hub. A tecla E permanece disponível quando o botão está oculto.
- **Teste:** confirmar ao vivo no Roblox Android que câmera, distância visual e posição real não mudem inesperadamente ao ativar/desativar; não é possível garantir ausência de correções pelo servidor somente com compilação.

## Reverse / Flashback com botão físico — v0.7.4

- **Local:** aba **Player**, controle **Reverse no HUD** (ativado por padrão). A gravação começa ao executar o Monarca, antes da UI. Esse controle só define se o botão fixo fica visível, aproximadamente a 54% da altura da tela.
- **Ícone:** seta circular de Reverse desenhada com segmentos vetoriais da própria interface Roblox (`Frame`, sem letra e sem dependência de fonte ou imagem externa); controle compacto de **48×48 px**, cantos de 11 px, borda branca, brilho violeta discreto e sombra deslocada para dar sensação de botão físico. Ao pressionar, o controle afunda 3 px e inverte as cores da seta e do fundo. Ao soltar, retorna à posição e encerra o Reverse.
- **Ativação:** pressione e segure o botão no Android ou a tecla **E** no teclado. Não é um alternável de um toque: ao soltar, a reprodução retroativa para. O mesmo módulo responde aos dois meios de entrada.
- **Base original:** o script fornecido grava `CFrame`, `Velocity`, estado do `Humanoid`, `PlatformStand` e `Tool` equipado. A adaptação preserva esses campos, substitui `Velocity` por `AssemblyLinearVelocity`, usa buffer circular (até **1.800 estados**, ~60 segundos a 30 Hz) para evitar `table.remove(frames, 1)` e previne leitura de frames inexistentes.
- **Segurança operacional:** o Reverse restaura o estado ancorado, `AutoRotate` e `PlatformStand` ao soltar, interrompe em morte ou troca de personagem, desconecta os listeners ao encerrar o hub, impede concorrência com Fly ativo e não tenta rebobinar o clone experimental de invisibilidade. Ao ocultar o botão, o histórico e a gravação continuam disponíveis; o módulo é desligado ao encerrar o hub. A preferência é salva quando disponível.
- **Limitação:** trata-se de um efeito de posição e estados do avatar no cliente. Não restaura pontos de vida, itens destruídos, outras pessoas nem o tempo do servidor. Servidores podem recusar ou corrigir posições; ferramentas/estados antigos podem deixar de existir. Precisa de teste dentro do Roblox Android para confirmar a suavidade e o posicionamento do controle.

## Botão fixo para invisibilidade no HUD — v0.7.3

Na aba **X?**, a opção **Botão fixo no HUD** ativa ou oculta um controle compacto `INVIS OFF/ON` ancorado ao lado direito da tela (38% da altura, 14 px da borda, 94×38 px), **sem arrastar** e independente da janela principal do Monarca. Assim, continua disponível mesmo com o painel minimizado. Usa o estilo escuro com borda branca quando OFF e fundo branco com texto escuro e halo violeta discreto quando ON.

O botão alterna **exclusivamente o modo Invisível · experimental (clone)**; não aciona a opção que depende de servidor. Ambos usam a mesma função de acionamento e se mantêm sincronizados, inclusive quando a invisibilidade experimental é interrompida automaticamente devido a falha, morte ou respawn. Durante transições exibe `...` e ignora toques repetidos. Evita ativação simultânea com o modo de invisibilidade de servidor.

A opção só aparece para o username `samulucas7419` no cliente. A preferência `invisibilityHudEnabled` é salva com as demais configurações quando `writefile` está disponível. A posição é fixa e não se altera com movimentação ou zoom da câmera. Fechar ou reiniciar o Hub remove o botão antigo, evitando controles duplicados. Não garante replicação da invisibilidade; o protótipo continua experimental.

## Invisibilidade por clone — experimento v0.7.2

A aba **X?** mantém a opção **Invisível · servidor** para experiências administradas pelo usuário, e adiciona **Invisível · experimental** como segundo botão opcional. O segundo não precisa de instalação no servidor, mas **não possui confirmação de visibilidade por outras contas**.

Implementação experimental: realiza uma cópia local do personagem (desliga scripts locais duplicados, com exceção do Animate), posiciona a cópia no lugar de origem e troca `LocalPlayer.Character` e `Workspace.CurrentCamera.CameraSubject` para ela. O personagem real é movido repetidamente para uma posição distante. O clone aparece semitransparente apenas no próprio cliente. Ao desligar, o script restaura o personagem e a câmera na posição atual do clone e o destrói. Também tenta reverter em caso de morte, respawn ou encerramento do hub.

**Não é invisibilidade FE comprovada**: o servidor pode rejeitar ou corrigir a movimentação do corpo real, o jogo pode bloquear a troca local do personagem, e o clone não substitui interações válidas para o servidor. A confirmação exige teste com outra conta. Acesso ao experimento está limitado no cliente ao Username `samulucas7419`, sem representar segurança de servidor. Evite utilizar durante Fly, Follow, Headsit e Backpack; ao ativar, o Monarca interrompe esses modos. A ativação é manual e o botão mostra avisos de instabilidade. Uma proteção do jogo pode levar a respawn.

## Rastro contínuo + aba X? — v0.7.1

**Rastro radioativo (666):** o efeito anterior só tingia peças de até 9 studs de lado; por isso, em boa parte dos mapas as manchas pareciam lâminas sobrepostas, sem modificar o bloco. Agora o contato altera a cor e material `Neon` da peça atingida (quando ancorada e até 230 studs no plano), e restaura o estado depois. Trechos locais de rastro são espaçados a cada ~0,37 stud de deslocamento, amostrados a cada 0,075 s. O comprimento de cada trecho segue a distância percorrida entre amostras; largura e comprimento diminuem durante os 4,1 segundos de desaparecimento. Um limite de 90 marcas evita crescimento infinito de instâncias. `Terrain` e bases gigantes continuam recebendo **projeção local**, não recoloração total. Não altera o servidor nem os outros jogadores.

**Aba X?:** localizada entre Visual e Player. Primeiro alternável **Invisível**, com aparência preta/contorno branco em OFF e branca/texto preto em ON. Só confirma ON quando o servidor responde pelo `ReplicatedStorage.MonarcaInvisibility` à solicitação do jogador. **Para funcionar de verdade para outros jogadores**, instale o arquivo `server/MonarcaInvisibility.server.lua` como Script em `ServerScriptService` **de uma experiência que você administra**. O servidor verifica `Player.Name == samulucas7419`, torna `BasePart`, `Decal`, `Texture` e efeitos de aparência do próprio personagem invisíveis/desativados para todos, esconde o nome por `Humanoid.DisplayDistanceType = None`, repete o estado no respawn e restaura as propriedades originais ao desligar. Não confere invisibilidade contra scripts de detecção, colisões, sons ou ferramentas ESP especiais; é invisibilidade de renderização replicada, **não invulnerabilidade**.

Sem a integração de servidor, nenhum código executado exclusivamente no cliente pode impor invisibilidade visual replicada de forma confiável em jogos de terceiros. O botão informa a ausência do servidor e permanece OFF. A instalação no servidor não acontece apenas por alterar o GitHub.

## Ajuste da tag e rastro radioativo — v0.7.0

- **Tamanho da tag:** manter dimensões totalmente fixas na tela causava impressão de crescimento quando o personagem ficava menor devido ao zoom. A tag agora reduz de maneira controlada o próprio `UIScale` de acordo com a altura projetada do personagem em pixels, com limite para zoom próximo e ocultação a distâncias excessivas. Assim, não aumenta em relação ao corpo quando a câmera se afasta.
- **666 → Rastro radioativo:** novo botão alternável abaixo da perna Korblox. Quando o jogador se movimenta sobre o solo, `workspace:Raycast` identifica a superfície e deposita pequenas manchas `Neon` verde radioativo, com `ParticleEmitter` de faíscas e luz `PointLight` discreta. Em blocos de tamanho reduzido, a cor/material do bloco também pode ficar verde temporariamente no cliente. O efeito some gradualmente em aproximadamente **3,8 segundos** e a superfície é restaurada. O modo não altera permanentemente o mapa nem é FE.
- **Desempenho:** no máximo 22 resíduos ao mesmo tempo, só os três últimos com iluminação ativa, um raycast a cada 0,19 segundo durante caminhada e vida curta das partículas. Não produz resíduos em pleno voo, sem contato próximo do solo. Desativar o controle remove as marcas restantes e restaura as cores originais dos blocos.
- O rastro é **local**; outros jogadores só o veriam com uma implementação no servidor da experiência. A opção funciona separadamente dos emotes e do headless.

## Tag estável e RGB ONDA — v0.6.9

- A tag deixou de depender de redimensionamento 3D de `BillboardGui`: uma `ScreenGui` desenha o texto em **280×42 pixels**, com `TextSize = 19` e `TextScaled = false`, enquanto `Camera:WorldToViewportPoint` acompanha a posição da cabeça. Distância e zoom não alteram a dimensão do texto na tela.
- O modo antigo `RGB FAST` passou a aparecer como **RGB ONDA**: um `UIGradient` com seis pontos de cor cria um espectro distribuído horizontalmente no texto. A onda varia suavemente e completa um ciclo em aproximadamente **5,6 segundos**, sem flashes nem mudanças bruscas da cor inteira. A amostra de cor na aba Player acompanha o mesmo efeito.
- A chave de configuração `ownerTagRainbowFast` foi mantida apenas para preservar as preferências salvas. O resultado permanece **local**, exclusivo ao usuário `samulucas7419` na interface, sem replicação para outros jogadores.

## Tag exclusiva e Fly parado — v0.6.8

- Na aba **Player**, a seção **Tag pessoal** só é exibida para o nome de usuário **samulucas7419** (Username, não DisplayName). É possível ligar/desligar a tag, escrever até 32 caracteres, ajustar **Vermelho / Verde / Azul** por sliders de 0–255 com prévia e ativar **RGB FAST** (aprox. 3,5 ciclos completos de cor por segundo).
- A tag usa `BillboardGui` ligado à cabeça do próprio personagem e reaparece após respawn enquanto ativa. Texto, cor e modo RGB são gravados em `Monarca/settings.json` nos ambientes que oferecem `writefile`. Ela é **visível somente no cliente local**. A whitelist do cliente não é um mecanismo seguro para permissões de servidor.
- O Fly corrigiu o `leanPitch` calculado como zero quando o personagem estava parado. Agora a orientação usa o `LookVector.Y` da câmera mesmo sem movimento, com interpolação para evitar giros bruscos.

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
