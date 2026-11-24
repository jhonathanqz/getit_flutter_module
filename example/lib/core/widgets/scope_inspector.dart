import 'dart:async';

import 'package:flutter/material.dart';
import 'package:getit_flutter_module/getit_flutter_module.dart';

import '../services/log_store.dart';

/// Painel flutuante que mostra, ao vivo, os escopos abertos, os binds de
/// cada um e o log do getit_flutter_module. Útil para ver o dispose acontecendo.
class ScopeInspector extends StatefulWidget {
  const ScopeInspector({super.key});

  @override
  State<ScopeInspector> createState() => _ScopeInspectorState();
}

class _ScopeInspectorState extends State<ScopeInspector> {
  final _container = ModularContainer.instance;
  bool _expanded = false;
  bool _showLog = false;

  @override
  void initState() {
    super.initState();
    _container.addListener(_refresh);
    LogStore.instance.addListener(_refresh);
  }

  // As mudanças acontecem durante build/dispose das rotas: atualiza depois.
  void _refresh() => scheduleMicrotask(() {
        if (mounted) setState(() {});
      });

  @override
  void dispose() {
    _container.removeListener(_refresh);
    LogStore.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scopes = _container.scopes;
    final theme = Theme.of(context);

    if (!_expanded) {
      return FloatingActionButton.extended(
        heroTag: 'scope-inspector',
        key: const Key('inspector-toggle'),
        onPressed: () => setState(() => _expanded = true),
        icon: const Icon(Icons.account_tree_outlined),
        label: Text('${scopes.length} escopos'),
      );
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: SizedBox(
        width: 340,
        height: 380,
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('getit_flutter_module inspector'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _expanded = false),
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Escopos')),
                ButtonSegment(value: true, label: Text('Log')),
              ],
              selected: {_showLog},
              onSelectionChanged: (s) => setState(() => _showLog = s.first),
            ),
            const Divider(height: 16),
            Expanded(child: _showLog ? _log(theme) : _scopes(scopes, theme)),
          ],
        ),
      ),
    );
  }

  Widget _scopes(List<ScopeInfo> scopes, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final scope in scopes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${scope.id}  ×${scope.references}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                for (final bind in scope.binds)
                  Text('  • $bind', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }

  Widget _log(ThemeData theme) {
    final lines = LogStore.instance.value.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: lines.length,
      itemBuilder: (_, index) => Text(
        lines[index].replaceFirst('[getit_flutter_module] ', ''),
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
