import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/app_state.dart';
import '../../widgets/product/product_card.dart';
import '../../widgets/common/animations.dart';

// Cuántas categorías se muestran por "página" del selector.
// Súbelo o bájalo según cuántos chips quepan cómodos en una fila.
const int _kCategoriasPorPagina = 5;

class MenuScreen extends StatefulWidget {
  MenuScreen({super.key});
  @override State<MenuScreen> createState() => _MenuState();
}

class _MenuState extends State<MenuScreen> {
  String? _cat;
  String  _q = '';

  final _catPageCtrl = PageController();
  int   _catPage = 0;

  @override void dispose() { _catPageCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.instance,
    builder: (context, _) {
    final lista = _q.isNotEmpty
        ? AppState.instance.buscarProductos(_q)
        : AppState.instance.getProductosPorCategoria(_cat);

    final categorias = AppState.instance.categorias;
    final paginas = <List<dynamic>>[];
    for (var i = 0; i < categorias.length; i += _kCategoriasPorPagina) {
      paginas.add(categorias.sublist(
        i, i + _kCategoriasPorPagina > categorias.length ? categorias.length : i + _kCategoriasPorPagina));
    }
    if (paginas.isEmpty) paginas.add(const []);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('Menú'), backgroundColor: C.surface,
        // Refresca el catálogo completo (productos/adiciones/toppings/etc.)
        // contra el backend — cargarDatos() normalmente solo pide esto una
        // vez por sesión, así que si algo se creó/editó en el admin
        // después de que la app ya cargó datos, este es el único modo de
        // verlo sin reiniciar la app entera. Ver también el
        // RefreshIndicator (deslizar hacia abajo) más abajo.
        actions: [IconButton(
          icon: Icon(Icons.refresh),
          tooltip: 'Actualizar menú',
          onPressed: () => AppState.instance.refrescarDatos())],
        bottom: PreferredSize(preferredSize: Size.fromHeight(56),
          child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(style: TextStyle(color: C.text),
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search, color: C.textMut, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear, size: 18, color: C.textMut),
                        onPressed: () => setState(() => _q = ''))
                    : null))))),
      body: Column(children: [
        // ── Categorías (paginadas) ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CatChip(label: 'Todos', selected: _cat == null, onTap: () => setState(() => _cat = null)),
            SizedBox(width: 8),
            Expanded(
              child: Column(children: [
                SizedBox(
                  height: 36,
                  child: PageView.builder(
                    controller: _catPageCtrl,
                    itemCount: paginas.length,
                    onPageChanged: (p) => setState(() => _catPage = p),
                    itemBuilder: (_, p) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(children: paginas[p].map<Widget>((c) => _CatChip(
                        label: c.nombre, selected: _cat == c.nombre,
                        onTap: () => setState(() => _cat = c.nombre))).toList()),
                    ),
                  ),
                ),
                if (paginas.length > 1) ...[
                  SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(paginas.length, (i) => AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(horizontal: 3),
                      width: i == _catPage ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _catPage ? C.green : C.border,
                        borderRadius: BorderRadius.circular(3))))),
                ],
              ]),
            ),
          ]),
        ),
        SizedBox(height: 8),

        // ── Grid ──
        // Deslizar hacia abajo también fuerza la recarga del catálogo
        // (mismo refrescarDatos() que el botón de la AppBar) — física
        // "always scrollable" en ambas ramas para que el gesto funcione
        // incluso cuando "Sin productos" no llena la pantalla.
        Expanded(child: RefreshIndicator(
          color: C.green,
          onRefresh: () => AppState.instance.refrescarDatos(),
          child: lista.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.coffee_outlined, size: 52, color: C.textMut),
                  SizedBox(height: 12),
                  Text('Sin productos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.text)),
                  Text(_q.isNotEmpty ? 'No hay resultados para "$_q"' : 'Categoría sin productos',
                    style: TextStyle(fontSize: 13, color: C.textSec))]))])
            : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, 80),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.73),
                itemCount: lista.length,
                itemBuilder: (_, i) => StaggeredFadeIn(index: i, step: Duration(milliseconds: 35),
                  child: ProductCard(producto: lista[i]))))),
      ]),
    );
    },
  );
}

class _CatChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  _CatChip({required this.label, required this.selected, required this.onTap});

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(duration: Duration(milliseconds: 200),
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? C.green : C.surf2,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: selected ? C.green : C.border)),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: selected ? Colors.white : C.textSec))));
}