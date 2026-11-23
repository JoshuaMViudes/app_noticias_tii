import 'dart:convert';
import 'dart:io';
import 'package:app_noticias_tii/services/login_services.dart';
import 'package:http/http.dart' as http;
import '../models/noticia.dart'; // Certifique-se que o caminho aponta para o seu arquivo noticia.dart

class NoticiaService {
  final LoginServices _loginServices = LoginServices();
  static const String baseUrl = "http://10.0.2.2:8000/api";

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
    File? imagemArquivo,
  }) async {
    try {
      final token = await _loginServices.getToken();

      if (imagemArquivo != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/noticia'),
        );
        request.headers['Accept'] = 'application/json';
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['titulo'] = titulo;
        request.fields['resumo'] = resumo;
        request.fields['conteudo'] = conteudo;
        request.fields['categoria_id'] = categoriaId.toString();
        //Adicionar o Campo Ativo
        request.files.add(
          await http.MultipartFile.fromPath('imagem', imagemArquivo.path),
        );

        final resposta = await request.send();

        //print(resposta); //Verificar Erros

        if (resposta.statusCode != 200 && resposta.statusCode != 201) {
          throw Exception('Todos os campos são obrigatórios.');
        }
      } else {
        throw Exception('Todos os campos são obrigatórios.');
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
    required int ativo,
    File? imagemArquivo,
  }) async {
    try {
      final token = await _loginServices.getToken();

      if (imagemArquivo != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/noticia/$id'),
        );
        request.headers['Accept'] = 'application/json';
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['_method'] = 'PUT';
        request.fields['titulo'] = titulo;
        request.fields['resumo'] = resumo;
        request.fields['conteudo'] = conteudo;
        request.fields['categoria_id'] = categoriaId.toString();
        request.fields['ativo'] = ativo.toString();
        request.files.add(
          await http.MultipartFile.fromPath('imagem', imagemArquivo.path),
        );

        final resposta = await request.send();

        //print(resposta); //Verificar Erros

        if (resposta.statusCode != 200 && resposta.statusCode != 201) {
          throw Exception('Todos os campos são obrigatórios.');
        }
      } else {
        throw Exception('Todos os campos são obrigatórios.');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<void> excluirNoticia() async {}
}
