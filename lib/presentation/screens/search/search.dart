import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/app_state.dart';
import '../../../data/models/models.dart';
import '../../widgets/product/product_card.dart';

class SearchScreen extends StatefulWidget {
  SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
    final resultados = AppState.instance.buscarProductos(_q);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.surface, titleSpacing: 0,
        title: TextField(
          controller: _ctrl, autofocus: true, style: TextStyle(color: C.text),
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Buscar bebidas, categorías...',
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _q.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, color: C.textMut, size: 18),
                    onPressed: () { _ctrl.clear(); setState(() => _q = ''); })
                : null)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: C.text),
          onPressed: () => Navigator.pop(context))),

      body: _q.isEmpty
          ? _Sugerencias()
          : resultados.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off, size: 52, color: C.textMut),
                  SizedBox(height: 12),
                  Text('Sin resultados para "$_q"', style: TextStyle(fontSize: 15, color: C.textSec))]))
              : GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.73),
                  itemCount: resultados.length,
                  itemBuilder: (_, i) => ProductCard(producto: resultados[i])),
    );
    },
  );
}

class _Sugerencias extends StatelessWidget {
  @override Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Categorías', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
      SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: AppState.instance.categorias.map((c) => GestureDetector(
        onTap: () {}, // navegar a menú con esa categoría
        child: Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: C.surf2, borderRadius: BorderRadius.circular(100), border: Border.all(color: C.border)),
          child: Text(c.nombre, style: TextStyle(fontSize: 13, color: C.textSec, fontWeight: FontWeight.w600))))).toList()),
      SizedBox(height: 24),
      Text('Sugerencias', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
      SizedBox(height: 12),
      ...['Café', 'Frappé', 'Capuchino', 'Tinto', 'Vitafer'].map((s) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.trending_up_outlined, color: C.textMut, size: 18),
        title: Text(s, style: TextStyle(color: C.textSec, fontSize: 14)),
        trailing: Icon(Icons.north_west, color: C.textMut, size: 14))),
    ]),
  );
}