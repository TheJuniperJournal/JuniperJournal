class BrowserHistory {
  String get location => '/';
  Future<void> listen(void Function(String) onChange) async {}
  void write(String path, {bool replace = false}) {}
  void dispose() {}
}
