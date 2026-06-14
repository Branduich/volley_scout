enum Categoria {
  under11('Under 11'),
  under12('Under 12'),
  under13('Under 13'),
  under14('Under 14'),
  under16('Under 16'),
  under18('Under 18'),
  terzaDivisione('Terza Divisione'),
  secondaDivisione('Seconda Divisione'),
  primaDivisione('Prima Divisione'),
  serieD('Serie D'),
  serieC('Serie C'),
  serieB('Serie B'),
  serieB1('Serie B1'),
  serieB2('Serie B2'),
  serieA1('Serie A1'),
  serieA2('Serie A2'),
  serieA3('Serie A3');

  final String label;
  const Categoria(this.label);
}

enum Ruolo {
  undefined('Undefined'),
  palleggiatore('Palleggiatore'),
  opposto('Opposto'),
  schiacciatore('Schiacciatore'),
  centrale('Centrale'),
  libero('Libero');

  final String label;
  const Ruolo(this.label);
}
