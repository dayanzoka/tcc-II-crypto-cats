extends CasoDeTeste

## Todas as telas com a cara do menu, no tom do wallpaper escolhido (ADR 0034):
## vidro fosco com tinta, moldura de vinhas, baloes de flor e texto branco.
## As preferencias vao para um arquivo temporario, para nao mexer nas de quem
## roda a suite.

const TELAS: Dictionary = {
	"res://cenas/ui/selecao_de_fases.tscn": ["Raiz"],
	"res://cenas/ui/editor_de_fase.tscn": ["Raiz"],
	"res://cenas/ui/dashboard_telemetria.tscn": ["Raiz", "PainelFases", "PainelDetalhe", "PainelDiagnostico"],
	"res://cenas/ui/escolha_de_gato.tscn": ["Painel"],
}

## Paineis do jogo: o tema vai no no indicado (o primeiro) e o vidro no segundo.
const PAINEIS_DO_JOGO: Dictionary = {
	"res://cenas/ui/tela_captura.tscn": ["Raiz", "Raiz/Painel"],
	"res://cenas/base/painel_pause.tscn": ["Raiz", "Raiz/Painel"],
	"res://cenas/base/caixa_puzzle.tscn": ["Raiz", "Raiz/Painel"],
	"res://cenas/base/painel_cifra.tscn": ["Raiz", "Raiz/Painel"],
	"res://cenas/base/terminal.tscn": ["Painel", "Painel"],
}

var _caminho_original: String = ""


func antes() -> void:
	_caminho_original = Preferencias.caminho
	Preferencias.caminho = caminho_temporario("preferencias_tema.cfg")
	if FileAccess.file_exists(Preferencias.caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Preferencias.caminho))


func depois() -> void:
	Preferencias.caminho = _caminho_original
	await get_tree().process_frame


func _abrir(cena: String) -> Node:
	var tela: Node = (load(cena) as PackedScene).instantiate()
	get_tree().root.add_child(tela)
	await get_tree().process_frame
	await get_tree().process_frame
	return tela


func teste_cada_fundo_tem_seu_tema() -> void:
	var baloes: Dictionary = {}
	for fundo: String in GaleriaDeFundos.ORDEM:
		var tema: Theme = TemaDaGaleria.tema(fundo)
		var balao: StyleBoxTexture = tema.get_stylebox(&"normal", &"Button") as StyleBoxTexture
		if not afirmar_nao_nulo(balao, "%s: botao e o balao desenhado" % fundo):
			continue
		afirmar_igual(balao.texture, GaleriaDeFundos.textura_do_balao(fundo), "%s: balao no tom do fundo" % fundo)
		baloes[balao.texture.resource_path] = true
		afirmar_igual(tema.get_color(&"font_color", &"Button"), Color.WHITE, "%s: texto do botao branco" % fundo)
		afirmar_igual(tema.get_color(&"font_color", &"Label"), Color.WHITE, "%s: texto branco" % fundo)
		afirmar_igual(tema.get_constant(&"outline_size", &"Label"), 0, "%s: sem contorno" % fundo)
		var vidro: StyleBoxFlat = tema.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
		afirmar_igual(vidro.bg_color, GaleriaDeFundos.tinta(fundo), "%s: vidro com a tinta do fundo" % fundo)
		afirmar_igual(vidro.corner_radius_top_left, MolduraDeVinhas.RAIO * MolduraDeVinhas.ESCALA,
			"%s: canto do vidro na curva da vinha" % fundo)
		# CheckBox e Button para o Godot: nao pode herdar o balao.
		afirmar_verdadeiro(tema.get_stylebox(&"normal", &"CheckBox") is StyleBoxEmpty,
			"%s: caixinha de marcar sem balao" % fundo)
	afirmar_igual(baloes.size(), GaleriaDeFundos.ORDEM.size(), "cada fundo com um balao diferente")
	afirmar_verdadeiro(TemaDaGaleria.tema("ceu") == TemaDaGaleria.tema("ceu"), "o tema de cada fundo e montado uma vez")


## Texto branco sobre o vidro le bem em todos os fundos: contraste de pelo
## menos 4,5 para 1 (WCAG AA) mesmo nas partes mais claras do wallpaper
## (blocos de 16x16, percentil 90 de luminancia), que o desfoque espalha atras
## do texto.
func teste_texto_branco_le_bem_em_todos_os_fundos() -> void:
	for fundo: String in GaleriaDeFundos.ORDEM:
		var imagem: Image = GaleriaDeFundos.textura_do_fundo(fundo).get_image()
		imagem.convert(Image.FORMAT_RGB8)
		for i: int in 4:
			imagem.shrink_x2()   # cada pixel vira a media de um bloco 16x16
		var luminancias: Array[float] = []
		var cores: Array[Color] = []
		for y: int in imagem.get_height():
			for x: int in imagem.get_width():
				var cor: Color = imagem.get_pixel(x, y)
				cores.append(cor)
				luminancias.append(_luminancia(cor))
		var ordem: Array[float] = luminancias.duplicate()
		ordem.sort()
		var limite: float = ordem[int(ordem.size() * 0.9)]
		var clara: Color = cores[luminancias.find(limite)]
		var tinta: Color = GaleriaDeFundos.tinta(fundo)
		var vidro: Color = clara.lerp(Color(tinta.r, tinta.g, tinta.b), tinta.a)
		var contraste: float = 1.05 / (_luminancia(vidro) + 0.05)
		afirmar_verdadeiro(contraste >= 4.5, "%s: contraste do texto branco %.1f (minimo 4,5)" % [fundo, contraste])


func _luminancia(cor: Color) -> float:
	var canais: Array[float] = []
	for c: float in [cor.r, cor.g, cor.b]:
		canais.append(c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4))
	return 0.2126 * canais[0] + 0.7152 * canais[1] + 0.0722 * canais[2]


func teste_telas_com_vidro_vinhas_e_baloes() -> void:
	GaleriaDeFundos.salvar("noite")
	for cena: String in TELAS:
		var tela: Node = await _abrir(cena)
		afirmar_igual((tela as Control).theme, TemaDaGaleria.tema("noite"), "%s: tema do fundo escolhido" % cena)
		for nome: String in TELAS[cena]:
			afirmar_vidro_com_vinhas(tela.get_node(nome) as Control, "%s/%s" % [cena.get_file(), nome])
		_conferir_botoes(tela, cena, "noite")
		tela.free()


func teste_paineis_do_jogo_com_vidro_vinhas_e_veu() -> void:
	GaleriaDeFundos.salvar("piquenique")
	for cena: String in PAINEIS_DO_JOGO:
		var painel: Node = await _abrir(cena)
		var alvo: Control = painel.get_node(String(PAINEIS_DO_JOGO[cena][0])) as Control
		afirmar_igual(alvo.theme, TemaDaGaleria.tema("piquenique"), "%s: tema do fundo escolhido" % cena)
		afirmar_vidro_com_vinhas(painel.get_node(String(PAINEIS_DO_JOGO[cena][1])) as Control, cena.get_file())
		var veu: ColorRect = painel.get_node_or_null("Raiz/Fundo") as ColorRect
		if veu != null:
			afirmar_igual(veu.color, TemaDaGaleria.cor_do_veu("piquenique"), "%s: veu no tom do fundo" % cena)
		_conferir_botoes(painel, cena, "piquenique")
		painel.free()


## Todo botao comum e o balao de flores no tom do fundo, com texto branco; os
## pequenos do editor usam o mesmo balao na altura minima.
func _conferir_botoes(raiz: Node, cena: String, fundo: String) -> void:
	for no: Node in _descendentes(raiz):
		var botao: Button = no as Button
		if botao == null or botao is CheckBox or botao is CheckButton or botao.flat:
			continue
		if botao.theme_type_variation == &"CartaoDeGato" or botao.get_parent() is Window:
			continue
		if botao.owner == null and botao.get_parent() is ColorPicker:
			continue
		var estilo: StyleBoxTexture = botao.get_theme_stylebox(&"normal") as StyleBoxTexture
		if not afirmar_nao_nulo(estilo, "%s: '%s' e o balao" % [cena.get_file(), botao.name]):
			continue
		afirmar_igual(estilo.texture, GaleriaDeFundos.textura_do_balao(fundo),
			"%s: '%s' no tom do fundo" % [cena.get_file(), botao.name])
		var cor: Color = botao.get_theme_color(&"font_color")
		afirmar_igual(cor, Color.WHITE, "%s: '%s' com texto branco" % [cena.get_file(), botao.name])


func teste_trocar_o_fundo_no_menu_troca_o_tema() -> void:
	GaleriaDeFundos.salvar("brejo")
	var menu: Control = await _abrir("res://cenas/ui/menu_principal.tscn") as Control
	afirmar_igual(menu.theme, TemaDaGaleria.tema("brejo"), "comeca no brejo")
	menu.call("_ao_trocar_fundo")
	afirmar_igual(menu.theme, TemaDaGaleria.tema("noite"), "a galeria troca o tema junto com o fundo")
	menu.free()

	# A tela seguinte ja abre no fundo novo.
	var selecao: Control = await _abrir("res://cenas/ui/selecao_de_fases.tscn") as Control
	afirmar_igual(selecao.theme, TemaDaGaleria.tema("noite"), "a selecao abre no tom escolhido")
	afirmar_igual((selecao.get_node("Fundo") as TextureRect).texture, GaleriaDeFundos.textura_do_fundo("noite"),
		"e com o mesmo wallpaper")
	selecao.free()


## Atras do labirinto nao ha mais wallpaper da galeria: o proprio cenario
## continua ate a borda da tela (ADR 0038, ver teste_cenarios.gd).
func teste_labirinto_sem_wallpaper_da_galeria_atras() -> void:
	var fase: Node = (load("res://cenas/base/fase_base.tscn") as PackedScene).instantiate()
	afirmar_nulo(fase.get_node_or_null("Wallpaper"), "a fase nao desenha o wallpaper da galeria")
	fase.free()


func _descendentes(no: Node) -> Array[Node]:
	var lista: Array[Node] = []
	for filho: Node in no.get_children(true):
		lista.append(filho)
		lista.append_array(_descendentes(filho))
	return lista
