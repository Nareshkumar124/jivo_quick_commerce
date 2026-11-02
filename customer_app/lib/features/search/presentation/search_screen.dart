import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/paged_product_grid.dart';
import 'search_controller.dart';

/// Search (`03 §2.7`): debounced suggestions while typing, recent searches
/// (on this device) and trending searches, then a results grid.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit(String query) {
    if (query.trim().isEmpty) return;
    _field.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(searchControllerProvider.notifier).submit(query);
  }

  void _clear() {
    _field.clear();
    ref.read(searchControllerProvider.notifier).onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(searchControllerProvider);
    final submitted = state.submitted;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-field'),
          controller: _field,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchFieldHint,
            border: InputBorder.none,
          ),
          onChanged: ref.read(searchControllerProvider.notifier).onChanged,
          onSubmitted: _submit,
        ),
        actions: [
          if (state.text.isNotEmpty)
            IconButton(
              tooltip: l10n.clearSearch,
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
        ],
      ),
      bottomNavigationBar: const CartBar(),
      body: submitted != null
          ? PagedProductGrid(
              query: SearchQuery(submitted),
              emptyMessage: l10n.noResults(submitted),
              emptyAction: _NoResultsHint(onSelected: _submit),
            )
          : state.text.trim().isEmpty
          ? _Discover(onSelected: _submit)
          : _Suggestions(
              state: state,
              onSubmit: _submit,
              onRetry: ref
                  .read(searchControllerProvider.notifier)
                  .retrySuggestions,
            ),
    );
  }
}

/// Recent and trending searches, shown before typing.
class _Discover extends ConsumerWidget {
  const _Discover({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recent = ref.watch(recentSearchesProvider);
    final trending = ref.watch(trendingSearchesProvider);

    Widget heading(String text, {Widget? trailing}) => Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: theme.textTheme.titleSmall),
          ),
        ),
        ?trailing,
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        if (recent.isNotEmpty) ...[
          heading(
            l10n.recentSearches,
            trailing: TextButton(
              key: const Key('clear-recent'),
              onPressed: ref.read(recentSearchesProvider.notifier).clear,
              child: Text(l10n.clearRecentSearches),
            ),
          ),
          Wrap(
            spacing: JivoSpacing.sm,
            runSpacing: JivoSpacing.sm,
            children: [
              for (final query in recent)
                ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(query),
                  onPressed: () => onSelected(query),
                ),
            ],
          ),
          const SizedBox(height: JivoSpacing.xl),
        ],
        heading(l10n.trendingSearches),
        const SizedBox(height: JivoSpacing.sm),
        switch (trending) {
          AsyncData(:final value) => Wrap(
            spacing: JivoSpacing.sm,
            runSpacing: JivoSpacing.sm,
            children: [
              for (final trend in value)
                ActionChip(
                  avatar: const Icon(Icons.trending_up, size: 18),
                  label: Text(trend.text),
                  onPressed: () => onSelected(trend.query),
                ),
            ],
          ),
          AsyncError() => Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.invalidate(trendingSearchesProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.state,
    required this.onSubmit,
    required this.onRetry,
  });

  final SearchState state;
  final ValueChanged<String> onSubmit;
  final VoidCallback onRetry;

  /// Products and categories open directly; keywords run the search.
  void _open(BuildContext context, SearchSuggestion suggestion) {
    final slug = suggestion.slug;
    switch (suggestion.type) {
      case SuggestionType.product when slug != null:
        context.push(Routes.product(slug));
      case SuggestionType.category when slug != null:
        context.push(Routes.category(slug));
      case _:
        onSubmit(suggestion.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = state.text.trim();
    final searchFor = ListTile(
      key: const Key('search-for'),
      leading: const Icon(Icons.search),
      title: Text(query),
      onTap: () => onSubmit(query),
    );
    return switch (state.suggestions) {
      AsyncData(:final value) => ListView(
        children: [
          searchFor,
          for (final suggestion in value)
            ListTile(
              leading: Icon(switch (suggestion.type) {
                SuggestionType.product => Icons.shopping_basket_outlined,
                SuggestionType.category => Icons.category_outlined,
                SuggestionType.keyword => Icons.north_west,
              }),
              title: Text(suggestion.text),
              onTap: () => _open(context, suggestion),
            ),
        ],
      ),
      AsyncError() => ListView(
        children: [
          searchFor,
          ListTile(
            title: Text(l10n.suggestionsFailed),
            trailing: TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ),
        ],
      ),
      AsyncLoading() => ListView(
        children: [const LinearProgressIndicator(), searchFor],
      ),
      null => ListView(children: [searchFor]),
    };
  }
}

/// Trending searches as suggestions when a search found nothing.
class _NoResultsHint extends ConsumerWidget {
  const _NoResultsHint({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingSearchesProvider).value ?? const [];
    if (trending.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Text(AppLocalizations.of(context).noResultsTry),
        const SizedBox(height: JivoSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: JivoSpacing.sm,
          runSpacing: JivoSpacing.sm,
          children: [
            for (final trend in trending)
              ActionChip(
                label: Text(trend.text),
                onPressed: () => onSelected(trend.query),
              ),
          ],
        ),
      ],
    );
  }
}
