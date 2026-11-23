import 'dart:io';
import 'package:app_noticias_tii/models/categoria.dart';
import 'package:app_noticias_tii/models/noticia.dart';
import 'package:app_noticias_tii/services/categoria_service.dart';
import 'package:app_noticias_tii/services/noticia_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CadastrarNoticiaPage extends StatefulWidget {
  // Se vier null = modo CADASTRO. Se vier preenchida = modo EDIÇÃO.
  final Noticia? noticia;
  const CadastrarNoticiaPage({super.key, this.noticia});

  @override
  State<CadastrarNoticiaPage> createState() => _CadastrarNoticiaPageState();
}

class _CadastrarNoticiaPageState extends State<CadastrarNoticiaPage> {
  final ImagePicker _picker = ImagePicker();
  File? _imagemSelecionada;

  // Chave que identifica o Form; é com ela que chamamos validate().
  final _formKey = GlobalKey<FormState>();

  // Um controller por campo de texto: guarda (e permite preencher) o texto.
  final _tituloController = TextEditingController();
  final _resumoController = TextEditingController();
  final _conteudoController = TextEditingController();

  final NoticiaService _noticiaService = NoticiaService();
  final CategoriaService _categoriaService = CategoriaService();

  List<Categoria> _categorias = [];
  bool _carregandoCategorias = true;
  int? _categoriaId; // id da categoria escolhida (null = nenhuma ainda)
  bool _ativo = true; // switch "Publicação Ativa" começa ligado no cadastro
  bool _salvando = false; // true enquanto a requisição está em andamento

  // Atalho: estamos editando quando recebemos uma notícia.
  bool get _editando => widget.noticia != null;

  @override
  void initState() {
    super.initState();

    final noticia = widget.noticia;
    if (noticia != null) {
      // Modo edição: preenche o formulário com os dados que já existem.
      _tituloController.text = noticia.titulo;
      _resumoController.text = noticia.resumo;
      _conteudoController.text = noticia.conteudo;
      _categoriaId = noticia.categoriaId;
      _ativo = noticia.ativo == 1; // a API manda 1/0; o Switch precisa de bool
    }

    _carregarCategorias();
  }

  @override
  void dispose() {
    // Controllers precisam ser liberados para não vazar memória.
    _tituloController.dispose();
    _resumoController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    try {
      final lista = await _categoriaService.getCategorias();
      if (!mounted) return; // a tela pode ter sido fechada durante o await
      setState(() {
        _categorias = lista;
        // Proteção: se a categoria da notícia não existir mais na lista, o
        // Dropdown daria erro. Nesse caso o usuário escolhe outra.
        if (!lista.any((c) => c.id == _categoriaId)) {
          _categoriaId = null;
        }
        _carregandoCategorias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoCategorias = false);
    }
  }

  Future<void> _selecionarImagem(ImageSource origem) async {
    final XFile? foto = await _picker.pickImage(
      source: origem,
      imageQuality: 80,
    );

    if (foto != null) {
      setState(() {
        _imagemSelecionada = File(foto.path);
      });
    }
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<void> _salvar() async {
    // 1) Roda todos os validator dos campos; se algum falhar, para aqui.
    if (!_formKey.currentState!.validate()) return;

    // 2) Imagem é obrigatória só no cadastro. Na edição, se o usuário não
    //    escolher outra, a imagem atual continua no servidor.
    if (!_editando && _imagemSelecionada == null) {
      _mostrarMensagem('Selecione uma imagem de capa.');
      return;
    }

    setState(() => _salvando = true); // trava o botão e mostra o loading

    try {
      if (_editando) {
        await _noticiaService.editarNoticia(
          id: widget.noticia!.id,
          titulo: _tituloController.text.trim(),
          resumo: _resumoController.text.trim(),
          conteudo: _conteudoController.text.trim(),
          categoriaId: _categoriaId!,
          ativo: _ativo,
          imagemArquivo: _imagemSelecionada, // null = mantém a imagem atual
        );
      } else {
        await _noticiaService.criarNoticia(
          titulo: _tituloController.text.trim(),
          resumo: _resumoController.text.trim(),
          conteudo: _conteudoController.text.trim(),
          categoriaId: _categoriaId!,
          ativo: _ativo,
          imagemArquivo: _imagemSelecionada,
        );
      }

      if (!mounted) return;
      // Fecha a tela devolvendo true: a HomePage usa isso para recarregar.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // O service lança "Exception: mensagem"; tiramos o prefixo "Exception: ".
      _mostrarMensagem(
        e.toString().replaceFirst(RegExp(r'^(Exception: )+'), ''),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Notícia' : 'Cadastrar Notícia'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            // ---------- outros campos (parte de cima) ----------
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              // Mesma regra do Laravel: required|min:10|max:255
              validator: (valor) {
                final texto = valor?.trim() ?? '';
                if (texto.isEmpty) return 'Informe o título';
                if (texto.length < 10) {
                  return 'O título deve ter pelo menos 10 caracteres';
                }
                if (texto.length > 255) {
                  return 'O título deve ter no máximo 255 caracteres';
                }
                return null; // null = campo válido
              },
            ),
            const SizedBox(
              height: 15,
            ),
            TextFormField(
              controller: _resumoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Resumo',
                border: OutlineInputBorder(),
              ),
              validator: (valor) => (valor == null || valor.trim().isEmpty)
                  ? 'Informe o resumo'
                  : null,
            ),
            const SizedBox(
              height: 15,
            ),
            TextFormField(
              controller: _conteudoController,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Conteúdo',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (valor) => (valor == null || valor.trim().isEmpty)
                  ? 'Informe o conteúdo'
                  : null,
            ),
            const SizedBox(
              height: 15,
            ),
            const Text(
              'Imagem de Capa',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            // ---------- bloco de imagem (protótipo do professor) ----------
            const SizedBox(
              height: 15,
            ),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFD7D7D7),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
              ),
              child: _imagemSelecionada != null
                  ? Image.file(
                      _imagemSelecionada!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : (widget.noticia != null && widget.noticia!.imagem != null)
                  ? Image.network(
                      widget.noticia!.imagem!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, erro, stack) => const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(
              height: 15,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selecionarImagem(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Câmera'),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selecionarImagem(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                  ),
                ),
              ],
            ),
            // ---------- outros campos (parte de baixo) ----------
            const SizedBox(
              height: 15,
            ),
            if (_carregandoCategorias)
              const Center(child: CircularProgressIndicator())
            else if (_categorias.isEmpty)
              const Text('Não foi possível carregar as categorias.')
            else
              DropdownButtonFormField<int>(
                initialValue: _categoriaId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: _categorias
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.nome),
                      ),
                    )
                    .toList(),
                onChanged: (valor) => setState(() => _categoriaId = valor),
                validator: (valor) =>
                    valor == null ? 'Selecione uma categoria' : null,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicação Ativa'),
              value: _ativo,
              onChanged: (valor) => setState(() => _ativo = valor),
            ),
            const SizedBox(
              height: 10,
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                // onPressed null = botão desabilitado (evita duplo clique)
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _editando ? 'Salvar alterações' : 'Publicar notícia',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
