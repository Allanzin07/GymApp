import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdicionarAnuncioPage extends StatefulWidget {
  const AdicionarAnuncioPage({super.key});

  @override
  State<AdicionarAnuncioPage> createState() => _AdicionarAnuncioPageState();
}

class _AdicionarAnuncioPageState extends State<AdicionarAnuncioPage> {
  final _formKey = GlobalKey<FormState>();
  String nome = '';
  String descricao = '';
  String imagem = '';
  String distancia = '';
  double avaliacao = 0.0;
  String tipo = 'Profissional'; // padrão para anúncios de profissional

  Future<void> _salvarAnuncio() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      await FirebaseFirestore.instance.collection('anuncios').add({
        'nome': nome,
        'descricao': descricao,
        'imagem': imagem.isNotEmpty
            ? imagem
            : 'https://images.unsplash.com/photo-1554284126-aa88f22d8f85?w=800',
        'distancia': distancia.isNotEmpty ? distancia : '1 km',
        'avaliacao': avaliacao,
        'tipo': tipo,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anúncio adicionado com sucesso!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Anúncio'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nome'),
                onSaved: (v) => nome = v ?? '',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Digite o nome' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Descrição'),
                onSaved: (v) => descricao = v ?? '',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Digite a descrição' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'URL da Imagem (opcional)'),
                onSaved: (v) => imagem = v ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Distância'),
                onSaved: (v) => distancia = v ?? '',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _salvarAnuncio,
                child: const Text(
                  'Publicar Anúncio',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
