import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'adicionar_anuncio_page.dart';
import 'editar_perfil_profissional_page.dart';


class HomeProfissionalPage extends StatefulWidget {
  const HomeProfissionalPage({super.key});

  @override
  State<HomeProfissionalPage> createState() => _HomeProfissionalPageState();
}

class _HomeProfissionalPageState extends State<HomeProfissionalPage> {
  String nomeProfissional = "João Personal";
  String especialidade = "Treinamento Funcional";
  String descricao =
      "Profissional certificado com 5 anos de experiência ajudando alunos a alcançarem seus objetivos.";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Profissional'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(userType: 'Profissional'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com foto e nome
            Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=800',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    nomeProfissional,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              especialidade,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade600,
              ),
            ),
            const Divider(height: 30),

            // Descrição do profissional
            Text(
              descricao,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // Botões de ação
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      'Editar Perfil',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditarPerfilProfissionalPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.campaign),
                    label: const Text(
                      'Adicionar Anúncio',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdicionarAnuncioPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const Text(
              'Avaliações dos alunos:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _avaliacaoItem("Carlos Silva", 5, "Excelente profissional!"),
            _avaliacaoItem("Marina Costa", 4, "Muito atencioso e motivador."),
          ],
        ),
      ),
    );
  }

  Widget _avaliacaoItem(String nome, int estrelas, String comentario) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(Icons.person, color: Colors.red.shade400),
        title: Text(nome),
        subtitle: Text(comentario),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Icon(
              index < estrelas ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
