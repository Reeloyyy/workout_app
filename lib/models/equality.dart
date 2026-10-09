/// Element-wise equality for the lists held by domain models.
bool sameItems<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Marks a `copyWith` argument that was not passed, so nullable fields can be
/// explicitly set to null.
const Object unset = _Unset();

class _Unset {
  const _Unset();
}
