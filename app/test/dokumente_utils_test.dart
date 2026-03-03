import 'package:flutter_test/flutter_test.dart';
import 'package:elektronik_verwaltung/utils/dokumente_utils.dart';

void main() {
  test('sortFilesByName ascending', () {
    final input = ['b.txt', 'A.txt', 'c.txt'];
    final out = sortFilesByName(input);
    expect(out, ['A.txt', 'b.txt', 'c.txt']);
  });

  test('sortFilesByName descending', () {
    final input = ['b.txt', 'A.txt', 'c.txt'];
    final out = sortFilesByName(input, ascending: false);
    expect(out, ['c.txt', 'b.txt', 'A.txt']);
  });

  test('sortFilesByTypeThenName groups and sorts', () {
    final input = ['x.pdf', 'a.jpg', 'b.doc', 'c.png', 'z.txt'];
    final out = sortFilesByTypeThenName(input);
    // expected order: images (a.jpg, c.png), pdf (x.pdf), docs (b.doc), others (z.txt)
    expect(out, ['a.jpg', 'c.png', 'x.pdf', 'b.doc', 'z.txt']);
  });
}
