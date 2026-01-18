/// Maps backend category names to user-friendly display names.
/// This allows the UI to show more descriptive labels without changing backend data.
String displayCategory(String? category) {
  if (category == null) return 'Unknown';
  
  switch (category) {
    case 'Food':
      return 'Food & Beverages';
    default:
      return category;
  }
}

/// Converts display name back to backend category name for saving.
String backendCategory(String displayName) {
  switch (displayName) {
    case 'Food & Beverages':
      return 'Food';
    default:
      return displayName;
  }
}
