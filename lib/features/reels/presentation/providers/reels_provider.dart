import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/reel_model.dart';
import '../../data/repositories/reels_repository.dart';

/// Provider for the Reels Repository implementation
final reelsRepositoryProvider = Provider<IReelsRepository>((ref) {
  return ReelsRepositoryImpl();
});

/// AsyncNotifier to handle fetching and state of Reels
class ReelsNotifier extends AutoDisposeAsyncNotifier<List<ReelModel>> {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<ReelModel>> build() async {
    _currentPage = 1;
    _hasMore = true;
    return ref.watch(reelsRepositoryProvider).getReels(page: _currentPage);
  }

  /// Refresh the reels list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    _currentPage = 1;
    _hasMore = true;
    state = await AsyncValue.guard(() => ref.read(reelsRepositoryProvider).getReels(page: _currentPage));
  }

  /// Load next page of reels
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    final repository = ref.read(reelsRepositoryProvider);
    _currentPage++;

    final result = await AsyncValue.guard(() => repository.getReels(page: _currentPage));
    
    result.when(
      data: (newReels) {
        if (newReels.isEmpty) {
          _hasMore = false;
        } else {
          final currentReels = state.value ?? [];
          state = AsyncValue.data([...currentReels, ...newReels]);
        }
        _isLoadingMore = false;
      },
      error: (err, stack) {
        _currentPage--; // Rollback on error
        _isLoadingMore = false;
      },
      loading: () {},
    );
  }
}

/// The provider that the UI will listen to
final reelsProvider = AsyncNotifierProvider.autoDispose<ReelsNotifier, List<ReelModel>>(() {
  return ReelsNotifier();
});
