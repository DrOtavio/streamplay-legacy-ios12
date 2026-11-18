# StreamPlay Legacy — iOS 12 / iPhone 6 (jailbreak)

Projeto independente de `DrOtavio/streamplay-ios`, criado para testes no iPhone 6 / 6 Plus com iOS 12.5.8. Não requer TrollStore Lite.

## Recursos (versão 1.0)
- UIKit nativo, sem SwiftUI (compatível com iOS 12).
- Importação de listas M3U via endereço HTTP/HTTPS ou arquivo, busca de canais, persistência local.
- AVPlayer para streams HLS `.m3u8` e vídeo MP4 compatível com hardware/iOS 12.
- Navegador WKWebView, barra de URL e botões voltar/avançar/recarregar.
- Guia para usar o CarBridge Legacy em *Bridged Applications* ou *Portal*.

## CarPlay

O app **não possui entitlements CarPlay**: no iOS 12 com jailbreak, quem faz a ponte para o CarPlay é o **CarBridge Legacy** que já está instalado no aparelho. Primeiro valide o app no iPhone; depois habilite seu ícone no menu do CarBridge. Não há garantia de compatibilidade com iOS 12.5.8: a página da Havoc informa compatibilidade até 12.5.7. Use vídeo apenas quando o veículo estiver estacionado.

## Como compilar

GitHub Actions: **Actions → Build StreamPlay Legacy iOS 12 → Run workflow**. O workflow usa `macos-15` + Xcode 16.4 e publica o artefato `StreamPlayLegacy-iOS12-IPA` contendo um `.ipa` **não assinado**.

Xcode local: `bash scripts/build-ipa.sh` (requer Mac com Xcode compatível). Atenção: compilações de Xcode 16.4 visando iOS 12 podem apresentar problemas em aparelhos reais. Este projeto usa Objective-C para reduzir dependências do runtime Swift, mas o teste no dispositivo é necessário.

## Instalar sem TrollStore

1. No iPhone com jailbreak, instale **AppSync Unified** a partir de fonte confiável. Uma referência atualizada é a wiki do Legacy iOS Kit: https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Install-IPA-AppSync
2. Copie o `.ipa` gerado para o iPhone via compartilhamento de arquivo/AirDrop/Filza WebDAV e abra-o no **Filza → Instalar**.
3. Abra **StreamPlay Legacy** no iPhone, importe uma playlist M3U ou use o vídeo de demonstração.
4. Abra **Ajustes → CarBridge Legacy → Bridged Applications** e habilite o app, se a opção estiver disponível.
5. Conecte o aparelho à central e teste com o veículo parado. Se o aplicativo não aparecer, utilize o modo *Portal* do CarBridge como alternativa.

## Observações

- Sem IPTV pirata, conteúdo comercial ou URL privada incorporada ao código.
- `NSAllowsArbitraryLoads` foi habilitado para fontes IPTV HTTP legadas; prefira HTTPS em redes não confiáveis.
- Sites atuais podem não renderizar em `WKWebView` do iOS 12 (limite do WebKit do sistema).
- Sem transcoding. Codecs/formatos incompatíveis não são convertidos.
- A imagem de instalação do IPA é **não assinada**; instalações exigem suporte do jailbreak/AppSync ou assinatura apropriada.
