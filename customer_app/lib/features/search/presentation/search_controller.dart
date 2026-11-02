import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../data/recent_searches_store.dart';

/// Suggestions wait this long after the last keystroke (`03 §2.7`).
const kSearchDebounce = Duration(milliseconds: 300);

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(ref.watch(sharedPreferencesProvider)),
);

class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() => ref.read(recentSearchesStoreProvider).read();

  Future<void> add(String query) async {
    state = await ref.read(recentSearchesStoreProvider).add(query);
  }

  Future<void> clear() async {
    await ref.read(recentSearchesStoreProvider).clear();
    state = const [];
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(
  RecentSearches.new,
);

@immutable
class SearchState {
  const SearchState({this.text = '', this.suggestions, this.submitted});

  /// What is in the search field.
  final String text;

  /// Typeahead for [text]; null while nothing was requested.
  final AsyncValue<List<SearchSuggestion>>? suggestions;

  /// The query whose results are shown; null while typing.
  final String? submitted;
}

/// The search screen: debounced suggestions, submit, recent searches.
class ProductSearchController extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  /// The field changed: suggestions follow after [kSearchDebounce].
  void onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      state = SearchState(text: text);
      return;
    }
    state = SearchState(text: text, suggestions: state.suggestions);
    _debounce = Timer(kSearchDebounce, () => _suggest(text));
  }

  Future<void> _suggest(String text) async {
    state = SearchState(text: text, suggestions: const AsyncLoading());
    final repository = ref.read(catalogRepositoryProvider);
    final result = await AsyncValue.guard(
      () => storeScoped(ref, () => repository.suggest(text.trim())),
    );
    if (ref.mounted && state.text == text && state.submitted == null) {
      state = SearchState(text: text, suggestions: result);
    }
  }

  /// Retries the suggestions for the current text.
  void retrySuggestions() => _suggest(state.text);

  /// Shows results for [query] and remembers it.
  Future<void> submit(String query) async {
    final text = query.trim();
    if (text.isEmpty) return;
    _debounce?.cancel();
    state = SearchState(text: text, submitted: text);
    await ref.read(recentSearchesProvider.notifier).add(text);
  }
}

final searchControllerProvider =
    NotifierProvider.autoDispose<ProductSearchController, SearchState>(
      ProductSearchController.new,
    );
