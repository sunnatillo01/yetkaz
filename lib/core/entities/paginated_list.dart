import 'package:freezed_annotation/freezed_annotation.dart';

part 'paginated_list.freezed.dart';

/// Opaque cursor: the order-by values of the last document of a page.
@freezed
abstract class PageCursor with _$PageCursor {
  const factory PageCursor(List<Object?> values) = _PageCursor;
}

@freezed
abstract class PaginatedList<T> with _$PaginatedList<T> {
  const factory PaginatedList({
    required List<T> items,
    required bool hasMore,
    PageCursor? nextCursor,
    @Default(false) bool fromCache,
  }) = _PaginatedList<T>;
}
