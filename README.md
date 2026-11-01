# Monarca — Roblox Script Hub

Script Hub em **Luau**, com interface escura, abas **Home/Alvo/Visual/Player/Emote/666/Settings** e layout adaptável ao Android. Versão atual: **0.6.1**.

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
- `modules/player_fly.lua` — voo local com velocidade de 5–160 studs/s, controle analógico de movimento e comandos para subir/descer.
- `modules/zombie_r6.lua` — emote R6 corrigido: braços à frente, pernas alternadas no plano de caminhada; reprodução FE por animação publicada quando autorizada, ou alternativa local.
- `modules/pose_666.lua` — animação procedural local exclusiva do R6: braços projetados à frente e para dentro, postura curvada, cabeça levantada, caminhada cambaleante e idle cansado.
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
- **Marcar Alvo por toque**: botão em Alvo entrega um Tool `Marcar Alvo` na mochila. Ao equipá-lo e clicar/tocar no personagem de outro jogador, ele é selecionado automaticamente, sem digitar nick. A seleção depende do personagem visível/atingido e pode não funcionar em jogos que substituem a mochila ou captura de input.

- **Limitações físicas**: os novos constraints reduzem a oscilação causada pelo teletransporte a cada frame, mas a replicação do servidor e a latência ainda podem causar correções. O sistema desativa os modos ao trocar o alvo, quando ele sai ou quando o personagem reaparece.
- Aba **Visual** com controles organizados por Personagens, Iluminação, Interface e Desempenho.
- **X-Ray**: destaca personagens de outros jogadores através de obstáculos; **ESP**: exibe apelido e distância.
- **Horário**: opções Padrão/Dia/Noite, com restauração ao desligar; Fullbright e Sem neblina são independentes.
- **Mira roxa** e **Gráficos leves**, com ativação local e reversível.
- **Player**: FOV e controles de velocidade `8–160` (10× o padrão 16) e pulo `25–500` (10× o padrão 50). Painel com menor espaçamento entre sliders.
- **Fly**: velocidade ajustável de 5 a 160, toggle no Player, comandos SUBIR/DESCER na tela do celular e Space/Ctrl no teclado. Usa `LinearVelocity`, pode ser limitado pelo jogo e é desativado ao entrar em modos de Alvo.
- **R6/R15**: o painel só envia uma solicitação quando a experiência fornece `ReplicatedStorage.MonarcaRigSwitch`. O script `server/MonarcaRigSwitch.server.lua`, instalado em **ServerScriptService de um jogo próprio**, cria o novo modelo R6 ou R15 com `Players:CreateHumanoidModelFromDescriptionAsync`, troca `Player.Character`, destrói o modelo antigo e responde ao cliente com o resultado. Esse processo recria o personagem de verdade, disparando `CharacterAdded`. A implementação precisa ser testada com os scripts e regras de avatar da experiência. Em jogos de terceiros sem essa integração, a troca não funciona. Alterar só `Humanoid.RigType` pode matar o personagem.
- **Aba 666**: contém uma única opção alternável chamada **?** (sem nomes extras). A animação R6 muda o alinhamento dos ombros para apontar braços à frente e ligeiramente para dentro, inclina o tronco, ergue a cabeça, mantém um idle de respiração cansada e dá passos arrastados durante o movimento. Usa `Motor6D.Transform` e é **somente local**, não FE. Ao iniciar ?, desativa o Zombie; ao iniciar Zombie, desativa ?. O botão passa de preto/contorno branco para branco/texto preto quando ativo.
- **Navegação responsiva**: com sete abas, a faixa superior pode ser rolada horizontalmente no Android. Cada aba mantém 67 px de largura e o indicador de seleção branco. A rolagem automática procura manter a aba ativa visível.
- **Emote — Zumbi andando R6**: articulações dos ombros e quadris usam o eixo local de pitch correto, detectado pelo `Motor6D.C0/C1`; braços ficam aproximadamente 86° à frente e pernas dão passadas alternadas para frente/trás, com elevação de pés e oscilação sutil. A movimentação depende do personagem estar realmente caminhando e requer um **R6 real**.
- **FE quando permitido**: insira, na aba Emote, o ID de uma animação R6 publicada, autorizada para a experiência. O Hub usa o `Animator` do personagem (criado pelo servidor) e reproduz um `AnimationTrack`. Esse tipo de animação normalmente é replicado a outras pessoas. Sem ID/permissão ou se a animação não carregar, o modo procedural continua disponível, mas é **somente local** — `Motor6D.Transform` não replica.
- **Limite do FE**: publicar código no GitHub **não** publica uma animação na Roblox nem concede acesso a experiências de terceiros. Um asset válido e permissão da experiência são necessários. A animação não precisa ser um pacote de avatar do Marketplace; basta publicar um clipe apropriado para R6.
- Ajustes locais podem ser revertidos pelo jogo/servidor; não há garantia de replicação da movimentação ou emotes em outras máquinas.
- Botões, sliders, toggles, menus e notificações de status.
- Preferências salvas em `Monarca/settings.json` apenas se o ambiente possuir `writefile`/`readfile`; caso contrário, valem na sessão.
- Botão **Atualizar** baixa novamente `manifest.lua` e recarrega o catálogo; os módulos são baixados do GitHub sob demanda.

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

## Limites e testes

Código-fonte não equivale a teste em Roblox em execução. Verifique em um ambiente de teste antes do uso. A execução de código remoto exige `loadstring` e `game:HttpGet`; o arquivo de configuração exige APIs de arquivos não padronizadas. O projeto não contém recursos para perturbar outros jogadores, contornar anticheat ou acessar dados de terceiros.

## Observações visuais

X-Ray e ESP não alteram personagens no servidor. O ESP atualiza distâncias a cada 0,2 s e limita etiquetas a 500 studs. A renderização de Highlight pode ter limites do próprio Roblox. Mapas que sobrescrevem a iluminação ou bloqueiam efeitos podem reduzir a eficácia dos controles. As opções podem ser incompatíveis com as regras de algumas experiências.
