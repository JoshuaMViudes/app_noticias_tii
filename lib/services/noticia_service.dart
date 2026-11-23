import 'dart:convert';
import 'dart:io';
import 'package:app_noticias_tii/services/login_services.dart';
import 'package:http/http.dart' as http;
import '../models/noticia.dart'; // Certifique-se que o caminho aponta para o seu arquivo noticia.dart

class NoticiaService {
  final LoginServices _loginServices = LoginServices();
  static const String baseUrl = "http://10.0.2.2:8000/api";

  // Traduz a resposta de erro do Laravel em uma frase que o usuário entende.
  String _mensagemErro(int status, String corpo) {
    if (status == 401) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (status == 422) {
      // Em validação falha o Laravel devolve {"errors": {"campo": ["msg"]}}
      try {
        final dados = jsonDecode(corpo);
        final Map erros = dados['errors'] ?? {};
        if (erros.isNotEmpty) {
          return erros.values.map((lista) => (lista as List).first).join('\n');
        }
      } catch (_) {
        // corpo não era JSON: cai na mensagem padrão abaixo
      }
      return 'Verifique os campos e tente novamente.';
    }
    return 'Erro ao salvar a notícia (código $status).';
  }

  Future<List<Noticia>> getNoticia() async {
    final resposta = await http.get(Uri.parse('$baseUrl/noticias'));

    if (resposta.statusCode == 200) {
      final List dados = jsonDecode(resposta.body);
      return dados.map((item) => Noticia.fromJson(item)).toList();
    } else {
      throw Exception('Não foi possível carregar as Notícias');
    }
  }

  Future<void> criarNoticia({
    required String titulo,
    required String resumo,
    required String conteudo,
    required int categoriaId,
    required bool ativo,
    File? imagemArquivo,
  }) async {
    try {
      final token = await _loginServices.getToken();

      if (imagemArquivo != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/noticias'),
        );
        request.headers['Accept'] = 'application/json';
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['titulo'] = titulo;
        request.fields['resumo'] = resumo;
        request.fields['conteudo'] = conteudo;
        request.fields['categoria_id'] = categoriaId.toString();
        request.fields['ativo'] = ativo ? '1' : '0';
        request.files.add(
          await http.MultipartFile.fromPath('imagem', imagemArquivo.path),
        );

        final resposta = await request.send();

        final corpoResposta = await resposta.stream.bytesToString();
        print('Status: ${resposta.statusCode}');
        print('Resposta da Api: $corpoResposta');

        if (resposta.statusCode != 200 && resposta.statusCode != 201) {
          throw Exception(_mensagemErro(resposta.statusCode, corpoResposta));
        }
      } else {
        throw Exception('Selecione uma imagem de capa.');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<void> editarNoticia({
    required int id,
    required String titulo,
    required String resumo,
    required String conteudo,
    required int categoriaId,
    required bool ativo,
    File? imagemArquivo,
  }) async {
    try {
      final token = await _loginServices.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/noticias/$id'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['_method'] = 'PUT';
      request.fields['titulo'] = titulo;
      request.fields['resumo'] = resumo;
      request.fields['conteudo'] = conteudo;
      request.fields['categoria_id'] = categoriaId.toString();

      request.fields['ativo'] = ativo ? '1' : '0';

      if (imagemArquivo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('imagem', imagemArquivo.path),
        );
      }

      final resposta = await request.send();

      final corpoResposta = await resposta.stream.bytesToString();
      print('Status: ${resposta.statusCode}');
      print('Resposta da Api: $corpoResposta');

      if (resposta.statusCode != 200 && resposta.statusCode != 201) {
        throw Exception(_mensagemErro(resposta.statusCode, corpoResposta));
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<void> excluirNoticia(int id) async {
    try {
      final token = await _loginServices.getToken();

      final resposta = await http.delete(
        Uri.parse('$baseUrl/noticias/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resposta.statusCode != 200 && resposta.statusCode != 204) {
        throw Exception('Não foi possível excluir a notícia.');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }
}
