abstract interface class TerminalSession {
  Stream<String> get output;
  void write(String data);
  void resize(int columns, int rows);
  Future<void> close();
}

enum ContainerAction { start, stop, restart }
